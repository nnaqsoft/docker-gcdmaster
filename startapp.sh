#!/bin/sh
#
# Launch gcdmaster inside the noVNC desktop provided by jlesage/baseimage-gui.
#
# gcdmaster is a GTK app that expects $HOME to be writable so it can store its
# settings. Point HOME at the persisted /config volume so preferences survive
# container restarts.
#
export HOME=/config

# gcdmaster and its GSettings schema are installed under /usr/local (built from
# source, see Dockerfile). Make sure both are found at runtime.
export PATH="/usr/local/bin:$PATH"
export GSETTINGS_SCHEMA_DIR="/usr/local/share/glib-2.0/schemas"

exec /usr/local/bin/gcdmaster
