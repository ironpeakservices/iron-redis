# ironpeakservices/iron-redis
Secure base image for running Redis.

`docker pull docker.pkg.github.com/ironpeakservices/iron-redis/iron-redis:5.0.6`

## How is this different?
We build from the official redis source code, but additionally:
- an empty scratch container (no shell, unprivileged user, ...) for a tiny attack vector
- secure healthcheck binary for embedded container monitoring
- hardened redis config
- hardened Docker Compose file
- max volume size set to 10GB, max memory set to 4GB

## Example
```
FROM ironpeakservices/iron-redis
# add 'requirepass MySecret' into redis.conf
COPY redis.conf / 
```

## Update policy
Updates to the official redis docker image are automatically created as a pull request and trigger linting & a docker build.
When those checks complete without errors, a merge into master will trigger a deploy with the same version to packages.
A GitHub release will also be created to notify the GitHub subscribers.
