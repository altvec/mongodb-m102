# CRUD and administrative commands

## Inserting documents

Create database:

```
> user create_lesson_db
switched to db create_lesson_db
```

View current database in use:

```
> db
create_lesson_db
```

Show collections:

```
> show collections
```

Inserting an object:

```
> db.sample.insert({a:1})
```

Show collections again. Now we can see a new collection - 'sample':

```
> show collections
sample
system.indexes
```

Find all documents in the 'sample' collection:

```
> db.sample.find()
{ "_id" : ObjectID("535a9a9033352f009db551bfd"), "a" : 1 }
```

ObjectID is generated by mongodb driver, but you can specify it youself.


## Updating documents

You can update one or more documents at a time. Syntax for the update command is something like the following: `db.<collection>.update(<where>, <document_or_partial, update_expression>, <upsert>, <multi>)`.

`<multi>` - update multiple documents
`<upsert>` - update document or insert if not present

There are two types of update:
- Full document update/replacement
- partial update (changing only one field)

Let's assume that we have a collection `test` in `pcat` database.

```
> db
pcat

> t.find()
{ "_id" : ObjectID("535a9a9033352f009db551bf3"), "x" : "hello" }
{ "_id" : ObjectID("535a9a9033352f009db551bf2"), "x" : "hello" }
{ "_id" : ObjectID("535a9a9033352f009db551bf1"), "x" : "hello" }
{ "_id" : 100, "x" : "hello" }
{ "_id" : 101, "x" : "hello" }
```

Let's update document with id = 100:
```
> t.update( { '_id' : 100 }, { '_id' : 100, x : "hello world", y : 123 })
WriteResult( {"nMatched" : 1, "nUpserted" : 0, "nModified" : 1 })
```

**Remember: you can not change object Id!**

`_id` field must exist in every document, must be unique inside the collection and is automatically indexed by the MongoDB.

### Partial updates

Suppose we have a collection, 'cars', with one document preexisting:
`{ "_id" : 100, "name" : "GTO", "year" : 1969, "color" : "red" }`

and we want to update it by adding field `available : 1`.

This is how to do it:
```
db.cars.update( {_id:100}, {$set:{available:1}} )
```

The query part, `{_id:100}` identifies the document we want to update, and the ipdate part, `{$set:{available:1}}` sets the "available" field to 1.

### Multiple documents updates, upserts

`db.collection.update( query_document, update_document, [options_document] )`

where optional *options_document* has any one or more of the following optional parameters:
- `upsert : true/false`
- `multi : true/false`
- `writeConcern : document`

If `multi : false` of not specified at all, only first matched document will be updated.

If `upsert : true` and document or field doesn't exist it will be created/added.

Example. We have the following document:
```
{ _id : 'Jane', likes : ['tennis', 'golf'] }
```
how to add that this user likes 'football'? We want to record this even if the user doesn't yet have a document. We also want to avoid duplicate items in the 'likes' field. The solution is this:
```
db.users.update( {_id: 'Jane'}, {$addToSet: {'likes': 'football'}}, {'upsert': true})
```
*$push* would almost work, but *$addToSet* is better because it prevents duplicate items from being added to the array. 


## Removing documents

This is straightforward: `db.collection.remove( query_document )`. It's just like a find query, but instead of `find` we issue `remove` method that deletes all documents match the query. In place of *remove*, you can also use *deleteMany*, as of MongoDB 3.2


## Bulk write operations

There are 2 basic forms of bulk requests:
- ordered
- unordered (more efficient)

Example:
```
> var bulk = db.items.initializeUnorderedBulkOp();
> // var bulk = db.items.initializeOrderedBulkOp(); 
> 
> bulk.insert( { item: 'abc', defaultQty: 100, class: 'A', points: 100 } );
> bulk.insert( { item: 'efg', defaultQty: 200, class: 'C', points: 200 } );
> bulk.insert( { item: 'hij', defaultQty: 300, class: 'D', points: 300 } );
> bulk.insert( { item: 'klm', defaultQty: 400, class: 'F', points: 400 } );
> bulk.insert( { item: 'opq', defaultQty: 500, class: 'B', points: 500 } );
>
> bulk.execute() // this will send documents to server
BulkWriteResult({
    "writeErrors" : [],
    "writeConcernErrors" : [],
    "nInserted": 5,
    ...
})
```

## Commands

User commands:
- isMaster
- aggregate
- mapReduce
- count
- findAndModify

Administrative commands (runs agains 'admin' database):
- drop - drops collection (`db.collection.drop()`)
- create
- compact
- serverStatus - shows server status, obviously
- repSetGetStatus
- addShard
- createIndex
- dropIndex
- currentOp  - shows what is running on the server right now (look for 'secs_running')
- killOp - kill running operation by opration ID
- stats - shows collection stats (`db.collection.stats()`)

Actually, we can group command by following levels:
- Server:
  - isMaster()
  - serverStatus()
  - logout
- Database:
  - dropDatabase()
  - repairDatabase()
  - clone()
  - copydb()
  - dbStats()
- Collection:
  - create
  - drop
  - collStats
  - renameCollection
  - count
  - aggregate
  - mapReduce
  - findAndModify
  - geo*
- Index:
  - ensureIndex (createIndex)
  - dropIndex

Running command syntax: `db.runCommand({ <commandName>:<value>, <commandName2>:<value2>, ...})`

Example:
```
> db.runCommand({isMaster:1})
{
	"ismaster" : true,
	"maxBsonObjectSize" : 16777216,
	"maxMessageSizeBytes" : 48000000,
	"maxWriteBatchSize" : 1000,
	"localTime" : ISODate("2017-04-01T19:39:45.960Z"),
	"maxWireVersion" : 5,
	"minWireVersion" : 0,
	"readOnly" : false,
	"ok" : 1
}
> // command above can be shortcuted:
> db.runCommand('isMaster')
{
	"ismaster" : true,
	"maxBsonObjectSize" : 16777216,
	"maxMessageSizeBytes" : 48000000,
	"maxWriteBatchSize" : 1000,
	"localTime" : ISODate("2017-04-01T19:40:06.242Z"),
	"maxWireVersion" : 5,
	"minWireVersion" : 0,
	"readOnly" : false,
	"ok" : 1
}
> // or we can use built-in shell helper for that command:
> db.isMaster()
{
	"ismaster" : true,
	"maxBsonObjectSize" : 16777216,
	"maxMessageSizeBytes" : 48000000,
	"maxWriteBatchSize" : 1000,
	"localTime" : ISODate("2017-04-01T19:40:17.585Z"),
	"maxWireVersion" : 5,
	"minWireVersion" : 0,
	"readOnly" : false,
	"ok" : 1
}
```

*Btw, isMaster() determines if this member of the replica set is the Primary.*

**`db.collection.remove({})` is not the same as `db.collection.drop()`!** The first one will remove all documents in the collection, the last one will drop the collection entirely.


## Homework

### 2.1
```
> b = db.products_bak; db.products.find().forEach(function(o) {b.insert(o)})
> b.count()
11
> homework.a()
3.05
```

### 2.2 
```
> db.products.update({_id : ObjectId("507d95d5719dbef170f15c00")}, {$set: {'term_years': 3}})
WriteResult({ "nMatched" : 1, "nUpserted" : 0, "nModified" : 1 })
>
> db.products.find({_id : ObjectId("507d95d5719dbef170f15c00")}).pretty()
{
	"_id" : ObjectId("507d95d5719dbef170f15c00"),
	"name" : "Phone Service Family Plan",
	"type" : "service",
	"monthly_price" : 90,
	"limits" : {
		"voice" : {
			"units" : "minutes",
			"n" : 1200,
			"over_rate" : 0.05
		},
		"data" : {
			"n" : "unlimited",
			"over_rate" : 0
		},
		"sms" : {
			"n" : "unlimited",
			"over_rate" : 0
		}
	},
	"sales_tax" : true,
	"term_years" : 3
}
> db.products.update({_id : ObjectId("507d95d5719dbef170f15c00")}, {$set: {'limits.sms.over_rate': 0.01}})
WriteResult({ "nMatched" : 1, "nUpserted" : 0, "nModified" : 1 })
>
> db.products.find({_id : ObjectId("507d95d5719dbef170f15c00")}).pretty()
{
	"_id" : ObjectId("507d95d5719dbef170f15c00"),
	"name" : "Phone Service Family Plan",
	"type" : "service",
	"monthly_price" : 90,
	"limits" : {
		"voice" : {
			"units" : "minutes",
			"n" : 1200,
			"over_rate" : 0.05
		},
		"data" : {
			"n" : "unlimited",
			"over_rate" : 0
		},
		"sms" : {
			"n" : "unlimited",
			"over_rate" : 0.01
		}
	},
	"sales_tax" : true,
	"term_years" : 3
}
>
> homework.b()
0.050.019031
```

### 2.3
```
> db.products.find({'limits.voice': {$exists: true}}).count()
3
```
