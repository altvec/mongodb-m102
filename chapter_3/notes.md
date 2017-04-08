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


### MMAP v1

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


#### Locking

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
