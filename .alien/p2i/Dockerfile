# References:
# - https://github.com/puppeteer/puppeteer/blob/master/docs/troubleshooting.md#running-puppeteer-in-docker
FROM node:lts-alpine3.15

LABEL maintainer="Pedro Rodrigues <github.com/hpedrorodrigues>"

ARG uid=1000
ARG gid=1000

ARG user=alien
ARG group=alien

ENV ALIEN_HOME /home/${user}

ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

RUN apk update \
    && apk add --no-cache \
         chromium=99.0.4844.84-r0 \
         nss=3.78.1-r0 \
         freetype=2.11.1-r2 \
         freetype-dev=2.11.1-r2 \
         harfbuzz=3.0.0-r2 \
         ca-certificates=20220614-r0 \
         ttf-freefont=20120503-r2 \
    && rm -rf /var/cache/apk/* \
    && echo http://dl-2.alpinelinux.org/alpine/edge/community/ >> /etc/apk/repositories \
    && apk --no-cache add shadow=4.13-r0 \
    && groupmod -g $((gid + 1)) node \
    && usermod -u $((uid + 1)) -g $((gid + 1)) node \
    && addgroup -g "${gid}" "${group}" \
    && adduser -h "${ALIEN_HOME}" -u "${uid}" -G "${group}" -s /bin/bash -D "${user}" \
    && mkdir -p "${ALIEN_HOME}" /mnt /app \
    && chown -R "${uid}:${gid}" "${ALIEN_HOME}" /mnt /app

USER ${user}

WORKDIR /app

COPY . .

RUN npm ci

WORKDIR /mnt

ENTRYPOINT ["node", "/app/index.js"]
