FROM ubuntu:22.04 as build
LABEL stage=builder-ssserver

RUN apt-get update -y && apt-get upgrade -y && apt-get install -y wget gzip jq

RUN wget https://api.github.com/repos/teddysun/v2ray-plugin/releases/latest -O release_notes.txt

RUN TAG=$(cat release_notes.txt | grep tag_name | cut -d '"' -f4) && \
    ARCHIVE=$(cat release_notes.txt | jq -r .body | grep "linux-amd64" | awk '{print $2}' | tr -d '[:blank:]\r') && \
    EXPECTED_SHA1=$(cat release_notes.txt | jq -r .body | grep "linux-amd64" | awk '{print $1}' | tr -d '[:blank:]\r') && \
    wget "https://github.com/teddysun/v2ray-plugin/releases/download/$TAG/$ARCHIVE" && \
    test "$EXPECTED_SHA1" = "$(sha1sum "$ARCHIVE" | awk '{print $1}')" && \
    tar -xf *.gz && \
    rm *.gz && \
    mv v2ray* /usr/local/bin/v2ray-plugin && \
    chmod +x /usr/local/bin/v2ray-plugin


FROM ghcr.io/shadowsocks/ssserver-rust:latest

USER root
RUN apk update --no-cache
COPY --from=build /usr/local/bin/v2ray-plugin /usr/local/bin/v2ray-plugin
USER nobody

ENTRYPOINT [ "docker-entrypoint.sh" ]
CMD [ "ssserver", "--log-without-time", "-c", "/etc/shadowsocks-rust/config.json" ]
