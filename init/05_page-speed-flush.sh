#!/usr/bin/env bash

set -e

if [[ -n "${DEBUG}" ]]; then
    set -x
fi

make flush-pagespeed-server-side-cache -f /usr/local/bin/actions.mk

