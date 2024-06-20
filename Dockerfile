# syntax=docker/dockerfile:1.7.1@sha256:a57df69d0ea827fb7266491f2813635de6f17269be881f696fbfdf2d83dda33e

FROM yfhme/openssl-docker:v3.3.0@sha256:3fd176de74d9020c249752641990f2f4cf9e9d60615b192962862ab6aa56b701 as build

# renovate: datasource=github-tags depName=NLnetLabs/unbound
ENV UNBOUND_VERSION=1.20.0
ENV UNBOUND_SHA256=56b4ceed33639522000fd96775576ddf8782bb3617610715d7f1e777c5ec1dbf
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

FROM alpine:3.20.1@sha256:b89d9c93e9ed3597455c90a0b88a8bbb5cb7188438f70953fede212a0c4394e0 as unbound

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
