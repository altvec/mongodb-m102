# Storage Engines and Indexes

## Storage Engines

```
          +-------------------------------+
          |                               |
 +--------v--------+            +---------v-------+
 |     Database    |            |   Application   |
 +-----------------+            +-----------------+
 |  Storage Engine |
 +-----------------+
 |     Hardware    |
 +-----------------+

```

The Storage Engine is the interface between Database and Hardware. Basically Storage Engine is what database uses to implement **Create**, **Read**, **Update** and **Delete** operations.

What Storage Engines **does** affect:
- how data is written to disk
- how data is deleted/removed from disk
- how data is read from disk
- data file format (different storage engines can implement different types of compression and different ways of storing the BSON for mongodb. We are still working with BSON, but underlying data structers on storage level can be different)
- format of indexes (MMAPv1 uses Btrees, WiredTiger uses B+ trees)

What Storage Engines **doesn't** do:
- change how you perform queries
- change behavior at the cluster level, so it won't affect, say, how your system scales with additional machines

Pluggable storage engines are the big feature in MongoDB 3.0, so now you can choose which storage engine you're using (in recent versions it's WiredTiger by default). There are who choices:
- WiredTiger
- MMAPv1


## MMAP v1

MMAPv1 maps the data files directly into virtual memory, allowing OS to do most of the work of the storage engine. MMAP uses mmap() system call. This lets us treat the data files as if they were already in memory. If they're not already in memory, a page fault will pull them into RAM. And if they're in memory and we update them, an fsync() will propagate the changes back to disk.

By default MongoDB uses WiredTiger, but, if you want, you can pass `--storateEngine mmapv1` to `mongod` command.
You can see what storage engine is used with the following command in mongo shell:
```
> db.serverStatus().storageEngine
{
	"name" : "wiredTiger",
	"supportsCommittedReads" : true,
	"readOnly" : false,
	"persistent" : true
}
```

MMAPv1 comes with collection level locking (MongoDB 3.0)
Database level locking with MongoDB 2.2 - 2.6.


### Locking

Locking is about shared resources. If two processes are attempring to write to the same region on disk at the same time, corruption can occur. For this reason, MongoDB has a multiple readers single writer lock. What this means is that you can have as many readers as you like and they will lock out any writers. As soon as one witer comes in, however, it locks out not only all readers, but all other writers as well. If data were the only issue, we might have document level locking. But the reality is there's other information, specifically metadata, where conflicts can occur.

For example, two documents located in different places on disk might share a single index. So an update to one document will also involve an update to that index. And an update to the other document might involve an update to that same index, causing a conflict even if the documents are widely separated on the disk.

Another example of something that might cause a conflict is the journal.

**Database level locking.** So if you're able to distribute your load on the server among multiple databases, you can have simultaneous writes without any conflicts.

**Collection level locking.** This allows for more flexibility. Even if you have multiple collections in the same database, you can still write to them simultaneously until such time as you're fully utilizign your resources.

*Locks*:
- shared resources
  - data
  - metadata
    - indexes

*Journal* - it is a write-ahead log. We need it to ensure consistency. Think about what would happen in the event of a disk failure during fsync() without this. Some bits might be updated, others not. With the journal, you write down what you're about to do. Then you do it. So if a disk failure occurs while you're writing to the journal, that's fine. You simply don't perform the update. When the disk comes back up, it notes the state of the database, notes that there was a partial update logged in the journal, but not a complete one. It ignores that log. And your database comes up in a consistent state. If a disk failure occurs later while you're syncing your data to the disk, that's fine too. You've got it complete in the journal. And when your system comes back up, you note that there was an incomplete update on the document. You look at the journal, complete the update, and the database is back in a consistent state.

Keep in mind that data on disk in BSON, raw BSON, so bits are mapped from disk to virtual memory directly.

### MMAPv1 Documents and Data Files

What data files is look like? Assuming that mongod is started with `--dbpath /tmp/mongo-mmap/`:
```
/tmp/mongo-mmap
$ ls -1 .
_tmp
admin.0           # data file in admin db
admin.ns          # admin namespace file, which contain metadata
diagnostic.data
journal           # journal file
local.0           # data file, created when first document is inserted in local db
local.ns          # local namespace file, which contain metadata
mongod.lock       # lock file
storage.bson
```

Number of extents `numExtents`. Within a datafile several extents are going to be defined, and these extentes are going to be address space where we can put documents.

So, for example, here we have an extent with some documents (D1, D2, D3, D4):
```
+----|----|---------|----|-------------+
| D1 | D2 |   D3    | D4 |             |
+----|----|---------|----|-------------+
```

Some documents can be larger or smaller than others. But what happen if one of the documents is an array and you want to push some objects to that array? So, what ends up happening to D2 in that case? It wants to grow, but of course it's right next to D3 - there's no room to grow. So what ends up happening it is ends up moving.

```
+----|----|---------|----|------|------+
| D1 | D2 |   D3    | D4 |  D2  |      |
+----|-+--|---------|----|---^--|------+
       |                     |
       +---------------------+
```

The moving intself isn't going to be free, but actually there's another issue - indexes. Index need to point to the document, and in the case of MMAPv1 they point to the address space that the document starts at. Now, when that document moves not only do we have to delete it from where it was and recreate it here, we need to update every index that points to that document so that it goes from pointing from old location to the new one (after D4).

In order to provide some grow opportunity do small documents space allocated with padding - *Power of 2 sized allocations*. Suppose you insert a vety small document, it's going to allocate 32 bytes. If that document grows larger than 32 bytes, db will give it 64... up to 2MB. And after that, it'll just add two megabytes at a time until you hit 16MB limit.

So, Power of 2 sized allocations provide following benefits:
- Documents will not have to move as soon as they grow in size (because you have some space to grow before your reach your record size)
- Documents that grow at a constant rate will move less often as time goes on
- Record spaces are likely to get re-used (with standard sizes, all documents are likely to find record spaces that fit them)


## WiredTiger

Features:
- Document level locking
- Compression
- Big performance gains
- Witout downsides of MMAPv1

WiredTiger stores its data on disk in B-trees, similar to the B-trees MMAPv1 uses for indexes, but not for its data.

New write initially get written to files in un-used regions, and then incorporated in with the rest of the data in the background later. WiredTiger during an update will actually write a new version of documents, rather whan overwriting existing date the way MMAPv1 does in many cases. So you don't have to worry about document moving or padding factor, in fact, WiredTiger doesn't even provide padding.

**Caching**. WiredTiger has two caches on memory. First is the wiredTiger cache, which is half of your RAM by default, but you can tune that, and the next is the file system cache.

How your data gets from the WiredTiger cache to the File System cache, and then onto the drive? This happens periodically at what's called a checkpoint. During the checkpoint, your data goes from the WiredTiger cache to File System cache and from there gets flushed to disk. It initiates a new checkpoint 60 seconds after the end of the last checkpoint, so roughly every minute or so. Each checkpoint is a consistent snapshot of your data. If for some reason you were running your MongoDB with WiredTiger with no journaling and with no replication going on, you will need to go back to the last snapshot for a consistent view of your data - so about a minute. Also, because it's a consistent snapshot, if you are using journaling, it will truncate the journal at this point. Furhermore, if too much of your WiredTiger cache gets dirty, it will begin flushing to the file system cache, and from there to disk.

**Document level locking**. Technically WiredTiger doesn't have locks, but it has good concurrency protocols. The effect is the equivalent of document level locking. With WiredTiger your writes should scale with number of threads, assuming some reasonable caveats. No trying to have all of your threads update the same document at the same time, for example, and no trying to use lots more threads than you have cores.

**Compression**. There is three compression options:
- Snappy (default) - fast
- zlib - more compression
- none

Here are some options:
```
WiredTiger options:
  --wiredTigerCacheSizeGB arg           maximum amount of memory to allocate
                                        for cache; defaults to 1/2 of physical
                                        RAM
  --wiredTigerStatisticsLogDelaySecs arg (=0)
                                        seconds to wait between each write to a
                                        statistics file in the dbpath; 0 means
                                        do not log statistics
  --wiredTigerJournalCompressor arg (=snappy)
                                        use a compressor for log records
                                        [none|snappy|zlib]
  --wiredTigerDirectoryForIndexes       Put indexes and data in different
                                        directories
  --wiredTigerCollectionBlockCompressor arg (=snappy)
                                        block compression algorithm for
                                        collection data [none|snappy|zlib]
  --wiredTigerIndexPrefixCompression arg (=1)
                                        use prefix compression on row-store
                                        leaf pages

```


Summary of WiredTiger internals:
- Stores data in btrees
- Writes are initially separate, incorporated later
- Two caches
  - WiredTiger cache - 1/2 of RAM (default)
  - FS cache

## Indexes

- Keys can be any type
- _id index is automatically created (unique to the collection)
- other than _id, explicitly declared
- automatically used by query planner
- you can index array contents (multikey index)
- can index subdocuments and subfields
- field names are not in the index

`db.foo.createIndex( {a: 1} )`

Indexes are a way of finding your documents very quickly. Above is the command
`db.collection.createIndex` will create an index. Indexes are ordered. So if
you wanted to sort on a1 - `db.foo.find().sort({a: 1})`, you could use that index, even if you not specifyed any specific documents you want to look up, but by walking through the index, you could find the order of the documents that you want. Also, this same a1 index has a double purpose. You can walk backwars and sort on a negative 1 - `db.foo.find().sort({a: -1})`.

When creating index you can specify multiple fields (compound index), and much like with the
sort, the order is important - `db.foo.createIndex( { a : 1, b : 1 } )`. You
can use this index to sort on a1, b1, or you can walk in backwars to sort on
a -1, b -1 `db.foo.find().sort({a: -1, b: -1})`. **You can walk compound indexes
worwards or backwars, but no like this `db.foo.find().sort({a: 1, b: -1})`!**

`db.foo.getIndxes()` - list indexes for a collection.
`db.foo.dropIndex({a:1})` - drop index

**Multikey index**
Presumably, you have a document `{ likes: ['tennis', 'golf'] }`. When you
create multikey index on field `likes` actually 2 index records will be
created: `likes -> tennis` and `likes -> golf`.

### Unique Indexes

This will have `unique:true` in the index createIndex options

`db.foo.createIndex({document_pattern}, {unique: true})`

### Sparse Indexes

Normally in MongoDB if a field is just simply not in a document and we created
index on it, a key will still be added to that index or that document. If we
need to create index on some rare field, we can issue
`db.foo.createIndex({document_pattern}, {sparse: true})`.

If an index is unique and sparse, 2 documents which do not include the field
that indexed exist in the same collection can exists in the same collection!

### TTL Indexes

TTL index will be deleted after a certain number of seconds.
`db.foo.createIndex({document_pattern}, {expireAfterSeconds: 3600})`

### Geospatial Indexes

`db.foo.createIndex({loc: "2dsphere"})` - this will create index using
Spherical coordinates

`db.foo.createIndex({loc: "2d"})` - this will create index using Cartesian coordinates.

### Text Indexes

You can do searching, which involves text or sentences and words and so on that
are written in human language.

Let's say we have a collection `sentences` with some data:
```
> db.sentences.count()
11

> db.sentences.find()
{ "_id" : ObjectId("58eb50cfefe608bd6761bd09"), "words" : "Cat three granite" }
{ "_id" : ObjectId("58eb50e5efe608bd6761bd0a"), "words" : "cat shrub ruby" }
{ "_id" : ObjectId("58eb50f0efe608bd6761bd0b"), "words" : "Cat shrub obsidian" }
{ "_id" : ObjectId("58eb50f5efe608bd6761bd0c"), "words" : "Cat shrub granite" }
{ "_id" : ObjectId("58eb50fdefe608bd6761bd0d"), "words" : "Cat moss ruby" }
{ "_id" : ObjectId("58eb5101efe608bd6761bd0e"), "words" : "Cat moss granite" }
{ "_id" : ObjectId("58eb5108efe608bd6761bd0f"), "words" : "Cat moss obsidian" }
{ "_id" : ObjectId("58eb510eefe608bd6761bd10"), "words" : "dog moss obsidian" }
{ "_id" : ObjectId("58eb5111efe608bd6761bd11"), "words" : "Dog moss obsidian" }
{ "_id" : ObjectId("58eb5117efe608bd6761bd12"), "words" : "Dog moss ruby" }
{ "_id" : ObjectId("58eb511fefe608bd6761bd13"), "words" : "rat tree dog" }
```

We can't query this type of documents like this:
```
> db.sentences.find({words: 'rat'})
>
```

But we can use regexp, like this:
```
> db.sentences.find({words: /rat/})
{ "_id" : ObjectId("58eb511fefe608bd6761bd13"), "words" : "rat tree dog" }
```
In general performance of this will be not so great.

So, there's a special facility that we can use:

1. Let's create an index, a text search index type on the field 'words':
```
> db.sentences.createIndex({words: 'text'})
{
	"createdCollectionAutomatically" : false,
	"numIndexesBefore" : 1,
	"numIndexesAfter" : 2,
	"ok" : 1
    }
```
Now server is going to parse out all the individual words, stem them, and then
index them all. So we're going to get multiple index entries and a B-tree
basically. Basically one per word, which involves some stemmed form of these
words. It's a little bit like an multikey index notion.

Let's try a query now:
```
> db.sentences.find({$text: { $search: "cat"} })
{ "_id" : ObjectId("58eb50cfefe608bd6761bd09"), "words" : "Cat three granite" }
{ "_id" : ObjectId("58eb50e5efe608bd6761bd0a"), "words" : "cat shrub ruby" }
{ "_id" : ObjectId("58eb50f0efe608bd6761bd0b"), "words" : "Cat shrub obsidian" }
{ "_id" : ObjectId("58eb50f5efe608bd6761bd0c"), "words" : "Cat shrub granite" }
{ "_id" : ObjectId("58eb50fdefe608bd6761bd0d"), "words" : "Cat moss ruby" }
{ "_id" : ObjectId("58eb5101efe608bd6761bd0e"), "words" : "Cat moss granite" }
{ "_id" : ObjectId("58eb5108efe608bd6761bd0f"), "words" : "Cat moss obsidian" }
```

Also we can score sentences that have multiple terms in them:
```
> db.sentences.find({$text: { $search: "cat ruby"} }, {score: {$meta:
"textScore"}, _id: 0})
{ "words" : "Dog moss ruby", "score" : 0.6666666666666666 }
{ "words" : "Cat three granite", "score" : 0.6666666666666666 }
{ "words" : "cat shrub ruby", "score" : 1.3333333333333333 }
{ "words" : "Cat shrub obsidian", "score" : 0.6666666666666666 }
{ "words" : "Cat shrub granite", "score" : 0.6666666666666666 }
{ "words" : "Cat moss ruby", "score" : 1.3333333333333333 }
{ "words" : "Cat moss granite", "score" : 0.6666666666666666 }
{ "words" : "Cat moss obsidian", "score" : 0.6666666666666666 }
```

As you can see, sentences that have both terms have higher score.

Let's sort that by score:
```
> db.sentences.find({$text: { $search: "cat ruby"} }, {score: {$meta:
"textScore"}, _id: 0}).sort({score: {$meta: "textScore"}})
{ "words" : "cat shrub ruby", "score" : 1.3333333333333333 }
{ "words" : "Cat moss ruby", "score" : 1.3333333333333333 }
{ "words" : "Cat three granite", "score" : 0.6666666666666666 }
{ "words" : "Cat shrub obsidian", "score" : 0.6666666666666666 }
{ "words" : "Cat shrub granite", "score" : 0.6666666666666666 }
{ "words" : "Cat moss granite", "score" : 0.6666666666666666 }
{ "words" : "Cat moss obsidian", "score" : 0.6666666666666666 }
{ "words" : "Dog moss ruby", "score" : 0.6666666666666666 }
```

### Background Index Creation (on the Primary of the replica set)

`db.foo.createIndex({}, {background: true})`

- Runs in background on a primary
- Runs foreground on secondaries
- Slower than foreground
- Foreground "packs" more
- can take a while (much slower than foreground)


## Explain Method

It's how MongoDB lets you examine queries and see what indexes get used. You
can call Explain on a collection to create an explainable object. You then get
information on queries for that collection by executing the following methods
against your explain object:
- aggregate
- find()
- count()
- remove()
- update()
- group()

### Query planner vs Execution stats

query planner: default
execution stats:
- includes query planner
- more information
  - time to create the query
  - number of documents returned
  - documents examined

How to view execution stats: `db.example.explain("executionStats")`

### All plans execution

- a lot like executionStats
- also runs each available plan & looks at stats

Here's how to run it: `db.example.explain("allPlansExecution")`


## Covered Queries

Covered queries is a query that you're able to answer without looking at
documents at all. In other words - it answeres the query just using the index.

## Reads vs Writes

- Generally, more indexes -> faster reads
- Generally, more indexes -> slower writes
- It is faster to build index post import than pre import


## currentOp() and killOp()

In MongoDB it's possible to see what operations are currently running on
a given mongoD or mongoS instance and to kill them.


## Database profiler

This can be run on mongoD level.

Levels (sets per database):
- 0 - off
- 2 - on
- 1 - selective "give me the slow ones, based on some threshold in milliseconds"

Examples:
`db.foo.setProfilingLevel(2)`

this will create new system collection - `system.profile`, so we can then query
that and the profile operations are actually stored in system.profile
collection for given database. 


## Mongostat & mongotop

These are part of the standart mongodb distribution, so you have them out of
the box.

```
mongostat --help
Usage:
  mongostat <options> <polling interval in seconds>

Monitor basic MongoDB server statistics.

See http://docs.mongodb.org/manual/reference/program/mongostat/ for more information.

general options:
      --help                                      print usage
      --version                                   print the tool version and exit

verbosity options:
  -v, --verbose=<level>                           more detailed log output (include multiple times for more verbosity, e.g.
                                                  -vvvvv, or specify a numeric value, e.g. --verbose=N)
      --quiet                                     hide all log output

connection options:
  -h, --host=<hostname>                           mongodb host(s) to connect to (use commas to delimit hosts)
      --port=<port>                               server port (can also use --host hostname:port)

ssl options:
      --ssl                                       connect to a mongod or mongos that has ssl enabled
      --sslCAFile=<filename>                      the .pem file containing the root certificate chain from the certificate
                                                  authority
      --sslPEMKeyFile=<filename>                  the .pem file containing the certificate and key
      --sslPEMKeyPassword=<password>              the password to decrypt the sslPEMKeyFile, if necessary
      --sslCRLFile=<filename>                     the .pem file containing the certificate revocation list
      --sslAllowInvalidCertificates               bypass the validation for server certificates
      --sslAllowInvalidHostnames                  bypass the validation for server name
      --sslFIPSMode                               use FIPS mode of the installed openssl library

authentication options:
  -u, --username=<username>                       username for authentication
  -p, --password=<password>                       password for authentication
      --authenticationDatabase=<database-name>    database that holds the user's credentials
      --authenticationMechanism=<mechanism>       authentication mechanism to use

stat options:
  -o=<field>[,<field>]*                           fields to show. For custom fields, use dot-syntax to index into
                                                  serverStatus output, and optional methods .diff() and .rate() e.g.
                                                  metrics.record.moves.diff()
  -O=<field>[,<field>]*                           like -o, but preloaded with default fields. Specified fields inserted
                                                  after default output
      --humanReadable=                            print sizes and time in human readable format (e.g. 1K 234M 2G). To use
                                                  the more precise machine readable format, use --humanReadable=false
                                                  (default: true)
      --noheaders                                 don't output column names
  -n, --rowcount=<count>                          number of stats lines to print (0 for indefinite)
      --discover                                  discover nodes and display stats for all
      --http                                      use HTTP instead of raw db connection
      --all                                       all optional fields
      --json                                      output as JSON rather than a formatted table
      --useDeprecatedJsonKeys                     use old key names; only valid with the json output option.
  -i, --interactive                               display stats in a non-scrolling interface
```

Here's sample output:
```
mongostat --port 27017
insert query update delete getmore command dirty used flushes vsize   res qrw arw net_in net_out conn                time
    *0    *0     *0     *0       0     2|0  0.0% 0.3%       0 2.56G 15.0M 0|0 0|0   159b   42.6k    2 Apr 11 11:22:44.349
    *0    *0     *0     *0       0     1|0  0.0% 0.3%       0 2.56G 15.0M 0|0 0|0   157b   42.2k    2 Apr 11 11:22:45.350
    *0    *0     *0     *0       0     1|0  0.0% 0.3%       0 2.56G 15.0M 0|0 0|0   157b   42.2k    2 Apr 11 11:22:46.352
    *0    *0     *0     *0       0     2|0  0.0% 0.3%       0 2.56G 15.0M 0|0 0|0   158b   42.3k    2 Apr 11 11:22:47.350
    *0    *0     *0     *0       0     2|0  0.0% 0.3%       0 2.56G 15.0M 0|0 0|0   158b   42.3k    2 Apr 11 11:22:48.350
    *0    *0     *0     *0       0     1|0  0.0% 0.3%       0 2.56G 15.0M 0|0 0|0   157b   42.2k    2 Apr 11 11:22:49.350
    *0    *0     *0     *0       0     2|0  0.0% 0.3%       0 2.56G 15.0M 0|0 0|0   158b   42.3k    2 Apr 11 11:22:50.349
    *0    *0     *0     *0       0     2|0  0.0% 0.3%       0 2.56G 15.0M 0|0 0|0   158b   42.4k    2 Apr 11 11:22:51.347
    *0    *0     *0     *0       0     1|0  0.0% 0.3%       0 2.56G 15.0M 0|0 0|0   157b   42.1k    2 Apr 11 11:22:52.350
    *0    *0     *0     *0       0     1|0  0.0% 0.3%       0 2.56G 15.0M 0|0 0|0   157b   42.2k    2 Apr 11 11:22:53.351
```

Mongotop:
```
mongotop --port 27017
2017-04-11T11:25:45.817+0500	connected to: 127.0.0.1:27017

                         ns    total    read    write    2017-04-11T11:25:46+05:00
         admin.system.roles      0ms     0ms      0ms
       admin.system.version      0ms     0ms      0ms
          local.startup_log      0ms     0ms      0ms
       local.system.replset      0ms     0ms      0ms
              pcat.products      0ms     0ms      0ms
          pcat.products_bak      0ms     0ms      0ms
performance.sensor_readings      0ms     0ms      0ms
      performance.sentences      0ms     0ms      0ms
      performance.system.js      0ms     0ms      0ms

```


## Homework

### 3.1

```
> db.sensor_readings.createIndex({active:1, tstamp:1})
{
	"createdCollectionAutomatically" : false,
	"numIndexesBefore" : 1,
	"numIndexesAfter" : 2,
	"ok" : 1
}
> db.sensor_readings.getIndexes()
[
	{
		"v" : 2,
		"key" : {
			"_id" : 1
		},
		"name" : "_id_",
		"ns" : "performance.sensor_readings"
	},
	{
		"v" : 2,
		"key" : {
			"active" : 1,
			"tstamp" : 1
		},
		"name" : "active_1_tstamp_1",
		"ns" : "performance.sensor_readings"
	}
]
> homework.a()
6
```

### 3.2

```
> db.currentOp()
{
	"inprog" : [
		{
			"desc" : "conn8",
			"threadId" : "0x7000062b2000",
			"connectionId" : 8,
			"client" : "127.0.0.1:64941",
			"appName" : "MongoDB Shell",
			"active" : true,
			"opid" : 84156,
			"secs_running" : 0,
			"microsecs_running" : NumberLong(13),
			"op" : "command",
			"ns" : "admin.$cmd",
			"query" : {
				"currentOp" : 1
			},
			"numYields" : 0,
			"locks" : {

			},
			"waitingForLock" : false,
			"lockStats" : {

			}
		},
		{
			"desc" : "conn2",
			"threadId" : "0x700005e17000",
			"connectionId" : 2,
			"client" : "127.0.0.1:64931",
			"appName" : "MongoDB Shell",
			"active" : true,
			"opid" : 84108,
			"secs_running" : 0,
			"microsecs_running" : NumberLong(149488),
			"op" : "update",
			"ns" : "performance.sensor_readings",
			"query" : {

			},
			"planSummary" : "COLLSCAN",
			"numYields" : 124,
			"locks" : {
				"Global" : "w",
				"Database" : "w",
				"Collection" : "w"
			},
			"waitingForLock" : false,
			"lockStats" : {
				"Global" : {
					"acquireCount" : {
						"r" : NumberLong(125),
						"w" : NumberLong(125)
					}
				},
				"Database" : {
					"acquireCount" : {
						"w" : NumberLong(125)
					}
				},
				"Collection" : {
					"acquireCount" : {
						"w" : NumberLong(125)
					}
				}
			}
		},
		{
			"desc" : "conn6",
			"threadId" : "0x700006023000",
			"connectionId" : 6,
			"client" : "127.0.0.1:64937",
			"appName" : "MongoDB Shell",
			"active" : true,
			"opid" : 42001,       <------------------------ process ID to kill
			"secs_running" : 127, <------------------------ look for this!
			"microsecs_running" : NumberLong(127239894),
			"op" : "update",
			"ns" : "performance.sensor_readings",
			"query" : {
				"$where" : "function(){sleep(500);return false;}"
			},
			"planSummary" : "COLLSCAN",
			"numYields" : 252,
			"locks" : {
				"Global" : "w",
				"Database" : "w",
				"Collection" : "w"
			},
			"waitingForLock" : false,
			"lockStats" : {
				"Global" : {
					"acquireCount" : {
						"r" : NumberLong(257),
						"w" : NumberLong(253)
					}
				},
				"Database" : {
					"acquireCount" : {
						"r" : NumberLong(2),
						"w" : NumberLong(253)
					},
					"acquireWaitCount" : {
						"w" : NumberLong(3)
					},
					"timeAcquiringMicros" : {
						"w" : NumberLong(404)
					}
				},
				"Collection" : {
					"acquireCount" : {
						"r" : NumberLong(2),
						"w" : NumberLong(253)
					}
				}
			}
		}
	],
	"ok" : 1
}
> db.killOp(42001)
{ "info" : "attempting to kill op", "ok" : 1 }
> homework.c()
12
```

### 3.3

```
> db.products.count()
12
> db.products.createIndex({"for": 1})
{
	"createdCollectionAutomatically" : false,
	"numIndexesBefore" : 1,
	"numIndexesAfter" : 2,
	"ok" : 1
}

> db.products.find({"for": "ac3"}).count()
4 <-------- 4 documents matched query

> db.products.find({"for": "ac3"}).explain("executionStats")
{
	"queryPlanner" : {
		"plannerVersion" : 1,
		"namespace" : "pcat.products",
		"indexFilterSet" : false,
		"parsedQuery" : {
			"for" : {
				"$eq" : "ac3"
			}
		},
		"winningPlan" : {
			"stage" : "FETCH",
			"inputStage" : {
				"stage" : "IXSCAN", <----------------------- Index was used
				"keyPattern" : {
					"for" : 1
				},
				"indexName" : "for_1",
				"isMultiKey" : true,
				"multiKeyPaths" : {
					"for" : [
						"for"
					]
				},
				"isUnique" : false,
				"isSparse" : false,
				"isPartial" : false,
				"indexVersion" : 2,
				"direction" : "forward",
				"indexBounds" : {
					"for" : [
						"[\"ac3\", \"ac3\"]"
					]
				}
			}
		},
		"rejectedPlans" : [ ]
	},
	"executionStats" : {
		"executionSuccess" : true,
		"nReturned" : 4,
		"executionTimeMillis" : 0,
		"totalKeysExamined" : 4,
		"totalDocsExamined" : 4, <------------------- 4 documents were examided
		"executionStages" : {
			"stage" : "FETCH",
			"nReturned" : 4,
			"executionTimeMillisEstimate" : 0,
			"works" : 5,
			"advanced" : 4,
			"needTime" : 0,
			"needYield" : 0,
			"saveState" : 0,
			"restoreState" : 0,
			"isEOF" : 1,
			"invalidates" : 0,
			"docsExamined" : 4,
			"alreadyHasObj" : 0,
			"inputStage" : {
				"stage" : "IXSCAN",
				"nReturned" : 4,
				"executionTimeMillisEstimate" : 0,
				"works" : 5,
				"advanced" : 4,
				"needTime" : 0,
				"needYield" : 0,
				"saveState" : 0,
				"restoreState" : 0,
				"isEOF" : 1,
				"invalidates" : 0,
				"keyPattern" : {
					"for" : 1
				},
				"indexName" : "for_1",
				"isMultiKey" : true,
				"multiKeyPaths" : {
					"for" : [
						"for"
					]
				},
				"isUnique" : false,
				"isSparse" : false,
				"isPartial" : false,
				"indexVersion" : 2,
				"direction" : "forward",
				"indexBounds" : {
					"for" : [
						"[\"ac3\", \"ac3\"]"
					]
				},
				"keysExamined" : 4,
				"seeks" : 1,
				"dupsTested" : 4,
				"dupsDropped" : 0,
				"seenInvalidated" : 0
			}
		}
	},
	"serverInfo" : {
		"host" : "delorean.local",
		"port" : 27017,
		"version" : "3.4.3",
		"gitVersion" : "f07437fb5a6cca07c10bafa78365456eb1d6d5e1"
	},
	"ok" : 1
}

```

### 3.4

1. Document level locking
2. Data compression

