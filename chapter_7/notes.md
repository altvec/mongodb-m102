# Security and backup

## Security

1. Trusted environment (lock things down at network level)
2. MongoDB authentication:
    - --auth (security client access)
    - --keyfile (shared secret key used intra-cluster)
3. Run MongoDB with SSL

- authentication
    - MongoDB challenge/response
    - x.509/ssl
    - kerberos *
    - LDAP *
- access control / authorization
- encryption
- network setup
- auticity *


Only the server and router need --auth. They then require authentication (with username and password) for all clients ,driver or shell, that connect to them.

Using `--keyfile` with a replica set, database contents are send over the
network between mongod nodes unencrypted. It doesn't encrypt your data, it just
makes sure that the servers authenticate one another using the keyfile.
However, if the key file were sent across the network unencrypted, they
wouldn't be of much use!

Items with * are available only in MongoDB Enterprise Edition.

**By default security is off.**

Let's make it [secure](http://docs.mongodb.org/manual/security/):

- Start mongod: `mongod --auth --dbpath data`
- Connect from local host with mongo:

`> use admin
switched to db admin
> var me = { user: "username",
...          pwd: "passwd",
...          roles: [
...            "userAdminAnyDatabase",
...            "readWriteAnyDatabase"
...          ]
...}
> db.createUser(me)
Successfully added user
`

- Reconnect to mongodb:

`mongo localhost/admin -u username -p passwd`

- Create another user with permissions for current database:

`
> use test_db2
> var a = { user: "testuser", pwd: "testpwd", roles: ["readWrite"] }
> db.createUser(a)
`

Available roles:

- read
- readWrite
- dbAdmin
- userAdmin
- clusterAdmin
- readAnyDatabase
- readWriteAnyDatabase
- dbAdminAnyDatabase
- userAdminAnyDatabase

Types of users (clients):

- "admin" users
    - can do administration
    - created in the "admin" database
    - can access all databases
- "regular" users
    - access specific database
    - read/write or readOnly

## Backups and Restore

Methods for individual set/server:

- mongodump
- filesystem snapshot
- backup from secondary
    - shutdown, copy files, restart

### Mongodump / mongorestore

Can be done on hot system

- `mongodump --oplog`
- `mongorestore --oplogReplay`

### Filesystem snapshots

Use journaling!

Use `db.fsyncLock()` before snapshot
Use `db.fsyncUnlock()` after snapshot

With Lock you can't do reads/writes!

- LVM snapshots
- ZFS snapshots
- Amazon facilities

### Backups + sharding

1. Turn off balancer (so there is no chunk migrations)
`mongos --host some_mongos --eval "sh.stopBalancer()"` make sure that worked!
2. Backup config database `mongodump --host some_mongos_or_cfg_server --db config`

3. Backup each shard's replica set
`mongodump --host shard1_svr1 --oplog /backups/cluster1/shard1`
`mongodump --host shard2_svr1 --oplog /backups/cluster1/shard2`
`mongodump --host shard3_svr1 --oplog /backups/cluster1/shard3`

4. Turn on balancer `mongo --host some_mongos --eval "sh.startBalancer()"`

*After stopping balancer on sharded cluster you may need to wait for a live
migration to finish before the balancer stops!*

## Additional features

- "capped collections" (circular queues with preallocated max size)
- TTL collections (auto aged-out of old documents). You need to create special
    index for this.
- GridFS. BSON size is limited to 16MB. With GridFS you can store more than
    that (large blob storage).

## GridFS

Basically chunk up large file.

## Hardware & software tips

- faster CPU clock is preffered vs more CPU cores
- RAM is good, more RAM is better
- 64bit architecture
- virtualization is OK, but not required
- disable NUMA
- SSDs are good
    - wear endurance is not a problem actually
    - reserve some empty space (unpartitioned) ~20%
- filesystem cache is most of mongod's memory usage
- check readahead settings for your FS (small value)

Other recommendations you can find
[here](http://docs.mongodb.org/manual/administration/production-notes/)

## Additional resources

- docs - mongodb.org
- driver docs
- bug database/features
    - jira.mongodb.org
- support forums
- IRC (freenode.net/#mongodb)
- github.com (source code)
- blog.mongodb.org
- twitter @mongodb
- MMUGs


