#!/bin/sh
exec redis-server --save 60 1 --loglevel warning --requirepass "$REDIS_PASSWORD"