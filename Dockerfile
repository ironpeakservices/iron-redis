# image used for extracting the latest redis version
FROM redis:latest AS redistemp
# extract the latest redis version
RUN /usr/local/bin/redis-server --version | cut -d ' ' -f 3 | cut -d '=' -f 2 > /redis.version

# our (temp) builder image for building
# debian:buster not supported yet: https://github.com/GoogleContainerTools/distroless/issues/390
FROM debian:stretch AS builder

# add unprivileged user
RUN adduser --shell /bin/true --no-create-home --uid 1000 --disabled-password --disabled-login app \
	&& sed -i -r "/^(app|root)/!d" /etc/group /etc/passwd \
	&& sed -i -r 's#^(.*):[^:]*$#\1:/sbin/nologin#' /etc/passwd

# prepare the chowned/chmodded volume directory (fails if /data already exists so we don't copy over files)
RUN mkdir -p /redis/copy/data \
	&& chmod 700 /redis

# install the necessary build dependencies
RUN apt-get -q update \
	&& apt-get -q install -y wget make tcl gcc libjemalloc-dev

# copy in the redis version
COPY --from=redistemp /redis.version /

# get the redis source code and unpack it
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

# ---

# start from the distroless scratch image (with glibc), based on debian:stretch
FROM gcr.io/distroless/base

# add-in our unprivileged user
COPY --from=builder /etc/passwd /etc/group /etc/shadow /etc/

# copy our binaries into our scratch image
COPY --from=builder --chown=app /redis/copy/ /

# copy in our redis config file
COPY --chown=app redis.conf /

# run as an unprivileged user instead of root
USER app

# where we will store our data
VOLUME /data

# redis uses the current working directory
WORKDIR /data

# default redis port
EXPOSE 6379

# entrypoint
CMD ["/redis-server", "/redis.conf", "--port 6379"]
