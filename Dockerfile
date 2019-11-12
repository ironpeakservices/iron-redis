# image used for extracting the latest redis version
FROM redis:5.0.6 AS redistemp

# make a pipe fail on the first failure
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# extract the latest redis version
RUN /usr/local/bin/redis-server --version | cut -d ' ' -f 3 | cut -d '=' -f 2 > /redis.version

#
# ---
#

# our (temp) builder image for building
# debian:buster not supported yet: https://github.com/GoogleContainerTools/distroless/issues/390
FROM debian:buster AS builder

# make a pipe fail on the first failure
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# prepare the chowned/chmodded volume directory (fails if /data already exists so we don't copy over files)
RUN mkdir -p /redis/copy/data \
	&& chmod 700 /redis

# install the necessary build dependencies
# hadolint ignore=DL3008
RUN apt-get update -y \
    && apt-get -q install -y --no-install-recommends \
        ca-certificates=20180409 \
        wget=1.19.4-1ubuntu2.2 \
        make=4.1-9.1ubuntu1 \
        tcl=8.6.0+9 \
        gcc=4:7.4.0-1ubuntu2.3 \
        libjemalloc-dev=3.6.0-11 \
        libc6-dev=2.27-3ubuntu1

# copy in the redis version
COPY --from=redistemp /redis.version /

# get the redis source code and unpack it
# hadolint ignore=SC2155
RUN export REDIS_VERSION="$(cat /redis.version)" ; echo "Using Redis version ${REDIS_VERSION}" \
	&& redisHashLine="$(wget -qO - https://raw.githubusercontent.com/antirez/redis-hashes/master/README | grep 'hash redis' | grep -v 'rc\d' | grep -v '^#' | grep -F "${REDIS_VERSION}")" \
	&& wget "http://download.redis.io/releases/redis-${REDIS_VERSION}.tar.gz" \
	&& echo "$(echo "$redisHashLine" | cut -d ' ' -f 4) redis-${REDIS_VERSION}.tar.gz" | sha256sum --check \
	&& tar -C redis -xf "redis-${REDIS_VERSION}.tar.gz" \
	&& mv "/redis/redis-${REDIS_VERSION}/" /redis/src

WORKDIR /redis/src

# compile redis statically so everything (except glibc) is included
RUN make CFLAGS="-static -static-libgcc" EXEEXT="-static -static-libgcc" LDFLAGS="-I/usr/local/include/"

# copy our binaries
RUN cp src/redis-server src/redis-sentinel /redis/copy/

#
# ---
#

# start from the distroless scratch image (with glibc), based on debian:buster
FROM gcr.io/distroless/base-debian10:nonroot

# copy our binaries into our scratch image
COPY --from=builder --chown=nonroot /redis/copy/ /

# copy in our redis config file
COPY --chown=nonroot redis.conf /

# run as an unprivileged user instead of root
USER nonroot

# where we will store our data
VOLUME /data

# redis uses the current working directory
WORKDIR /data

# default redis port
EXPOSE 6379

# entrypoint
CMD ["/redis-server", "/redis.conf", "--port 6379"]
