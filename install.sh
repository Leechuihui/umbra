#!/usr/bin/env bash

# Copyright (C) 2026 leechuihui
# SPDX-License-Identifier: GPL-3.0-or-later
# See LICENSE in the repository root.

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Invoke through bash explicitly so a missing +x bit cannot break the install.
exec bash "$ROOT/install/linux.sh" "$@"