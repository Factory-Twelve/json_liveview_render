#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HEX_CONFIG_PATHS=(
  "$HOME/.hex/hex.config"
  "$HOME/.config/hex/hex.config"
  "$HOME/.mix/hex.config"
)

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/hex_release_dry_run.sh

Runs the local Hex release readiness pipeline:
  1) mix deps.get
  2) mix ci
  3) mix hex.build
  4) mix hex.publish --dry-run
USAGE
}

require_repo_root() {
  if [ ! -f "$REPO_ROOT/mix.exs" ]; then
    echo "Unable to locate mix.exs in repo root: $REPO_ROOT" >&2
    echo "Run this script from the project root directory." >&2
    echo "Current path: $(pwd)" >&2
    exit 1
  fi
}

require_tool() {
  local tool="$1"
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Required tool not found: $tool" >&2
    echo "Install the missing tool and rerun this script." >&2
    exit 1
  fi
}

require_hex_credentials() {
  if [ -n "${HEX_API_KEY:-}" ]; then
    return
  fi

  local config_file
  local hex_config

  for config_file in "${HEX_CONFIG_PATHS[@]}"; do
    if [ -f "$config_file" ]; then
      if grep -Eq '"api_key"|:api_key|"auth_key"|:auth_key' "$config_file"; then
        return
      fi
    fi
  done

  if hex_config="$(mix hex.config 2>/dev/null || true)"; then
    if printf '%s\n' "$hex_config" | grep -Eq '"api_key"|:api_key|"auth_key"|:auth_key'; then
      return
    fi
  fi

  cat <<'ERROR' >&2
Hex credentials not detected.

Set up credentials before running this script:
  - export HEX_API_KEY=<your_hex_api_key>
  - or authenticate with `mix hex.user auth`

Then rerun:
  ./scripts/hex_release_dry_run.sh
ERROR
  exit 1
}

run_step() {
  local step="$1"
  shift

  printf '\n==> %s\n' "$step"
  if "$@"; then
    return
  fi

  echo "Release dry-run failed while running: $step" >&2
  echo "Full command: $*" >&2
  echo "Failed command output is shown above." >&2
  echo "Suggested next steps:" >&2

  case "$step" in
    "mix ci")
      echo "  - Fix the CI-format/compile/test failure and rerun this script." >&2
      ;;
    "mix hex.build")
      echo "  - Inspect build warnings/errors and rerun after fixing any packaging blockers." >&2
      ;;
    "mix hex.publish --dry-run")
      echo "  - Review publish blockers with the hex output and fix metadata/version/package issues." >&2
      echo "  - Validate package metadata in mix.exs before rerunning." >&2
      ;;
    *)
      echo "  - Re-run the failed command directly for detailed diagnostics." >&2
      ;;
  esac

  echo "  - If credentials are the issue, re-check `HEX_API_KEY` or run `mix hex.user auth`." >&2
  exit 1
}

main() {
  usage

  if (( ${#} > 0 )); then
    echo
    echo "This script does not take arguments." >&2
    usage
    exit 1
  fi

  cd "$REPO_ROOT"

  require_repo_root
  require_tool mix

  if [ ! -f "$REPO_ROOT/mix.exs" ]; then
    echo "Could not find mix.exs after resolving repo root." >&2
    exit 1
  fi

  require_hex_credentials

  run_step "mix deps.get" mix deps.get
  run_step "mix ci" mix ci
  run_step "mix hex.build" mix hex.build
  run_step "mix hex.publish --dry-run" mix hex.publish --dry-run

  echo "\nHex dry-run release checks passed."
  echo "Next step for publish: run `mix hex.publish` from the repo root once you are ready."
}

main "$@"
