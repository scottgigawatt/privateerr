#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# collect-dockerfile-base-images.awk: Resolve Dockerfile ARG defaults used by
#                                     FROM instructions and print base images.
#
# Usage: awk -f scripts/awk/collect-dockerfile-base-images.awk <Dockerfiles>
#

#
# Record build-argument defaults that a later FROM instruction may reference.
#
/^ARG / {
  split($2, argument_parts, "=")
  docker_arguments[argument_parts[1]] = argument_parts[2]
}

#
# Resolve every known build argument in each base-image reference.
#
/^FROM / {
  base_image = $2

  # Substitute the Dockerfile's ${NAME} expression with its declared default.
  for (argument_name in docker_arguments) {
    gsub("\\$[{]" argument_name "[}]", docker_arguments[argument_name], base_image)
  }

  print base_image
}
