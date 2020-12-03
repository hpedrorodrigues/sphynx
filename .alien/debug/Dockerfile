FROM alpine:3.12.1

LABEL maintainer="Pedro Rodrigues <github.com/hpedrorodrigues>"

RUN apk update \
    && apk add --no-cache \
      busybox-extras=1.31.1-r19 \
      curl=7.69.1-r1 \
      wget=1.20.3-r1 \
      bash=5.0.17-r0 \
      bind-tools=9.16.6-r0 \
    && rm -rf /var/cache/apk/*
