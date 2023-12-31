# syntax=docker/dockerfile:1@sha256:ac85f380a63b13dfcefa89046420e1781752bab202122f8f50032edf31be0021

FROM yfhme/openssl-docker:v3.2.0@sha256:1807f6c9a4dc800c5f1ddd0e53ac143bfc00a795cc0ad21d9e8b72873e6b965d as build

# renovate: datasource=github-tags depName=NLnetLabs/unbound
ENV UNBOUND_VERSION=1.19.0
ENV UNBOUND_SHA256=a97532468854c61c2de48ca4170de854fd3bc95c8043bb0cfb0fe26605966624
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

FROM alpine:3.19.0@sha256:51b67269f354137895d43f3b3d810bfacd3945438e94dc5ac55fdac340352f48 as unbound

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
