#Q1

A: 6

#Q2

Lookup for rollback file in data dir!

A: MongoDB preserves the order of writes in a collection in its consistency
model. In this problem, 27003's oplog was effectively a "fork" and to
preserve write ordering a rollback was necessary during 27003's recovery phase

#Q3

A: It contains 3 documents

#Q4

A: 233

#Q5

A: 

- We can create an index to make the following query fast/faster:
`db.postings.find({"comments.flagged":true})`

- One way to assure people vote at most once per posting is to use this form
    of update:
`db.postings.update({_id:..., voters:{$ne:'joe'}}, {$inc: {votes:1}, $push:
{voters:'joe'}})`

#Q6

A:
- MongoDB supports atomic operations on individual documents
- MongoDB has a data type for binary data

#Q7

A: MongoDB supports reads from slaves/secondaries that are in remote locations

#Q8

A: 39:15

#Q9

A: 47664

#Q10

A:

- 2 shars in total are queried
- 8 documents in total are examined
