# syntax=docker/dockerfile:1.12.0@sha256:db1ff77fb637a5955317c7a3a62540196396d565f3dd5742e76dddbb6d75c4c5

FROM yfhme/openssl-docker:v3.3.2@sha256:4c835d5f1d33f91b42f73890e6319f0d1be1e9dbc63ae7ee0be71673b3d0736e AS build

# renovate: datasource=github-tags depName=NLnetLabs/unbound
ENV UNBOUND_VERSION=1.22.0
ENV UNBOUND_SHA256=c5dd1bdef5d5685b2cedb749158dd152c52d44f65529a34ac15cd88d4b1b3d43
ENV UNBOUND_DOWNLOAD_URL=https://nlnetlabs.nl/downloads/unbound/unbound-$UNBOUND_VERSION.tar.gz

ADD --checksum=sha256:$UNBOUND_SHA256 $UNBOUND_DOWNLOAD_URL /tmp/src/

WORKDIR /tmp/src

RUN build_deps="build-base expat-dev libssl3" && \
    apk update && apk upgrade && \
    apk add --no-cache $build_deps libevent-dev libexpat && \
    tar xzf unbound-$UNBOUND_VERSION.tar.gz && \
    rm -f unbound-$UNBOUND_VERSION.tar.gz && \
    cd unbound-$UNBOUND_VERSION && \
    ./configure \
        --prefix=/opt/unbound \
        --with-pthreads \
        --with-ssl=/opt/openssl \
        --with-libevent \
        --enable-tfo-server \
        --enable-tfo-client && \
    nproc | xargs -I % make -j% && \
    nproc | xargs -I % make -j% install && \
    apk del -r $build_deps libevent-dev libexpat && \
    rm -rf /opt/unbound/share/man

FROM alpine:3.20.3@sha256:beefdbd8a1da6d2915566fde36db9db0b524eb737fc57cd1367effd16dc0d06d AS unbound

COPY --from=build /opt /opt

RUN apk update && apk upgrade && \
    apk add libevent-dev libexpat tzdata && \
    addgroup unbound && \
    adduser -G unbound -s /dev/null -h /etc -D unbound && \
    mkdir -p -m 700 /opt/unbound/etc/unbound/var && \
    chown unbound:unbound /opt/unbound/etc/unbound/var && \
    touch /opt/unbound/etc/unbound/unbound.log && \
    chown unbound:unbound /opt/unbound/etc/unbound/unbound.log && \
    /opt/unbound/sbin/unbound-anchor -F -v -a /opt/unbound/etc/unbound/var/root.key || true

COPY --chown=unbound:unbound configs/ /opt/unbound/etc/unbound/

WORKDIR /opt/unbound/

LABEL org.opencontainers.image.title="yfhme/unbound-docker"
LABEL org.opencontainers.image.description="a validating, recursive, and caching DNS resolver"
LABEL org.opencontainers.image.url="https://github.com/yfhme/unbound-docker"
LABEL org.opencontainers.image.vendor="yfhme"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.source="https://github.com/yfhme/unbound-docker"
LABEL org.opencontainers.image.version=${UNBOUND_VERSION}

EXPOSE 53/tcp
EXPOSE 53/udp

ENTRYPOINT ["/opt/unbound/sbin/unbound", "-d", "-c", "/opt/unbound/etc/unbound/unbound.conf"]
