FROM kong/kong:3.3-alpine
USER root

RUN apk add --no-cache git luarocks build-base openssl-dev pcre-dev zlib-dev && \
    luarocks install kong-oidc && \
    apk del git luarocks build-base && \
    rm -rf /var/cache/apk/* /tmp/*

ENV KONG_PLUGINS="bundled,oidc"
USER kong
