#!/bin/bash

echo "Creating dirs..."

echo "Creating dirs for config servers..."
mkdir -p ./{cfg0,cfg1,cfg2}

echo "Creating data dirs for replica set 0, shard 0..."
mkdir -p ./{a0,a1,a2}

echo "Creating data dirs for replica set 1, shard 1..."
mkdir -p ./{b0,b1,b2}

echo "Creating data dirs for replica set 2, shard 2..."
mkdir -p ./{c0,c1,c2}

echo  "Creating data dirs for replica set 3, shard 3..."
mkdir -p ./{d0,d1,d2}

echo "Done."
echo

echo "Starting servers..."

echo "Starting config servers..."
mongod --configsvr --replSet confsrvs --dbpath cfg0 --port 26050 --fork --logpath log.cfg0 --logappend
mongod --configsvr --replSet confsrvs --dbpath cfg1 --port 26051 --fork --logpath log.cfg1 --logappend
mongod --configsvr --replSet confsrvs --dbpath cfg2 --port 26052 --fork --logpath log.cfg2 --logappend
echo "Done."
echo

echo "Setting up config servers replica set"
sleep 300
mongo --host delorean.local --port 26050 < setup_config_servers.js
echo "Done."
echo

echo "Starting shards (mongod data servers)..."
mongod --shardsvr --replSet a --dbpath a0 --logpath log.a0 --port 27000 --fork --logappend --smallfiles --oplogSize 50
mongod --shardsvr --replSet a --dbpath a1 --logpath log.a1 --port 27001 --fork --logappend --smallfiles --oplogSize 50
mongod --shardsvr --replSet a --dbpath a2 --logpath log.a2 --port 27002 --fork --logappend --smallfiles --oplogSize 50
mongod --shardsvr --replSet b --dbpath b0 --logpath log.b0 --port 27100 --fork --logappend --smallfiles --oplogSize 50
mongod --shardsvr --replSet b --dbpath b1 --logpath log.b1 --port 27101 --fork --logappend --smallfiles --oplogSize 50
mongod --shardsvr --replSet b --dbpath b2 --logpath log.b2 --port 27102 --fork --logappend --smallfiles --oplogSize 50
mongod --shardsvr --replSet c --dbpath c0 --logpath log.c0 --port 27200 --fork --logappend --smallfiles --oplogSize 50
mongod --shardsvr --replSet c --dbpath c1 --logpath log.c1 --port 27201 --fork --logappend --smallfiles --oplogSize 50
mongod --shardsvr --replSet c --dbpath c2 --logpath log.c2 --port 27202 --fork --logappend --smallfiles --oplogSize 50
mongod --shardsvr --replSet d --dbpath d0 --logpath log.d0 --port 27300 --fork --logappend --smallfiles --oplogSize 50
mongod --shardsvr --replSet d --dbpath d1 --logpath log.d1 --port 27301 --fork --logappend --smallfiles --oplogSize 50
mongod --shardsvr --replSet d --dbpath d2 --logpath log.d2 --port 27302 --fork --logappend --smallfiles --oplogSize 50
echo "Done."
echo

echo "Starting mongos processes..."
mongos --configdb confsrvs/delorean.local:26050,delorean.local:26051,delorean.local:26052 --fork --logappend --logpath log.mongos0
mongos --configdb confsrvs/delorean.local:26050,delorean.local:26051,delorean.local:26052 --fork --logappend --logpath log.mongos0 --port 26061
mongos --configdb confsrvs/delorean.local:26050,delorean.local:26051,delorean.local:26052 --fork --logappend --logpath log.mongos0 --port 26062
mongos --configdb confsrvs/delorean.local:26050,delorean.local:26051,delorean.local:26052 --fork --logappend --logpath log.mongos0 --port 26063
echo "Done."
echo

echo "Checking if all is up..."
ps -A | grep mongo

sleep 2

echo "Tailing logs..."
tail -n 1 log.cfg*
tail -n 1 log.a*
tail -n 1 log.b*
tail -n 1 log.c*
tail -n 1 log.d*
tail -n 1 log.mongos*
