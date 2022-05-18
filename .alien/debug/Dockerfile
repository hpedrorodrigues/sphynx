FROM alpine:3.15.4

LABEL maintainer="Pedro Rodrigues <github.com/hpedrorodrigues>"

RUN apk update \
    && apk add --no-cache \
      aws-cli=1.19.105-r0 \
      bash=5.1.16-r0 \
      bind-tools=9.16.27-r0 \
      bridge-utils=1.7.1-r0 \
      busybox-extras=1.34.1-r5 \
      conntrack-tools=1.4.6-r1 \
      curl=7.80.0-r1 \
      ethtool=5.15-r0 \
      iperf=2.1.4-r0 \
      iproute2=5.15.0-r0 \
      ipset=7.15-r0 \
      iptables=1.8.7-r1 \
      iputils=20210722-r0 \
      jq=1.6-r1 \
      mtr=0.94-r1 \
      net-snmp-tools=5.9.1-r5 \
      netcat-openbsd=1.130-r3 \
      nftables=1.0.1-r0 \
      nmap=7.92-r2 \
      openssl=1.1.1o-r0 \
      socat=1.7.4.2-r0 \
      strace=5.14-r0 \
      tcpdump=4.99.1-r3 \
      tcptraceroute=1.5b7-r3 \
      util-linux=2.37.4-r0 \
      vim=8.2.4836-r0 \
      wget=1.21.2-r2 \
    && rm -rf /var/cache/apk/*
