FROM alpine:3.15.0

LABEL maintainer="Pedro Rodrigues <github.com/hpedrorodrigues>"

RUN apk update \
    && apk add --no-cache \
      busybox-extras=1.34.1-r4 \
      curl=7.80.0-r0 \
      wget=1.21.2-r2 \
      bash=5.1.16-r0 \
      bind-tools=9.16.25-r0 \
      aws-cli=1.19.105-r0 \
    && rm -rf /var/cache/apk/*
