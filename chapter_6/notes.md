# Chapter 6 - Scalability

- Sharding
- Setting up your cluster
- Implementation details

## Sharding and data distribution

Sharding is kinda like partitions. We use sharding to scale out horizontally.
A given BSON document can live on one and only one shard at a given point in time. Within a shard we can have replication.

### Data distribution

In a MongoDB distribution based on a shard key (in a context of a given collection).
Range-based partitioning - a given key range will live on a particular shard.

```
+----------|-----------|------------+
| NAME LOW | NAME HIGH | SHARD      |
+----------|-----------|------------+
| Jane     | Joe       | S2         | <-- "chunk"
+----------|-----------|------------+
| Joe      | Kyle      | S0         |
+----------|-----------|------------+
                ...
+----------|-----------|------------+
| Matt     | Mike      | S1         |
+----------|-----------|------------+
```

**Chunk** - all the documents in a given key range (~100MB each).

The reasons behind range-based partitioning:

- we can do queries that involve ranges with some efficiency
- sorting

**Chunk** operations:

1. Split (basically split one huge key range by some median into many smaller key ranges).

```
+----------|-----------|------------+
| NAME LOW | NAME HIGH | SHARD      |
+----------|-----------|------------+
| Joe      | Kate      | S0         |
+----------|-----------|------------+
| Kate     | Kyle      | S0         |
+----------|-----------|------------+
```
Split is inexpensive operation. Split will make sure that there are no huge chunks.

2. Migrate - balance between different shards in the same system.

Migrate is actually going to move data from shard to shard when it sees there's lack of balance between the number of chunks on the different shards.

```
+----------|-----------|------------+
| NAME LOW | NAME HIGH | SHARD      |
+----------|-----------|------------+
| Joe      | Kate      | S0         |
+----------|-----------|------------+
| Kate     | Kyle      | S1         | this will be copied from S0 to S1
+----------|-----------|------------+
```

This op is not inexpensive! You can read and write to "migrating" chunk.

## Sharding process

```
                       S0              S1               S(N-1)

                   +--------+      +--------+         +--------+
     Replica Set   | mongod |      | mongod |         | mongod |
                   +---|----+      +----|---+         +----|---+
                       |                |                  |
                       |                |                  |
                       +-----------------------------------+
                                        |
                                        |
                                        |
     +--------+                      +--|-----+
     | config |----------------------| mongos |
     +--------+                      +--------+
                                         |
Small mongod                             |
storing metadata        +-----------------------------------+
                        |                |                  |
                        |                |                  |
                        |                |                  |
                        |                |                  |
                   +----|---+        +---|----+        +----|---+
                   | client |        | client |        | client |
                   +--------+        +--------+        +--------+
```

**mongos** - has no persistent state, so there's no data files here. This is a load balancer.

**config servers** - metadata store (should be minmum 3 servers in a production MongoDB cluster).

**mongod** - data stores/database.

## Cluster setup

Things to consider:

- how many shards initialy
- replication factor
- number of mongos processes
- number of config servers (usually 3)

Best practices:

- run mongos on the standart mongodb tcp port 27017
- do not run shard server mongod's nor config servers on that port

For each shard:

1. Initiate the replica set
2. "Add" the shard to the cluster

## Sharding a collection

When you shard a collection you specify a shard key. By default collections are not sharded.

Targeted query - use shard key, better performance.
Scatter gather - query all shards, worse performance.

Example: Your shard key for the people collection is `{ friends : 1, name : -1 }`. You also have an index on `{ name : 1, phoneNumber : 1 }`. Targeted queries would be the queries that use either the shard key, or a shard key prefix, are not scatter gather. They will be targeted only at those shards that contain the documents that will be returned by the query. Like this:

- db.people.find( { friends : "Bob", phoneNumber : "555-123-4444" } ) - this uses the shard key prefix;
- db.people.find( { friends : "Doug", name : "Emily" } ) - this uses the shard key.

## Shard key selection

- the shard key is common in queries for the collections
- good cardinality (granularity)
- consider compound shardkey
- is the key monotonically increasing? Choosing timestamp or BSON ObjectID's as shard key is a bad idea (unbalanced writes will occur).

## Shard key selection example

Suppose we have orders collection like this:

```
{
  _id: ___,
  company: ___,
  items: [
    {___},
    {___},
    {___},
    ...
    {___}
  ],
  date: ___,
  total: ___
}
```

What key to choose?

Bad ideas:

- using _id (monotonically increasing)
- using company (not enough cardinality)

Solution - use compound key like `{company:1, _id: 1}` or even better: `{company:1, date:1}`

## Processes and Machine Layout

- shard servers (mongod --shardsvr)
- config servers (mongod --configsvr) - 3 is recommended number
- mongos (mongos)

## Tips and best practices

- only shard the big collections
- pre-split if bulk loading
- pick shard key with care, they aren't easily changeable
- be cognizant of monotonically increasing shard keys
- adding a shard is easy but takes time
- use logical server names for config servers
- don't directly talk to anything except mongos except for dba work
- keep non-mongos processes off of 27017 to avoid mistakes
