#!/bin/sh

#
# Copyright 2025-2026 Scott Gigawatt
#
# SPDX-License-Identifier: Apache-2.0
#
# notification-tags.sh: Validate short notification tags without exporting
#                       registry or repository owner prefixes across jobs.
#
# Usage: notification-tags.sh --image <expected-image> --tags <newline-tags>
#

#
# Keep all inputs as data and reject malformed options without printing values.
#
set -eu
LC_ALL=C
export LC_ALL
expected_image=""
notification_tags=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        --image | --tags)
            if [ "$#" -lt 2 ]; then
                echo 'Notification tag option requires a value.' >&2
                exit 2
            fi

            case "$1" in
                --image) expected_image=$2 ;;
                --tags) notification_tags=$2 ;;
            esac
            shift 2
            ;;
        --help)
            echo 'Usage: notification-tags.sh --image <expected-image> --tags <newline-tags>'
            exit 0
            ;;
        *)
            echo 'Unknown notification tag option.' >&2
            exit 2
            ;;
    esac
done

#
# The expected image is an untagged reference. Registry ports are allowed,
# while control characters, digests, tags, and pattern syntax are not.
#
case "${expected_image}" in
    '' | *[!A-Za-z0-9._/:-]* | /* | */ | *//*)
        echo 'Expected notification image must be an untagged image reference.' >&2
        exit 1
        ;;
esac

case "${expected_image##*/}" in
    *:*)
        echo 'Expected notification image must be an untagged image reference.' >&2
        exit 1
        ;;
esac

#
# Buffer every validated tag before printing anything. An invalid later entry
# cannot leak a partial metadata list. Blank lines remain optional metadata.
#
printf '%s\n' "${notification_tags}" | awk -v image="${expected_image}" '
    $0 == "" { next }
    {
        tag = $0
        prefix = image ":"

        if (index(tag, prefix) == 1) {
            tag = substr(tag, length(prefix) + 1)
        }

        if (tag !~ /^[A-Za-z0-9_][A-Za-z0-9_.-]*$/ || length(tag) > 128) {
            invalid = 1
        } else {
            tags[++count] = tag
        }
    }
    END {
        if (invalid) {
            print "Notification tags must be short Docker tags or references to the expected image." > "/dev/stderr"
            exit 1
        }

        for (index_number = 1; index_number <= count; index_number++) {
            print tags[index_number]
        }
    }
'
