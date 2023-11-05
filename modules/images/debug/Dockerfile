FROM alpine:3.18.2

LABEL maintainer="Pedro Rodrigues <github.com/hpedrorodrigues>"

ARG uid=1000
ARG gid=1000

ARG user=sphynx
ARG group=sphynx

ENV SPHYNX_HOME /home/${user}

RUN apk update && \
    apk add --no-cache \
      aws-cli=2.13.5-r0 \
      bash=5.2.15-r5 \
      bind-tools=9.18.19-r0 \
      bridge-utils=1.7.1-r2 \
      busybox-extras=1.36.1-r4 \
      conntrack-tools=1.4.7-r1 \
      curl=8.4.0-r0 \
      ethtool=6.2-r1 \
      iperf=2.1.9-r0 \
      iproute2=6.3.0-r0 \
      ipset=7.17-r1 \
      iptables=1.8.9-r2 \
      iputils=20221126-r2 \
      jq=1.6-r3 \
      mtr=0.95-r2 \
      net-snmp-tools=5.9.3-r3 \
      nftables=1.0.7-r2 \
      nmap=7.93-r1 \
      openssl=3.1.4-r0 \
      socat=1.7.4.4-r1 \
      strace=6.3-r1 \
      tcpdump=4.99.4-r1 \
      tcptraceroute=1.5b7-r4 \
      util-linux=2.38.1-r8 \
      vim=9.0.1568-r0 \
      wget=1.21.4-r0 \
      sudo=1.9.13_p3-r2 \
    && rm -rf /var/cache/apk/*

# https://wiki.alpinelinux.org/wiki/Setting_up_a_new_user
RUN addgroup -g "${gid}" "${group}" \
  && adduser -h "${SPHYNX_HOME}" -u "${uid}" -G "${group}" -s /bin/bash -D "${user}" \
  && echo "${user} ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/${user}" \
  && chmod 0440 "/etc/sudoers.d/${user}" \
  && mkdir -p "${SPHYNX_HOME}" /mnt \
  && chown -R "${uid}:${gid}" "${SPHYNX_HOME}" /mnt

USER ${user}

WORKDIR ${SPHYNX_HOME}
