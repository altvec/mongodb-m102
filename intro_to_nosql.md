# Introduction to NoSQL

- Driven by the demands of "BigData":
    - Google
    - Facebook
    - Amazon

- Really huge amounts of data:
    - Distributed environment
    - High availability

- CAP theorem


## CAP theorem

CAP theorem states *It is impossible for a distributed computer system to
simultaneously provide all three of the guarantees*:

- **Consistency** - all nodes in a distributed system see the same data at the same
    time
- **Availability** - all requests receive a response about whether it was
    successful or failed
- **Partition Tolerance** - the system continues to operate despite arbitrary
    message loss of failures of part of the system

Relational databases emphasise *Consistency*, so either Availability or
Partition Tolerance will suffer.

NoSQL databases emphasise Availability and Partition Tolerance + eventual
consistency (twitter feed do not need to show updated from the last few seconds
immediately)

## NoSQL database types

- Sorted ordered column-oriented stores
- Key/value stores
- Document databases

### Sorted ordered column-oriented stores

- Google BigTable
- Apache Hbase
- Baidu HyperTable

### Key/value stores

- Membase (built on memcached)
- Redis
- Cassandra

### Document databases

- MongoDB
- CouchDB
- RavenDB
