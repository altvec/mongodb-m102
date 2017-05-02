#!/bin/bash

mkdir -p ./data
mkdir -p ./cfg

echo "Starting mongod for the first time..."
mongod --dbpath ./data --logpath ./data.log --fork
sleep 5
echo "Done."

echo "Initializing homework collection..."
mongo localhost/week6 --eval "load('week6_hw6.1.js'); homework.init(); db.trades.stats();"
echo "Done."

echo "Shutting down mongod..."
pkill mongod
sleep 2
echo "Done."

echo "Starting mongod, config server and mongos..."
mongod --shardsvr --dbpath ./data --logpath ./data.log --fork
echo "mongod started!"
mongod --configsvr --replSet csrs --dbpath ./cfg --logpath ./cfg.log --fork
mongo --port 27019 --eval "cfg = {_id: 'csrs', members: [ {_id:0, host:'delorean.local:27019'} ]}; rs.initiate(cfg);"
echo "mongod cfg server started!"
mongos --configdb csrs/delorean.local:27019 --logpath ./mongos.log --fork
echo "mongos started!"
sleep 2
echo "Done. Now you can connect to mongos and complete homework task!"

