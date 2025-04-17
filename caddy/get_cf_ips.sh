#!/bin/sh
# Prints out the latest Cloudflare IP list.

for i in `curl -s https://www.cloudflare.com/ips-v4`; do echo -n "$i "; done
for i in `curl -s https://www.cloudflare.com/ips-v6`; do echo -n "$i "; done
echo