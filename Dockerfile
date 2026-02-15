FROM ubuntu:24.04 AS build
LABEL stage=builder-ssserver

ARG V2RAY_TAG

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends wget jq ca-certificates

RUN --mount=type=secret,id=github_token  \
    set -eux; \
    TEMP_TOKEN=$(cat /run/secrets/github_token); \
    wget -qO release.json \
    --header "Authorization: Bearer $TEMP_TOKEN" \
    https://api.github.com/repos/teddysun/v2ray-plugin/releases/tags/${V2RAY_TAG}; \
    ARCHIVE=$(jq -r '.assets[] | select(.name | test("linux-amd64.*\\.tar\\.gz$")) | .name' release.json); \
    URL=$(jq -r '.assets[] | select(.name == "'"$ARCHIVE"'") | .browser_download_url' release.json); \
    DIGEST=$(jq -r '.assets[] | select(.name == "'"$ARCHIVE"'") | .digest' release.json); \
    EXPECTED_SHA256="${DIGEST#sha256:}"; \
    wget -qO "$ARCHIVE" "$URL"; \
    echo "$EXPECTED_SHA256  $ARCHIVE" | sha256sum -c -; \
    tar -xf "$ARCHIVE"; \
    rm -f "$ARCHIVE" release.json; \
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
