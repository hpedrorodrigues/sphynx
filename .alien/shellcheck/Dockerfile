FROM koalaman/shellcheck-alpine:v0.8.0

LABEL maintainer="Pedro Rodrigues <github.com/hpedrorodrigues>"

ARG uid=1000
ARG gid=1000

ARG user=alien
ARG group=alien

ENV ALIEN_HOME /home/${user}

RUN addgroup -g "${gid}" "${group}" \
  && adduser -h "${ALIEN_HOME}" -u "${uid}" -G "${group}" -D "${user}" \
  && mkdir -p "${ALIEN_HOME}" /mnt \
  && chown -R "${uid}:${gid}" "${ALIEN_HOME}" /mnt

USER ${user}

WORKDIR /mnt

ENTRYPOINT ["shellcheck", "--color=always"]
