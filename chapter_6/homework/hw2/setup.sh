#!/bin/bash

mkdir -p ../data2
mongod --shardsvr --dbpath ../data2 --logpath ../data2.log --fork
