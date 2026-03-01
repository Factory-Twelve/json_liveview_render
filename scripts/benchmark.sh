#!/usr/bin/env bash
set -euo pipefail

if [ "${CI:-false}" = "true" ]; then
  mix json_liveview_render.bench "$@" --format json
else
  mix json_liveview_render.bench "$@"
fi
