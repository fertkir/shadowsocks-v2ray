FROM ubuntu:24.04 AS build
LABEL stage=builder-ssserver

ARG V2RAY_VERSION="v5.46.0"
ARG V2RAY_SHA256="26338b4f8274522238c98a42dc8087f5cc613ebd8644ae73de51c1fdbbbb59b4"

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends wget ca-certificates

RUN set -eux; \
    ARCHIVE="v2ray-plugin-linux-amd64-${V2RAY_VERSION}.tar.gz"; \
    URL="https://github.com/teddysun/v2ray-plugin/releases/download/${V2RAY_VERSION}/${ARCHIVE}"; \
    wget -qO "$ARCHIVE" "$URL"; \
    echo "${V2RAY_SHA256}  $ARCHIVE" | sha256sum -c -; \
    tar -xf "$ARCHIVE"; \
    rm "$ARCHIVE"; \
    mv v2ray* /usr/local/bin/v2ray-plugin; \
    chmod 0755 /usr/local/bin/v2ray-plugin


FROM ghcr.io/shadowsocks/ssserver-rust:v1.24.0@sha256:85d01da9879b30b0784aea2b5ffceb5234d59cd81082064c08ebb113324e1359 AS ssserver

USER root
COPY --from=build /usr/local/bin/v2ray-plugin /usr/local/bin/v2ray-plugin
USER nobody
ENV USER=nobody

ENTRYPOINT [ "docker-entrypoint.sh" ]
CMD [ "ssserver", "--log-without-time", "-c", "/etc/shadowsocks-rust/config.json" ]


FROM ghcr.io/shadowsocks/sslocal-rust:v1.24.0@sha256:573338c89c79fcbd20d6ffae8a099f84126a86780e01cc30f689430b835342e2 AS sslocal

USER root
COPY --from=build /usr/local/bin/v2ray-plugin /usr/local/bin/v2ray-plugin
USER nobody
ENV USER=nobody

ENTRYPOINT [ "docker-entrypoint.sh" ]
CMD [ "sslocal", "--log-without-time", "-c", "/etc/shadowsocks-rust/config.json" ]
