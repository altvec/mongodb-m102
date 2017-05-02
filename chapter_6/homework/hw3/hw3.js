sh.addShard('delorean.local:28018');
homework.check1();

use config;
sleep 150;
db.chunks.aggregate([
  { $match : { ns : "week6.trades" } },
  { $group : { _id : "$shard", n : { $sum : 1 } } }
])

homework.c()
