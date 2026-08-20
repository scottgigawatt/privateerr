#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# collect-build-pins.awk: Extract and validate digest-pinned build dependency
#                         tags from one repository policy surface.
#
# Usage: awk -v surface=<name> -v expected_pins='<names>' \
#            -f test/policy/awk/collect-build-pins.awk <file>
#

#
# Find each uppercase build tag assignment and validate its pinned digest.
#
match($0, /[A-Z][A-Z0-9_]*_TAG[=:]/) {
  assignment = substr($0, RSTART, RLENGTH)
  pin_name   = assignment

  sub(/[=:]$/, "", pin_name)

  # Ignore runtime image selectors that are outside this build-input policy.
  if (expected_pins != "" && \
      index(" " expected_pins " ", " " pin_name " ") == 0) {
    next
  }

  remainder = substr($0, RSTART + RLENGTH)
  wrapper   = "${" pin_name ":-"

  sub(/^[[:space:]"]*/, "", remainder)

  # Unwrap the default-value syntax used by example environment files.
  if (index(remainder, wrapper) == 1) {
    remainder = substr(remainder, length(wrapper) + 1)
  }

  # Reject missing or malformed image, tool, and package digests.
  if (!match(remainder, /^[A-Za-z0-9][A-Za-z0-9._+\/:=-]*@sha256:[a-f0-9]+/)) {
    printf "Invalid or missing digest pin for %s in %s.\n", \
      pin_name, FILENAME > "/dev/stderr"
    invalid = 1
    next
  }

  pin_value = substr(remainder, RSTART, RLENGTH)
  digest    = pin_value

  sub(/^.*@sha256:/, "", digest)

  # Require the complete 256-bit digest rather than a shortened prefix.
  if (length(digest) != 64) {
    printf "Digest pin for %s in %s must contain 64 hexadecimal characters.\n", \
      pin_name, FILENAME > "/dev/stderr"
    invalid = 1
    next
  }

  print surface "|" pin_name "|" pin_value
}

#
# Return a failing status after processing so every malformed pin is reported.
#
END {
  # Propagate validation failures to the calling policy script.
  if (invalid) {
    exit 1
  }
}
