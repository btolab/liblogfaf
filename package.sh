#!/bin/bash

set -o pipefail -o errtrace -o errexit -o nounset -o functrace

# shellcheck disable=2155
export PROJECT=$(dirname "${PWD}")

git status --porcelain | grep -q . && GIT_STATE=dirty || GIT_STATE=clean
if ! DESCRIBE=$(git describe --tags --long --dirty 2>/dev/null | sed -r -e 's/^v?// ; s/-/ /g ; s/ 0 / 1 /') ; then
    echo >&2 "no tag"; exit 1
fi
IFS=' ' read -r -a BUILD <<< "$DESCRIBE"

export VERSION=${BUILD[0]}
export RELEASE=${BUILD[1]}
if [ 'dirty' = "${GIT_STATE}" ] ; then
    RELEASE=${RELEASE}+${BUILD[2]}
fi

function cleanup_install() {
    find "${DESTDIR}${LIBDIR}" ! -name 'liblogfaf.so.0.0.0' -type f -delete
    find "${DESTDIR}/" -type l -delete
}

if [ -f Makefile ] ; then
    make distclean
fi

export DESTDIR=${PWD}/dist/

autoreconf -i -f >/dev/null

if LIBDIR="/usr/lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH 2>/dev/null)" ; then
    echo "building deb"
    rm -rf "${DESTDIR}"
    ./configure --prefix=/usr --libdir="${LIBDIR}" >/dev/null
    make install >/dev/null
    cleanup_install
    nfpm package -f nfpm.yaml -p deb
fi

if LIBDIR=$(rpm --eval "%{_libdir}") ; then
    echo "building rpm"
    rm -rf "${DESTDIR}"
    ./configure --prefix="$(rpm --eval "%{_prefix}")" --libdir="${LIBDIR}" >/dev/null
    make install >/dev/null
    cleanup_install
    nfpm package -f nfpm.yaml -p rpm
fi
