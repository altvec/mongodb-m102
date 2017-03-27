# Concepts + Rationale

1. Scale
  1. A hardware -> paralellism (more CPU cores, more servers), clouds
  2. Scale up -> BigData

2. Development speed
  1. Make application development easier
  
3. Handling complex data
  1. Complex structured, unstructured or polymorphic data
  

## Scale

Traditionaly databases are scalled vertically - just buy a bigger box.
Pros:
* Easy to maintain

Cons:
* Expensive and hard to "scale"
* If it fails it fails completely

More advanced method - scale horizontally, i.e. add more servers to the cluster.
Pros:
* Improved capacity and speed
* Easy to scale (just add more boxes)
* Can be ran on commodity hardware (not some proprietary expensive hardware)
* Redundancy

Cons:
* Higher failure probability due to sheer number of boxes
* Network latency and bandiwdth eating up since the boxes must communicate with each other
* Coordination of servers (need some system that coordinates boxes work)

Scaling RDBMS and NoSQL systems in general: more features - less scaling possibilities and less speed.


## SQL and complex transactions

There are no joins and complex transactions support in MongoDB, 'cause it's a hard problem in a distrubuted enviroment (multiple servers). So we need a different data model.


## Documents overview

Document-oriented databases (which is mongodb) works with JSON (language independent) documents.
JSON represents a flexible and concise framework for specifying queries as well as storing records.
JSON syntax is similar to that of common data structures used in many programming languages and is, therefore, familiar to developers.
```
Example doc:

{
  x: 3,
  y: 'abc',
  z: [1, '2', 3],
  _id: 'abc123'
}
```

MongoDB query syntax is actually JSON!


## JSON types

There are the following types in JSON:
* strings
* numbers
* booleans
* null
* arrays
* objects/disctionaries

```
{
  'name': 'joe',
  'age': 31,
  'voted': true,
  'school': null,
  'likes': ['football', 'math', 'programming'],
  'address': {
    'city': 'Cleveland',
    'state': 'OH'
  }
}
```

## BSON (serialization format)

BSON - binary JSON.

Goals of BSON:
1. Fast scannability (ability to skip 'key' fields without getting 'values')
2. Data types ('date' datatype, BigData, ObjectID)

### BSON Format

Example doc: `{ a: 3, b: 'xyz' }`

BSON equivalent:
```
+-----------------------------------------------------+
| length | type | a | 3 | type | b | length | xyz | 0 |
+--------|--------------|-------------------------|---+
         |<--- a: 3 --->|<-------- b: xyz ------->|

* 32 bits length of BSON document
* 32 bits length of entire document
* 8 bits field type (int32) - 'a'
* 16 bits 'a' key
* 32 bits 'a' value
* 8 bits field type (string) - 'b'
* 16 bits 'b' key
* 4 bits length of the 'b' value
* 'b' value
* 0 - end of BSON document
```


## Basic Queries

Queries are represented as BSON (JSON) declarations.
Some examples:
```
# show databases
show dbs

# show collections in current database
show collections

# find all docs in the collection "products"
db.products.find()

# find first document in the collection "products"
db.products.fineOne()

# this is equivalent of previous command
db.products.findOne( {} )

# limit output to 5 docs
db.products.find().limit(5)

# select by field (by default object's id is also selected)
db.products.find({},{name:1})

# select products with price greater or equal than 200, displaying only name and price and _id
db.products.find({ price: {$gte: 200}}, {name:1, price:1 })
```

Contrast with SQL:
```
MongoDB -> {a : 99}
SQL -> WHERE a = 99

db.products.find( { price: 12.5 } )
SELECT * from products WHERE price = 12.5
```


## Operators

Basically 2 types: quering and updating

### Quering

$gte - greater than or equal
$gt - greater than
$lt - lower than
$lte - lower than or equal
$or
$not
$in
$nin - not in
$type
$exists - check if field exists

By default query like this {x:1, y:2} is enterpreted as "x:1" AND "y:2"!

### Updating

$inc
$set
$attoToSet
$attToAdrr


## Quering nested documents

`{x: {a:1, b:3} }`

Where a=1 inside the x document?

"Dot notation" to the resque:
`find({"x.a": 1})`


## Sorting

`db.collection_name.find(___).sort(___)`

`.sort(key_pattern)`

key_pattern: `{field_name: direction}`

directions:
1  - ASCENDING
-1 - DESCENDING

Example:
```
db.products.find({price: {$exists:true}}, {name:1, price:1}).sort({price:1})

here we use 'price:{$exists:true}' because there are some documents without the price field in the Products collection.
```

### Multiple sort keys

`.find().sort({lastname: 1, firstname: 1})`

### Order of functions

1. Query
2. Sorting
3. Skipping
4. Limiting

## MongoDB Deployments

* Standalone Deployment
  * Simplest MongoDB deployment: just one server. No redundancy, no scaling.
* Replica set deployment
  * Provides durability and availability
  * This involves replicating data to other servers, which can take over if the primary server goes down.
* Shared Cluster Deployment
  * Involves spreading your data across multiple "shards"
  * Each shard is its own replica set deployment
  * Not only provides durability and availability, but also scales.
