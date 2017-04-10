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
