# Replication Part 2

- Voting
- Write Concern
- Capacity Planning

Suppose, we have the following configuration of replica set:

```
cfg = {
    _id : "abc",
    members : [
        {_id : 0, host : "localhost:27001"}, <options>,
        {_id : 1, host : "localhost:27002"}, <options>,
        {_id : 2, host : "localhost:27003"}, <options>
    ]
}
```

There are some `options`, that we can use:

**Arbiter** - `arbiterOnly: true`

Arbiters has no data, but can participate in election of Primary. Arbiters can be used for:

- Make an odd number of votes in the replica set
- To spread the replica set over more datacenters
- To protect against network splits

**Priority** - `priority: <n>`

Priority value can be any positive number (even decimals) from 0 to ...

- 1 - default value
- 0 - never primary
- 2 or more - greater chance to be primary

**Hidden** - `hidden: true` & **slaveDelay** - `slaveDelay: true`

Delayed secondary member of replica set, it will be always behind the primary for certain amount of time. Hidden node can't be readed directly.

To configure a delayed secondary member, set its priority value to 0, its hidden value to true, and its slaveDelay value to the number of seconds to delay.

Also, a delayed secondary has other disadvantages: since it can't become primary, it's less useful for ensuring high availability than a standard secondary.

If you would like to be able to undo a human error on your replica set, you also have other options available:

- You can replay your oplog up to the error.
- You can use MMS Backup.

**Votes** - `votes:<n>`. Do not use it in production! Also, it's essentialy deprecated in MongoDB >= 3.0

## Applied Reconfiguration

## Cluster wide commits and write concern

Principles:

- Write is truly committed upon application at a majority of the replica set
- We can get acknowlegment of this specfying `w` parameter:

`db.foo.getLastError({ w:'majority', wtimeout: 80000 })`

## Write concern

1. no call to GLE (getLastError)
2. w: 1
3. w: 'majority'
4. w: all
5. variation (call every N)
6. w: <tag>

Write concern is set on collection level.

## Write concern use cases

- No call to GLE:
  - page view counter
  - logging

- w: '1'
  - useful for not super critical writes (dupkey constraint)

- w: 'majority'
  - most things that are important

- w: 'all'
  - flow control

- w: variation "call every N"
```
for (i = 0; i < N; i++ ) {
  db.foo.insert(arr[i]);
  if (i % 500 == 0 || i == N - 1) {
    getLastError({w: 'call every N'})
  }
}
```

For getLastError/WriteConcern with `w=3`, if you have an arbiter, it doesn't counts as one of the 3.

getLastError() doesn't need to be called if you are using default Write Concern.

## Replica sets in a single datacenter

- 3 members
- 2 members + arbiter
- 2 members with manual failover
- 5 members (bad idea actually)
- 2 large + 1 small members (bad idea in case of failure of one of the large members)

## Replica sets in a multiple datacenters

- 2 datacenters with data members + 1 remote arbiter

## Mixed storage engine replica sets

- Different storage engines for different members

Replication sends _operations_ from primary, _not bytes_!

Reasons for creating mixed RS:

- testing
- upgrading

Caveat: entire data set goes over the wire!

## Homework

### 5.1

Set up a replica set that includes an arbiter.

To demonstrate that you have done this, what is the value in the "state" field for the arbiter when you run rs.status()?

```
> cfg = {
... _id: 'test',
... members: [
... {_id: 0, host: 'localhost:27001'},
... {_id: 1, host: 'localhost:27002'},
... {_id: 2, host: 'localhost:27003'}
... ]
... }
{
	"_id" : "test",
	"members" : [
		{
			"_id" : 0,
			"host" : "localhost:27001"
		},
		{
			"_id" : 1,
			"host" : "localhost:27002"
		},
		{
			"_id" : 2,
			"host" : "localhost:27003"
		}
	]
}
> cfg.members[2]
{ "_id" : 2, "host" : "localhost:27003", "arbiterOnly" : true }
> rs.initiate(cfg)
{ "ok" : 1 }
test:PRIMARY> rs.status().members[2].stateStr
ARBITER
test:PRIMARY> rs.status().members[2].state
7
```

### 5.2

You have just been hired at a new company with an existing MongoDB deployment. They are running a single replica set with two members. When you ask why, they explain that this ensures that the data will be durable in the face of the failure of either server. They also explain that should they use a readPreference of "primaryPreferred", that the application can read from the one remaining server during server maintenance.

You are concerned about two things, however. First, a server is brought down for maintenance once a month. When this is done, the replica set primary steps down, and the set cannot accept writes. You would like to ensure availability of writes during server maintenance.

Second, you also want to ensure that all writes can be replicated during server maintenance.

Which of the following options will allow you to ensure that a primary is available during server maintenance, and that any writes it receives will replicate during this time?

Check all that apply.

Answer:
- Add two data bearing members plus one arbiter
- Add another data bearing node

### 5.3

You would like to create a replica set that is robust to data center failure.

You only have two data centers available. Which arrangement(s) of servers will allow you to be stay up (as in, still able to elect a primary) in the event of a failure of either data center (but not both at once)? Check all that apply.

Answer: none of the above

### 5.4

Consider the following scenario: You have a two member replica set, a primary, and a secondary.

The data center with the primary goes down, and is expected to remain down for the foreseeable future. Your secondary is now the only copy of your data, and it is not accepting writes. You want to reconfigure your replica set config to exclude the primary, and allow your secondary to be elected, but you run into trouble. Find out the optional parameter that you'll need, and input it into the box below for your rs.reconfig(new_cfg, OPTIONAL PARAMETER).

Hint: You may want to use this documentation page to solve this problem.

Your answer should be of the form { key : value } (including brackets). Do not include the rs.reconfig portion of the query, just the options document.

Answer: `{force: true}`
