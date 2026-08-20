#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# order-environment.awk: Print resolved Compose environment assignments in the
#                        same order as the selected preset environment file.
#
# Usage: awk -F = -f scripts/awk/order-environment.awk - <environment-file>
#

#
# Record valid assignments from the resolved environment input by variable
# name, then continue with the selected preset environment file.
#
NR == FNR {

  # Retain only syntactically valid environment assignments.
  if ($0 ~ /^[A-Za-z_][A-Za-z0-9_]*=/) {
    values[$1] = $0
  }

  next
}

#
# Print each resolved assignment when its variable appears in the selected
# preset environment file.
#
$0 ~ /^[A-Za-z_][A-Za-z0-9_]*=/ && $1 in values {
  print values[$1]
}
