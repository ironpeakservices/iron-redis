# ironpeakservices/iron-redis
Secure base image for running Redis.

Check it out on [Docker Hub](https://hub.docker.com/r/ironpeakservices/iron-redis)!

## How is this different?
We build from the official redis source code, but additionally:
- an empty scratch container (no shell, unprivileged user, ...) for a tiny attack vector
- hardened redis config
- hardened Docker Compose file
- max volume size set to 10GB, max memory set to 4GB

## Example
```
FROM ironpeakservices/iron-redis
# add 'requirepass MySecret' into redis.conf
COPY redis.conf / 
```