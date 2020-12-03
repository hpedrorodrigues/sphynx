FROM ocaml/opam2:alpine-3.10-ocaml-4.10

LABEL maintainer="Pedro Rodrigues <github.com/hpedrorodrigues>"

ARG uid=1000
ARG gid=1000

ARG user=alien
ARG group=alien

ENV ALIEN_HOME /home/${user}

USER root

RUN apk add --no-cache m4=1.4.18-r1 && rm -rf /var/cache/apk/*

RUN echo http://dl-2.alpinelinux.org/alpine/edge/community/ >> /etc/apk/repositories \
  && apk --no-cache add shadow=4.8.1-r0 \
  && groupmod -g $((gid + 1)) opam \
  && usermod -u $((uid + 1)) -g $((gid + 1)) opam

USER opam

RUN opam pin add eq https://github.com/jonase/eq.git

USER root

RUN addgroup -g "${gid}" "${group}" \
  && adduser -h "${ALIEN_HOME}" -u "${uid}" -G "${group}" -s /bin/bash -D "${user}" \
  && mkdir -p "${ALIEN_HOME}" \
  && chown -R "${uid}:${gid}" "${ALIEN_HOME}"

USER ${user}

ENV PATH ${PATH}:/home/opam/.opam/4.10/bin

ENTRYPOINT ["eq"]
