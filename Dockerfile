FROM jlesage/baseimage-gui:debian-12-v4.11.3

# K3b is KDE's full CD/DVD/Blu-ray burning suite. It shells out to CLI backends:
#   k3b            : the burning suite (GUI)
#   cdrdao         : disc-at-once engine for audio mastering (CD-Text, gapless gaps)
#   wodim          : cdrecord data-CD backend
#   dvd+rw-tools   : growisofs DVD / Blu-ray backend
#   genisoimage    : mkisofs ISO image creation
#   cdparanoia     : audio CD ripping engine
#   icedax / libcdio-utils : alternate ripping and disc-inspection paths
# Audio encoders K3b auto-detects on PATH for its rip "Filetype" list:
#   flac, lame (MP3), vorbis-tools (oggenc), opus-tools (opusenc), wavpack
#   (faac/AAC lives in Debian non-free, so it is intentionally left out)
# Theming / session helpers:
#   adwaita-qt     : Qt theme so DARK_MODE=1 styles the K3b UI
#   dbus-x11       : provides dbus-run-session for the per-session bus K3b expects
# Drive detection stack (see rootfs/etc/cont-init.d/50-optical-stack.sh):
#   dbus           : system bus daemon
#   udev           : systemd-udevd + cdrom_id rule that stamps ID_CDROM on the drive
#   udisks2        : the daemon Solid/K3b enumerate optical drives through
# Localisation (baked in at build, not via the ENABLE_CJK_FONT runtime installer):
#   fonts-noto-*   : full Unicode glyph coverage (Latin, Cyrillic, Greek, Arabic,
#                    Hebrew, Indic, CJK, emoji) so non-ASCII metadata/filenames render
#   locales        : real UTF-8 locale (en_US.UTF-8) for correct sorting/handling
# NOTE: fonts-noto-cjk adds a few hundred MB; acceptable for a full burning suite.
RUN add-pkg k3b cdrdao dvd+rw-tools wodim genisoimage cdparanoia icedax libcdio-utils \
            flac lame vorbis-tools opus-tools wavpack \
            adwaita-qt dbus-x11 dbus udev udisks2 \
            fonts-noto-core fonts-noto-cjk fonts-noto-color-emoji \
            locales

# dbus registers a dpkg-statoverride for the "messagebus" group, but the baseimage
# rebuilds /etc/group at startup without it, leaving the override dangling so any
# runtime apt/dpkg (CJK font installer, INSTALL_PACKAGES) aborts. Remove it at build.
RUN dpkg-statoverride --list 2>/dev/null | grep -w messagebus | awk '{print $NF}' \
      | xargs -r -n1 dpkg-statoverride --remove || true

# Generate a real UTF-8 locale. startapp.sh still defaults LC_ALL=C.UTF-8, but any
# component that expects a named locale (sorting, some Qt paths) gets a valid one.
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen

# App start script.
COPY startapp.sh /startapp.sh
RUN chmod +x /startapp.sh

# Files copied into the container image (device-access env hook, drive-detection
# init script, etc.).
COPY rootfs/ /
RUN chmod +x /etc/cont-env.d/SUP_GROUP_IDS_INTERNAL \
             /etc/cont-init.d/50-optical-stack.sh

# App identity shown in the web UI.
RUN set-cont-env APP_NAME "K3b"

# Standard mount points this image expects.
#   /config  : persistent app config and state
#   /storage : user source/output files (read-write so rips and images can be written)
VOLUME ["/config", "/storage"]

# noVNC web UI.
EXPOSE 5800

# OCI image metadata.
LABEL org.opencontainers.image.title="k3b-web" \
      org.opencontainers.image.description="K3b (KDE CD/DVD burning suite) accessible from a web browser. Unofficial, not affiliated with the K3b project." \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/nnaqsoft/k3b-web"
