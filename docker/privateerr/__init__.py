#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# __init__.py: Privateerr configuration generation and recovery supervisor.
#

"""Generate PIA connection files and supervise Gluetun recovery in one process.

Configuration validation lives in config, HTTP requests in client, and connection
validation and file publication in settings. The supervisor coordinates those
pieces while the shell adapter runs the unmodified upstream PIA scripts.
"""
