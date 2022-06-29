ARG BUILD_FROM=${BUILD_FROM}

FROM ${BUILD_FROM}

ENV LANG C.UTF-8

RUN \
    apk add --no-cache \
        musl musl-dev
RUN \
    apk add --no-cache \
        autoconf
RUN \
    apk add --no-cache \
        automake
RUN \
    apk add --no-cache \
        build-base
RUN \
    apk add --no-cache \
        curl
RUN \
    apk add --no-cache \
        ffmpeg-dev
RUN \
    apk add --no-cache \
        gcc
RUN \
    apk add --no-cache \
        gettext-dev
RUN \
    apk add --no-cache \
        git
RUN \
    apk add --no-cache \
        jpeg-dev
RUN \
    apk add --no-cache \
        libjpeg-turbo-dev
RUN \
    apk add --no-cache \
        libmicrohttpd-dev
RUN \
    apk add --no-cache \
        libwebp-dev
RUN \
    apk add --no-cache \
        linux-headers
RUN \
    apk add --no-cache \
        python2-dev
RUN \
    apk add --no-cache \
        v4l-utils-dev

RUN \
    apk add --no-cache \
        cifs-utils
RUN \
    apk add --no-cache \
        ffmpeg
RUN \
    apk add --no-cache \
        ffmpeg-libs
RUN \
    apk add --no-cache \
        libcurl
RUN \
    apk add --no-cache \
        libjpeg
RUN \
    apk add --no-cache \
        libjpeg-turbo
RUN \
    apk add --no-cache \
        libintl
RUN \
    apk add --no-cache \
        libmicrohttpd
RUN \
    apk add --no-cache \
        libwebp
RUN \
    apk add --no-cache \
        mosquitto-clients
RUN \
    apk add --no-cache \
        python2
RUN \
    apk add --no-cache \
        v4l-utils
RUN \
    apk add --no-cache \
        iperf3
RUN \
    apk add --no-cache \
        netdata

RUN \
  sed -i 's/127.0.0.1/\*/' /etc/netdata/netdata.conf \
  && \
  echo 'SEND_EMAIL="NO"' > /etc/netdata/health_alarm_notify.conf

RUN MOTION_VERSION=4.3.1 \
    && curl -J -L -o /tmp/motion.tar.gz \
        https://github.com/Motion-Project/motion/archive/release-${MOTION_VERSION}.tar.gz \
    && mkdir -p /tmp/motion \
    && tar zxf /tmp/motion.tar.gz -C \
        /tmp/motion --strip-components=1 \
    && cd /tmp/motion \
    && autoreconf -fiv \
    && ./configure \
            --without-pgsql \
            --without-mysql \
            --without-sqlite3 \
            --prefix=/usr \
            --sysconfdir=/etc \
    && make install \
    && make distclean

RUN apk add --no-cache \
  bc \
  coreutils \
  dateutils \
  findutils \
  gettext \
  gawk \
  jq \
  git

RUN apk add --no-cache \
  python3

RUN apk add --no-cache \
  inotify-tools \
  mosquitto-clients

RUN apk add --no-cache \
  apache2 \
  apache2-utils

RUN apk add --no-cache \
  imagemagick

RUN apk add --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing/ \
  tcsh

RUN apk add --no-cache \
  nmap

### LIVE555

#RUN \
#    apk add --no-cache \
#	git \
#	g++ \
#	make \
#       openssl-dev \
#	live-media-dev \
#	live-media-utils

#RUN \
#    && \
#    cd /tmp \
#    && \
#    git clone https://github.com/dcmartin/live555.git \
#    && \
#    cd live555 \
#    && \
#    sed -i -e 's/proxyStream\-\%d/stream%02d/g' ./proxyServer/live555ProxyServer.cpp \
#    && \
#    sed -i -e "s/proxyStream/stream/g" ./proxyServer/live555ProxyServer.cpp \
#    && \
#    ./genMakefiles linux \
#    && \
#    make -j4 \
#    && \
#    cp proxyServer/live555ProxyServer /usr/local/bin/ \
#    && \
#    rm -rf /tmp/*

RUN apk add --no-cache \
  openssh-client

# environment
ENV CONFIG_PATH /data/options.json
ENV MOTION_CONF /etc/motion/motion.conf

# Copy rootts
COPY rootfs /

## APACHE

ARG MOTION_APACHE_CONF=/etc/apache2/httpd.conf
ARG MOTION_APACHE_HTDOCS=/var/www/localhost/htdocs
ARG MOTION_APACHE_CGIBIN=/var/www/localhost/cgi-bin
ARG MOTION_APACHE_HOST=localhost
ARG MOTION_APACHE_PORT=9999
ARG MOTION_APACHE_ADMIN=root@hassio.local

ENV MOTION_APACHE_CONF "${MOTION_APACHE_CONF}"
ENV MOTION_APACHE_HTDOCS "${MOTION_APACHE_HTDOCS}"
ENV MOTION_APACHE_CGIBIN "${MOTION_APACHE_CGIBIN}"
ENV MOTION_APACHE_HOST "${MOTION_APACHE_HOST}"
ENV MOTION_APACHE_PORT "${MOTION_APACHE_PORT}"
ENV MOTION_APACHE_ADMIN "${MOTION_APACHE_ADMIN}"

# Ports for motion (control and stream)
EXPOSE ${MOTION_APACHE_PORT}

EXPOSE 9999

CMD [ "/usr/bin/run.sh" ]

# Build arugments
ARG BUILD_ARCH
ARG BUILD_DATE
ARG BUILD_REF
ARG BUILD_VERSION

# Labels
LABEL \
    io.hass.name="ageathome" \
    io.hass.description="" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    io.hass.version=${BUILD_VERSION} \
    maintainer="David C Martin <github@dcmartin.com>"
