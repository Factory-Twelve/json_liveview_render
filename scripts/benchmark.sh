#!/usr/bin/env bash
set -euo pipefail

if [ "${CI:-false}" = "true" ]; then
  filtered_args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --format=*)
        ;;
      --format)
        if [[ $# -gt 1 ]] && [[ "$2" != --* ]]; then
          shift
        fi
        ;;
      *)
        filtered_args+=("$1")
        ;;
    esac

    shift
  done

  mix json_liveview_render.bench "${filtered_args[@]}" --format json
else
  mix json_liveview_render.bench "$@"
fi
