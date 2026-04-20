#!/bin/sh
exec redis-server --save 60 1 --loglevel warning --requirepass "$(cat /REDIS_PASSWORD)"