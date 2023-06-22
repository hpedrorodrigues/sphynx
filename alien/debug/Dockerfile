FROM alpine:3.17.3

LABEL maintainer="Pedro Rodrigues <github.com/hpedrorodrigues>"

RUN apk update && \
    apk add --no-cache \
      aws-cli=1.25.97-r0 \
      bash=5.2.15-r0 \
      bind-tools=9.18.16-r0 \
      bridge-utils=1.7.1-r1 \
      busybox-extras=1.35.0-r29 \
      conntrack-tools=1.4.7-r0 \
      curl=8.1.2-r0 \
      ethtool=6.0-r0 \
      iperf=2.1.8-r0 \
      iproute2=6.0.0-r1 \
      ipset=7.15-r1 \
      iptables=1.8.8-r2 \
      iputils=20211215-r0 \
      jq=1.6-r2 \
      mtr=0.95-r1 \
      net-snmp-tools=5.9.3-r2 \
      nftables=1.0.5-r2 \
      nmap=7.93-r0 \
      openssl=3.0.9-r1 \
      socat=1.7.4.4-r0 \
      strace=6.0-r0 \
      tcpdump=4.99.4-r0 \
      tcptraceroute=1.5b7-r4 \
      util-linux=2.38.1-r1 \
      vim=9.0.0999-r0 \
      wget=1.21.4-r0 \
    && rm -rf /var/cache/apk/*
