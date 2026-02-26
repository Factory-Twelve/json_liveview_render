#!/usr/bin/env bash
set -euo pipefail

echo "==> Fetch dependencies"
mix deps.get

echo "==> Check formatting"
mix format --check-formatted

echo "==> Compile (warnings as errors)"
mix compile --warnings-as-errors

echo "==> Run tests"
mix test

echo "==> Local CI passed"
