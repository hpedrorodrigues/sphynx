# References:
# - https://github.com/Homebrew/brew/blob/master/Dockerfile
# - https://hub.docker.com/r/linuxbrew/brew
FROM linuxbrew/brew:3.2.5

LABEL maintainer="Pedro Rodrigues <github.com/hpedrorodrigues>"

ARG uid=1001
ARG gid=1001

ARG user=alien
ARG group=alien

ENV ALIEN_HOME /home/${user}

RUN groupadd -g "${gid}" "${group}" \
  && useradd -l -m -d "${ALIEN_HOME}" -u "${uid}" -g "${group}" -s /bin/bash "${user}" \
  && mkdir -p "${ALIEN_HOME}" /mnt \
  && chown -R "${uid}:${gid}" "${ALIEN_HOME}" /mnt \
  && usermod -a -G 'linuxbrew' "${user}" \
  && apt-get update \
  && apt-get install --no-install-recommends -y python3=3.8.2-0ubuntu2 \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

USER ${user}

RUN brew update \
  && brew upgrade \
  && brew install hpedrorodrigues/tools/sphynx

WORKDIR /mnt
