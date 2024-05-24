FROM hadolint/hadolint:v2.12.0-alpine as hadolint
FROM alpine:3.20.0

LABEL maintainer="Pedro Rodrigues <github.com/hpedrorodrigues>"

COPY --from=hadolint /bin/hadolint /bin/hadolint

ARG uid=1000
ARG gid=1000

ARG user=sphynx
ARG group=sphynx

ENV SPHYNX_HOME /home/${user}

RUN addgroup -g "${gid}" "${group}" \
  && adduser -h "${SPHYNX_HOME}" -u "${uid}" -G "${group}" -s /bin/bash -D "${user}" \
  && mkdir -p "${SPHYNX_HOME}" /mnt \
  && chown -R "${uid}:${gid}" "${SPHYNX_HOME}" /mnt

USER ${user}

WORKDIR /mnt

ENTRYPOINT ["hadolint", "-"]
