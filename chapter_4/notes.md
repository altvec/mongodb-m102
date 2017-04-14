# Replication

- Durability
- Availability

Replication - redundant copies of the same data across set of machines.

Reasons to do replication:
- HA (high availability)
- Data safety
- Disaster recovery
- Scalability (you can read from replicas if you will, but generally it's may not be a good idea, because replicas can lag behing a bit)

Replication:
- **Replication is asynchronous**
- **Single Primary at a given point in time**

There is a possibility for synchronous replication, where client will wait for ack from replicas (actually, client sent request to primary, then request has to be propagated to replicas before you get an ack). Downside - huge latency across network.

To summarize:
- MongoDB replication works on commodity hardware
- Supports a model of replication with a single primary and multiple secondaries
- Works across wide area network
- Provides eventual consistency


## Statement-based vs Binary replication

**Statement-based**: basically it will run your `db.foo.insert({foo:'bar'})` on primary and on every other secondaries. Pros: you can replicate even if the replica set has servers running different storage engines (with or without compression) and different versions of MongoD itself.

**Binary**: replicate files state (bytes), e.g. for file 12 on some offset with some length insert some data.
Binary is more efficient, but we must have exact byte for byte physical content of data files matching on the secondary in the primary.
Downsides: may not work if there is version difference between primary and secondary.


## Replica set

Replica set is just a notion of a replication clusters. There's one Primary and can
be more than one Secondaries. Group of servers, that are supposed to have the same
data, that's what a replica set is.
*Replication Factor* - number of members in a replica set.

Benefits of replica sets:
- automatic failover
- automatic node recovery

### Failover

"Consensus" of majority of nodes determine what node is a Primary in case of network
partition/failover event.

On the client side, mongo drivers are replica set aware, so the driver is smart
enough to realize when some node is down and it need go to talk to newly
elected primary.

**Warn**: failover is not instantaneous, it actually takes a bit of time to
occur.

### Recovery

There are 3 ways of handlind recovery procedure:
1. Complete wipe of previous primary (which now becomes secondary) and
   replicate all data to it from newly primary. In this case we loose all the
   commited data that hasn't been replicated before failover.
2. Manually roll back all commits that hasn't been replicated before failver
   and apply them on newly elected primary.
3. Automatically (which is done by MongoDB) roll back all commited writes on
   previous primary that hasn't been replicated and archive them.
