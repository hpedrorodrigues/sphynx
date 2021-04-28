FROM alpine:3.13.5

LABEL maintainer="Pedro Rodrigues <github.com/hpedrorodrigues>"

RUN apk update \
    && apk add --no-cache \
      busybox-extras=1.32.1-r6 \
      curl=7.76.1-r0 \
      wget=1.21.1-r1 \
      bash=5.1.0-r0 \
      bind-tools=9.16.11-r1 \
    && rm -rf /var/cache/apk/*
