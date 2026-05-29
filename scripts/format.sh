#!/usr/bin/env bash
# Auto-format all Swift sources. Run before pushing; CI only lints.
set -euo pipefail
swiftformat .
