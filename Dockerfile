FROM arm32v6/alpine:latest AS builder
MAINTAINER PKizzle

ARG SHAIRPORT_VER=development

RUN apk --no-cache -U add \
        git \
        build-base \
        autoconf \
        automake \
        libtool \
        alsa-lib-dev \
        libdaemon-dev \
        popt-dev \
        libressl-dev \
        soxr-dev \
        avahi-dev \
        libconfig-dev

RUN mkdir /root/alac \
      && git clone https://github.com/mikebrady/alac.git \
      /root/alac

WORKDIR /root/alac

RUN autoreconf -fi \
      && ./configure \
      && make \
      && make install

RUN mkdir /root/shairport-sync \
        && git clone --recursive --depth 1 --branch ${SHAIRPORT_VER} \
        git://github.com/mikebrady/shairport-sync \
        /root/shairport-sync

WORKDIR /root/shairport-sync

RUN autoreconf -i -f \
        && ./configure \
              --with-alsa \
              --with-avahi \
              --with-ssl=openssl \
              --with-soxr \
              --with-apple-alac \
              --sysconfdir=/etc \
        && make \
        && make install


FROM arm32v6/alpine:latest

RUN apk add --no-cache \
        dbus \
        alsa-lib \
        libdaemon \
        popt \
        libressl \
        soxr \
        avahi \
        libconfig \
        libstdc++ \
      && rm -rf \
        /etc/ssl \
        /lib/apk/db/* \
        /root/shairport-sync

COPY --from=builder /etc/shairport-sync* /etc/
COPY --from=builder /usr/local/bin/shairport-sync /usr/local/bin/shairport-sync
COPY --from=builder /usr/local/lib/libalac.so.0.0.0 /usr/local/lib/libalac.so.0.0.0
COPY --from=builder /usr/local/lib/libalac.la /usr/local/lib/libalac.la
COPY --from=builder /usr/local/lib/pkgconfig/alac.pc /usr/local/lib/pkgconfig/alac.pc

RUN ln -s -f /usr/local/lib/libalac.so.0.0.0 /usr/local/lib/libalac.so.0
RUN ln -s -f /usr/local/lib/libalac.so.0.0.0 /usr/local/lib/libalac.so

COPY /usr/share/alsa/alsa.conf /usr/share/alsa/alsa.conf
COPY start.sh /start

ENV AIRPLAY_NAME Docker

ENTRYPOINT [ "/start" ]
