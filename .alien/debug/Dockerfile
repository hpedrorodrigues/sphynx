FROM alpine:3.14.0

LABEL maintainer="Pedro Rodrigues <github.com/hpedrorodrigues>"

RUN apk update \
    && apk add --no-cache \
      busybox-extras=1.33.1-r3 \
      curl=7.77.0-r1 \
      wget=1.21.1-r1 \
      bash=5.1.4-r0 \
      bind-tools=9.16.16-r2 \
      aws-cli=1.19.93-r0 \
    && rm -rf /var/cache/apk/*
