#!/bin/bash

mongo localhost/week6 --eval "load('week6_hw6.1.js'); sh.addShard('delorean.local:27018'); print(homework.a())"
