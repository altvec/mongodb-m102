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

What Storage Engines does affect:
- how data is written to disk
- how data is deleted/removed from disk
- how data is read from disk
- data file format (different storage engines can implement different types of compression and different ways of storing the BSON for mongodb. We are still working with BSON, but underlying data structers on storage level can be different)
- format of indexes (MMAPv1 uses Btrees, WiredTiger uses B+ trees)

What Storage Engines doesn't do:
- change how you perform queries
- change behavior at the cluster level, so it won't affect, say, how your system scales with additional machines

Pluggable storage engines are the big feature in MongoDB 3.0, so now you can choose which storage engine you're using (in recent versions it's WiredTiger by default). There are who choices:
- WiredTiger
- MMAPv1

### MMAP v1

MMAPv1 maps the data files directly into virtual memory, allowing OS to do most of the work of the storage engine.

