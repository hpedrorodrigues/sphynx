FROM mvdan/shfmt:v3.6.0-alpine as shfmt
FROM alpine:3.18.2

LABEL maintainer="Pedro Rodrigues <github.com/hpedrorodrigues>"

COPY --from=shfmt /bin/shfmt /bin/shfmt

ARG uid=1000
ARG gid=1000

ARG user=sphynx
ARG group=sphynx

ENV SPHYNX_HOME /home/${user}

RUN addgroup -g "${gid}" "${group}" \
  && adduser -h "${SPHYNX_HOME}" -u "${uid}" -G "${group}" -D "${user}" \
  && mkdir -p "${SPHYNX_HOME}" /mnt \
  && chown -R "${uid}:${gid}" "${SPHYNX_HOME}" /mnt

USER ${user}

WORKDIR /mnt

ENTRYPOINT ["shfmt"]
