#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# strip-comments.awk: Remove comments, trailing whitespace, and empty lines
#                     from raw Compose and environment configuration output.
#
# Usage: awk -f scripts/awk/strip-comments.awk <configuration-file>
#

#
# Remove the first comment and everything after it, trim trailing whitespace,
# and print only records that still contain fields.
#
{
  sub(/#.*/, "")
  sub(/[[:space:]]+$/, "")

  # Print only records that retain at least one field after normalization.
  if (NF) {
    print
  }
}
