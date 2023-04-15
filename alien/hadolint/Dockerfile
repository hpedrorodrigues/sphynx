FROM hadolint/hadolint:v2.12.0-alpine as hadolint
FROM alpine:3.17.3

LABEL maintainer="Pedro Rodrigues <github.com/hpedrorodrigues>"

COPY --from=hadolint /bin/hadolint /bin/hadolint

ARG uid=1000
ARG gid=1000

ARG user=alien
ARG group=alien

ENV ALIEN_HOME /home/${user}

RUN addgroup -g "${gid}" "${group}" \
  && adduser -h "${ALIEN_HOME}" -u "${uid}" -G "${group}" -s /bin/bash -D "${user}" \
  && mkdir -p "${ALIEN_HOME}" /mnt \
  && chown -R "${uid}:${gid}" "${ALIEN_HOME}" /mnt

USER ${user}

WORKDIR /mnt

ENTRYPOINT ["hadolint", "-"]
