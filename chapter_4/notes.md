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


## Starting replica set

Prepare replica set for initialization:
```
mkdir -p ./db-data/{r1,r2,r3}

mongod --port 27001 --replSet abc --dbpath ./db-data/r1 --logpath ./log.1 --logappend --oplogSize 50 --smallfiles
mongod --port 27002 --replSet abc --dbpath ./db-data/r2 --logpath ./log.2 --logappend --oplogSize 50 --smallfiles
mongod --port 27003 --replSet abc --dbpath ./db-data/r3 --logpath ./log.3 --logappend --oplogSize 50 --smallfiles

```

Initiating the set:

1. Specify config:
```
cfg = {
    _id : "abc",
    members : [
        {_id : 0, host : "localhost:27001"},
        {_id : 1, host : "localhost:27002"},
        {_id : 2, host : "localhost:27003"}
    ]
}
```
Best practices:
- don't use raw ip addresses
- don't use names from /etc/hosts
- use DNS
    - pick an appropriate TTL (e.g. minutes)

2. Initial data: `replSetInitiate` or in the shell `rs.initiate(cfg)`
```
> rs.initiate(cfg)
{ "ok" : 1 }
abc:SECONDARY>
abc:PRIMARY>
```
Now our server becomes Primary.

### Replica set status

```
abc:PRIMARY> rs.status()
{
	"set" : "abc",
	"date" : ISODate("2017-04-14T06:03:40.245Z"),
	"myState" : 1,
	"term" : NumberLong(1),
	"heartbeatIntervalMillis" : NumberLong(2000),
	"optimes" : {
		"lastCommittedOpTime" : {
			"ts" : Timestamp(1492149817, 1),
			"t" : NumberLong(1)
		},
		"appliedOpTime" : {
			"ts" : Timestamp(1492149817, 1),
			"t" : NumberLong(1)
		},
		"durableOpTime" : {
			"ts" : Timestamp(1492149817, 1),
			"t" : NumberLong(1)
		}
	},
	"members" : [
		{
			"_id" : 0,
			"name" : "localhost:27001",
			"health" : 1,
			"state" : 1,
			"stateStr" : "PRIMARY",
			"uptime" : 4050,
			"optime" : {
				"ts" : Timestamp(1492149817, 1),
				"t" : NumberLong(1)
			},
			"optimeDate" : ISODate("2017-04-14T06:03:37Z"),
			"electionTime" : Timestamp(1492149327, 1),
			"electionDate" : ISODate("2017-04-14T05:55:27Z"),
			"configVersion" : 1,
			"self" : true
		},
		{
			"_id" : 1,
			"name" : "localhost:27002",
			"health" : 1,
			"state" : 2,
			"stateStr" : "SECONDARY",
			"uptime" : 503,
			"optime" : {
				"ts" : Timestamp(1492149817, 1),
				"t" : NumberLong(1)
			},
			"optimeDurable" : {
				"ts" : Timestamp(1492149817, 1),
				"t" : NumberLong(1)
			},
			"optimeDate" : ISODate("2017-04-14T06:03:37Z"),
			"optimeDurableDate" : ISODate("2017-04-14T06:03:37Z"),
			"lastHeartbeat" : ISODate("2017-04-14T06:03:39.978Z"),
			"lastHeartbeatRecv" : ISODate("2017-04-14T06:03:38.743Z"),
			"pingMs" : NumberLong(0),
			"syncingTo" : "localhost:27001",
			"configVersion" : 1
		},
		{
			"_id" : 3,
			"name" : "localhost:27003",
			"health" : 1,
			"state" : 2,
			"stateStr" : "SECONDARY",
			"uptime" : 503,
			"optime" : {
				"ts" : Timestamp(1492149817, 1),
				"t" : NumberLong(1)
			},
			"optimeDurable" : {
				"ts" : Timestamp(1492149817, 1),
				"t" : NumberLong(1)
			},
			"optimeDate" : ISODate("2017-04-14T06:03:37Z"),
			"optimeDurableDate" : ISODate("2017-04-14T06:03:37Z"),
			"lastHeartbeat" : ISODate("2017-04-14T06:03:39.978Z"),
			"lastHeartbeatRecv" : ISODate("2017-04-14T06:03:38.772Z"),
			"pingMs" : NumberLong(0),
			"syncingTo" : "localhost:27001",
			"configVersion" : 1
		}
	],
	"ok" : 1
}
```

### Replica set commands

```
abc:PRIMARY> rs.help()
	rs.status()                                { replSetGetStatus : 1 } checks repl set status
	rs.initiate()                              { replSetInitiate : null } initiates set with default settings
	rs.initiate(cfg)                           { replSetInitiate : cfg } initiates set with configuration cfg
	rs.conf()                                  get the current configuration object from local.system.replset
	rs.reconfig(cfg)                           updates the configuration of a running replica set with cfg (disconnects)
	rs.add(hostportstr)                        add a new member to the set with default attributes (disconnects)
	rs.add(membercfgobj)                       add a new member to the set with extra attributes (disconnects)
	rs.addArb(hostportstr)                     add a new member which is arbiterOnly:true (disconnects)
	rs.stepDown([stepdownSecs, catchUpSecs])   step down as primary (disconnects)
	rs.syncFrom(hostportstr)                   make a secondary sync from the given member
	rs.freeze(secs)                            make a node ineligible to become primary for the time specified
	rs.remove(hostportstr)                     remove a host from the replica set (disconnects)
	rs.slaveOk()                               allow queries on secondary nodes

	rs.printReplicationInfo()                  check oplog size and time range
	rs.printSlaveReplicationInfo()             check replica set members and replication lag
	db.isMaster()                              check who is primary

	reconfiguration helpers disconnect from the database so the shell will display
	an error, even if the command succeeds.
```


### Reading and Writing

By default you can't read from Secondaries:
```
abc:SECONDARY> db.foo.find()
Error: error: {
	"ok" : 0,
	"errmsg" : "not master and slaveOk=false",
	"code" : 13435,
	"codeName" : "NotMasterNoSlaveOk"
}
```

### Read preference

A.k.a `slaveOk()` - indicate that we're ok with eventually consistent reads
from Secondaries.

Reasons to do this:
- geography (latency)
- separate a workload (for analytics/reporting)
- availability (during a failover)

There are following available options when you connecting to DB from client side:
- primary (default)
- `!` `*` primaryPreffered
- `*` secondary
- `!` `*` secondaryPreferred
- `!` `*` nearest (in terms of network latency)

`*` - secondary is possible
`!` - primary is possible

- When in doubt, use primary preference (default).
- When remote, use nearest (also can be good for even read loads)
- Use secondary for certain reporting workloads, bearing in mind the
    possibility of lag

So, clearly if we used primary, we're going to only send the query to the
primary.

*Nearest may be the most even for load distribution.*


## Homework

### 4.1

Answer is: 5001

### 4.2

Answer is: 5002

### 4.3

Answer is: 5

### 4.4

Answer is: 6

### 4.5

Answer is: R
