#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# __main__.py: Start Privateerr's foreground supervisor.
#

"""Start Privateerr's foreground supervisor."""

from .supervisor import main

# Return the supervisor result as the container exit code for Docker and one-shot callers.
raise SystemExit(main())
