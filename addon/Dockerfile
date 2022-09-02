ARG BUILD_FROM=${BUILD_FROM}

FROM ${BUILD_FROM}

ENV LANG C.UTF-8

RUN apk add --no-cache \
  bc \
  curl \
  rsync \
  make \
  coreutils \
  dateutils \
  findutils \
  gettext \
  gawk \
  tar \
  jq \
  git

RUN apk add --no-cache \
  python3

RUN apk add --no-cache \
  mosquitto-clients

RUN apk add --no-cache \
  apache2 \
  apache2-utils

RUN apk add --no-cache \
  nmap

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
ARG MOTION_APACHE_PORT=7999
ARG MOTION_APACHE_ADMIN=root@hassio.local

ENV MOTION_APACHE_CONF "${MOTION_APACHE_CONF}"
ENV MOTION_APACHE_HTDOCS "${MOTION_APACHE_HTDOCS}"
ENV MOTION_APACHE_CGIBIN "${MOTION_APACHE_CGIBIN}"
ENV MOTION_APACHE_HOST "${MOTION_APACHE_HOST}"
ENV MOTION_APACHE_PORT "${MOTION_APACHE_PORT}"
ENV MOTION_APACHE_ADMIN "${MOTION_APACHE_ADMIN}"

# Ports for motion (control and stream)
EXPOSE ${MOTION_APACHE_PORT}

EXPOSE 7999

CMD [ "/usr/bin/run.sh" ]

# Build arguments
ARG BUILD_ARCH=${BUILD_ARCH}
ARG BUILD_DATE=${BUILD_DATE}
ARG BUILD_REF=${BUILD_REF}
ARG BUILD_VERSION=${BUILD_VERSION}

# for debugging
ENV BUILD_FROM="${BUILD_FROM}"
ENV BUILD_ARCH="${BUILD_ARCH}"
ENV BUILD_VERSION="${BUILD_VERSION}"

# Labels
LABEL \
    io.hass.name="ageathome" \
    io.hass.description="" \
    io.hass.type="addon" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.version=${BUILD_VERSION} \
    maintainer="David C Martin <github@dcmartin.com>"
