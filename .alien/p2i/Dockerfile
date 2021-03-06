# Reference:
# - https://github.com/puppeteer/puppeteer/blob/master/docs/troubleshooting.md#running-puppeteer-in-docker
FROM node:lts-alpine3.12

LABEL maintainer="Pedro Rodrigues <github.com/hpedrorodrigues>"

ARG uid=1000
ARG gid=1000

ARG user=alien
ARG group=alien

ENV ALIEN_HOME /home/${user}

RUN apk update \
    && apk add --no-cache \
         chromium=86.0.4240.111-r0 \
         nss=3.57-r0 \
         freetype=2.10.4-r0 \
         freetype-dev=2.10.4-r0 \
         harfbuzz=2.6.6-r0 \
         ca-certificates=20191127-r4 \
         ttf-freefont=20120503-r1 \
    && rm -rf /var/cache/apk/*

ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

RUN echo http://dl-2.alpinelinux.org/alpine/edge/community/ >> /etc/apk/repositories \
  && apk --no-cache add shadow=4.8.1-r0 \
  && groupmod -g $((gid + 1)) node \
  && usermod -u $((uid + 1)) -g $((gid + 1)) node

RUN addgroup -g "${gid}" "${group}" \
  && adduser -h "${ALIEN_HOME}" -u "${uid}" -G "${group}" -s /bin/bash -D "${user}" \
  && mkdir -p "${ALIEN_HOME}" /mnt /app \
  && chown -R "${uid}:${gid}" "${ALIEN_HOME}" /mnt /app

USER ${user}

WORKDIR /app

COPY . .

RUN npm ci

WORKDIR /mnt

ENTRYPOINT ["node", "/app/index.js"]
