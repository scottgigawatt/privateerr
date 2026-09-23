#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# data.py: Validate dynamic objects at the HTTP response boundary.
#

"""Keep untrusted JSON separate from the supervisor's typed connection settings."""

from collections.abc import Mapping
from typing import TypeGuard, cast


def object_fields(value: object) -> dict[str, object]:
    """Require an object with string keys before inspecting nested response fields."""
    if not isinstance(value, dict):
        raise ValueError("Expected a JSON object.")

    # Runtime dictionary checks cannot establish generic key and value types.
    fields = cast(Mapping[object, object], value)
    result: dict[str, object] = {}

    for key, item in fields.items():
        if not isinstance(key, str):
            raise ValueError("Expected a string object key.")

        result[key] = item

    return result


def is_object(value: object) -> TypeGuard[dict[str, object]]:
    """Narrow a JSON dictionary after verifying its string keys."""
    return isinstance(value, dict) and all(
        isinstance(key, str) for key in cast(Mapping[object, object], value)
    )


def is_list(value: object) -> TypeGuard[list[object]]:
    """Retain unknown JSON items as objects until their individual fields are checked."""
    return isinstance(value, list)
