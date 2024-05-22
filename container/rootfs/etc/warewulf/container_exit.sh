#!/bin/sh
#set -x
LANG=C
LC_CTYPE=C
export LANG LC_CTYPE
dnf clean all
rm -rf /var/cache/dnf/*
rm -rf /tmp/*
