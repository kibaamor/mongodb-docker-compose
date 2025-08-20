#!/bin/bash

mongosh --host mongos --eval 'sh.status();'
