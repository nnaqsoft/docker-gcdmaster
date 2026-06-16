# syntax=docker/dockerfile:1
#
# gcdmaster is no longer packaged by Debian/Ubuntu: its old GUI linked against
# libgnomeuimm, which was removed from the archives, so the binary package was
# dropped after Debian 10. Upstream cdrdao has since ported the GUI to gtkmm-3,
# which IS in Debian 12, so we build cdrdao + gcdmaster from source here and copy
# only the resulting binaries and data into the slim runtime image.

# ---- Stage 1: build cdrdao + gcdmaster from upstream source ----
FROM debian:bookworm AS builder

# Pin to a specific upstream commit for reproducible builds. Bump deliberately.
ARG CDRDAO_REF=d35b78d49ed5c2777f3ab7fc3badd5fd603ddeb8

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates git build-essential autoconf automake libtool pkg-config \
        flex bison \
        libsigc++-2.0-dev libgtkmm-3.0-dev \
        libao-dev libvorbis-dev libflac++-dev libsamplerate0-dev libmad0-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git clone https://github.com/cdrdao/cdrdao . \
    && git checkout "$CDRDAO_REF"

# autogen.sh regenerates configure; fall back to autoreconf if it is absent.
RUN (./autogen.sh || autoreconf -fi) \
    && ./configure --prefix=/usr/local --with-gcdmaster \
    && make -j"$(nproc)" \
    && make install DESTDIR=/stage

# ---- Stage 2: runtime image on the web-GUI base ----
FROM jlesage/baseimage-gui:debian-12-v4.11.3

# Runtime libraries the built binaries link against, plus optional extra burn
# backends for broader media support.
#   libgtkmm-3.0-1v5 + libsigc++ : the GUI toolkit gcdmaster links against
#   libao4/libvorbisfile3/libflac++10/libsamplerate0/libmad0 : audio decoding
#   libglib2.0-bin : provides glib-compile-schemas (gcdmaster ships a GSettings schema)
#   dvd+rw-tools / wodim : extra DVD and data-CD backends
RUN add-pkg \
        libgtkmm-3.0-1v5 libsigc++-2.0-0v5 \
        libao4 libvorbisfile3 libflac++10 libsamplerate0 libmad0 \
        libglib2.0-bin \
        dvd+rw-tools wodim

# Copy the source-built cdrdao + gcdmaster (binaries, data, drivers, schema).
COPY --from=builder /stage/usr/local/ /usr/local/

# Compile the GSettings schema gcdmaster installs, so the GUI can store settings.
RUN glib-compile-schemas /usr/local/share/glib-2.0/schemas

# App start script.
COPY startapp.sh /startapp.sh
RUN chmod +x /startapp.sh

# Files copied into the container image (device-access env hook, etc.).
COPY rootfs/ /
RUN chmod +x /etc/cont-env.d/SUP_GROUP_IDS_INTERNAL

# App identity shown in the web UI.
RUN set-cont-env APP_NAME "gcdmaster"

# Standard mount points this image expects.
#   /config  : persistent app config and state
#   /storage : user source audio files (read-write so output images can be written)
VOLUME ["/config", "/storage"]

# noVNC web UI.
EXPOSE 5800

# OCI image metadata.
LABEL org.opencontainers.image.title="gcdmaster-web" \
      org.opencontainers.image.description="gcdmaster (cdrdao GUI) accessible from a web browser. Unofficial, not affiliated with the cdrdao or gcdmaster projects." \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/nnaqsoft/docker-gcdmaster"
