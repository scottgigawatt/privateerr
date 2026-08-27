#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# collect-dockerfile-base-images.awk: Resolve global Dockerfile ARG defaults
#                                     used by FROM instructions and print each
#                                     external base image once.
#
# Usage: awk -f scripts/awk/collect-dockerfile-base-images.awk <Dockerfiles>
#

#
# clear_array: Remove every entry from an associative array portably.
#
# Parameters: values - Associative array to clear.
#             key    - Function-local iteration key; callers must not supply it.
#
# Returns: Nothing.
#
function clear_array(values,    key) {
  for (key in values) {
    delete values[key]
  }
}

#
# trim: Remove leading and trailing horizontal whitespace.
#
# Parameters: value - String to trim.
#
# Returns: The trimmed string.
#
function trim(value) {
  sub(/^[[:space:]]+/, "", value)
  sub(/[[:space:]]+$/, "", value)
  return value
}

#
# resolve_arguments: Replace Dockerfile variable references with known global
#                    ARG defaults.
#
# Parameters: value     - FROM image token to resolve.
#             output    - Function-local resolved-token buffer.
#             position  - Function-local cursor within value.
#             character - Function-local character at position.
#             closing   - Function-local offset of a closing brace.
#             name      - Function-local Dockerfile ARG name.
#             end       - Function-local end of an unbraced ARG name.
#
# Returns: The resolved token. Sets resolve_failed when a value is unavailable.
#
function resolve_arguments(value,    output, position, character, closing, name, end) {
  output = ""
  resolve_failed = 0

  for (position = 1; position <= length(value); position++) {
    character = substr(value, position, 1)
    if (character != "$") {
      output = output character
      continue
    }

    if (substr(value, position + 1, 1) == "{") {
      closing = index(substr(value, position + 2), "}")
      if (closing == 0) {
        resolve_failed = 1
        return value
      }

      name = substr(value, position + 2, closing - 1)
      position += closing + 1
    } else {
      end = position + 1
      while (end <= length(value) && substr(value, end, 1) ~ /[A-Za-z0-9_]/) {
        end++
      }

      name = substr(value, position + 1, end - position - 1)
      if (name == "") {
        output = output character
        continue
      }
      position = end - 1
    }

    if (!(name in docker_arguments)) {
      resolve_failed = 1
      return value
    }
    output = output docker_arguments[name]
  }

  return output
}

#
# Reset Dockerfile-scoped ARG and stage state for each input file.
#
FNR == 1 {
  clear_array(docker_arguments)
  clear_array(build_stages)
  first_from_seen = 0
}

{
  instruction_line = trim($0)
  if (instruction_line == "" || substr(instruction_line, 1, 1) == "#") {
    next
  }

  field_count = split(instruction_line, instruction_fields, /[[:space:]]+/)
  instruction = toupper(instruction_fields[1])

  # Only ARG instructions before the first FROM can affect a FROM reference.
  if (instruction == "ARG" && !first_from_seen) {
    argument = substr(instruction_line, length(instruction_fields[1]) + 1)
    argument = trim(argument)
    equals = index(argument, "=")

    if (equals == 0) {
      delete docker_arguments[argument]
    } else {
      argument_name = trim(substr(argument, 1, equals - 1))
      argument_value = trim(substr(argument, equals + 1))
      docker_arguments[argument_name] = argument_value
    }
    next
  }

  if (instruction != "FROM") {
    next
  }

  first_from_seen = 1
  image_field = 2
  while (image_field <= field_count && instruction_fields[image_field] ~ /^--/) {
    image_field++
  }
  if (image_field > field_count) {
    next
  }

  base_image = resolve_arguments(instruction_fields[image_field])
  if (resolve_failed) {
    next
  }

  normalized_image = tolower(base_image)
  if (normalized_image != "scratch" && !(normalized_image in build_stages) && !(base_image in printed_images)) {
    print base_image
    printed_images[base_image] = 1
  }

  alias_field = image_field + 1
  if (alias_field + 1 <= field_count && toupper(instruction_fields[alias_field]) == "AS") {
    build_stages[tolower(instruction_fields[alias_field + 1])] = 1
  }
}
