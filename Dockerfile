FROM ubuntu:22.04 AS build
LABEL stage=builder-ssserver

ARG V2RAY_TAG

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends wget jq ca-certificates

RUN --mount=type=secret,id=github_token  \
    set -eux; \
    wget -qO release.json \
    --header "Authorization: Bearer $(cat /run/secrets/github_token)" \
    https://api.github.com/repos/teddysun/v2ray-plugin/releases/tags/${V2RAY_TAG}; \
    ARCHIVE=$(jq -r '.assets[] | select(.name | test("linux-amd64.*\\.tar\\.gz$")) | .name' release.json); \
    URL=$(jq -r '.assets[] | select(.name == "'"$ARCHIVE"'") | .browser_download_url' release.json); \
    DIGEST=$(jq -r '.assets[] | select(.name == "'"$ARCHIVE"'") | .digest' release.json); \
    EXPECTED_SHA256="${DIGEST#sha256:}"; \
    wget -qO "$ARCHIVE" "$URL"; \
    echo "$EXPECTED_SHA256  $ARCHIVE" | sha256sum -c -; \
    tar -xf "$ARCHIVE"; \
    mv v2ray* /usr/local/bin/v2ray-plugin; \
    chmod 0755 /usr/local/bin/v2ray-plugin; \
    rm -f "$ARCHIVE" release.json


FROM ghcr.io/shadowsocks/ssserver-rust:latest AS ssserver

USER root
COPY --from=build /usr/local/bin/v2ray-plugin /usr/local/bin/v2ray-plugin
USER nobody
ENV USER=nobody

ENTRYPOINT [ "docker-entrypoint.sh" ]
CMD [ "ssserver", "--log-without-time", "-c", "/etc/shadowsocks-rust/config.json" ]


FROM ghcr.io/shadowsocks/sslocal-rust:latest AS sslocal

USER root
COPY --from=build /usr/local/bin/v2ray-plugin /usr/local/bin/v2ray-plugin
USER nobody
ENV USER=nobody

ENTRYPOINT [ "docker-entrypoint.sh" ]
CMD [ "sslocal", "--log-without-time", "-c", "/etc/shadowsocks-rust/config.json" ]
