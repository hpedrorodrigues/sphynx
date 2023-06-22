FROM node:lts-alpine3.18

LABEL maintainer="Pedro Rodrigues <github.com/hpedrorodrigues>"

ARG uid=1000
ARG gid=1000

ARG user=alien
ARG group=alien

ENV ALIEN_HOME /home/${user}

RUN npm install --global prettier@2.8.8 \
  && echo http://dl-2.alpinelinux.org/alpine/edge/community/ >> /etc/apk/repositories \
  && apk --no-cache add shadow=4.13-r6 \
  && groupmod -g $((gid + 1)) node \
  && usermod -u $((uid + 1)) -g $((gid + 1)) node \
  && addgroup -g "${gid}" "${group}" \
  && adduser -h "${ALIEN_HOME}" -u "${uid}" -G "${group}" -s /bin/bash -D "${user}" \
  && mkdir -p "${ALIEN_HOME}" /mnt \
  && chown -R "${uid}:${gid}" "${ALIEN_HOME}" /mnt

USER ${user}

WORKDIR /mnt

ENTRYPOINT ["prettier"]
