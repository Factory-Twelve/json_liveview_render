#!/usr/bin/env bash
set -euo pipefail

PLAN_FILE="${BASH_SOURCE%/*}/ci_plan.md"

PLAN_COMMANDS=()
PLAN_MATRIX=()

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/ci_local.sh [--matrix "1.15,1.19"]
  ./scripts/ci_local.sh --dry-run --matrix "1.15,1.19"

Options:
  --dry-run  Show the resolved check plan without running commands.
  --matrix   Comma-separated list of plan matrix versions to run.
             Defaults to all plan versions.
  -h, --help
             Show this help text.
USAGE
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

load_plan() {
  if [ ! -f "$PLAN_FILE" ]; then
    echo "ci plan file not found: $PLAN_FILE" >&2
    exit 1
  fi

  local section=""
  while IFS= read -r line; do
    line="$(trim "$line")"

    case "$line" in
      "## Commands")
        section="commands"
        continue
        ;;
      "## Matrix")
        section="matrix"
        continue
        ;;
      "## "*)
        section=""
        continue
        ;;
    esac

    case "$section" in
      commands)
        if [ "${line:0:1}" = "-" ]; then
          local entry command_name command
          entry="${line#- }"
          command_name="${entry%%:*}"
          command="${entry#*: }"
          PLAN_COMMANDS+=("${command_name}|${command}")
        fi
        ;;

      matrix)
        if [ -z "$line" ] || [ "${line:0:1}" = "#" ]; then
          continue
        fi

        PLAN_MATRIX+=("$line")
        ;;
    esac
  done < "$PLAN_FILE"

  if (( "${#PLAN_MATRIX[@]}" == 0 )); then
    echo "plan has no matrix entries: $PLAN_FILE" >&2
    exit 1
  fi
}

plan_versions() {
  local versions=""

  for entry in "${PLAN_MATRIX[@]}"; do
    local version="${entry%%|*}"
    if [ -z "$versions" ]; then
      versions="$version"
    else
      versions="${versions},${version}"
    fi
  done

  printf '%s' "$versions"
}

matrix_entry_for_version() {
  local requested="$1"
  for entry in "${PLAN_MATRIX[@]}"; do
    local version="${entry%%|*}"
    if [ "$version" = "$requested" ]; then
      printf '%s' "$entry"
      return 0
    fi
  done
  return 1
}

command_for_check() {
  local check="$1"
  local entry
  local name

  for entry in "${PLAN_COMMANDS[@]}"; do
    name="${entry%%|*}"
    if [ "$name" = "$check" ]; then
      echo "${entry#*|}"
      return 0
    fi
  done
  return 1
}

in_list() {
  local version="$1"
  local values="$2"
  local seen_version

  for seen_version in $values; do
    if [ "$seen_version" = "$version" ]; then
      return 0
    fi
  done

  return 1
}

parse_matrix_arg() {
  local selected="$1"
  if [ -z "$selected" ]; then
    selected="$(plan_versions)"
  fi

  local selected_versions=""
  local original_ifs=$IFS
  IFS=,
  set -- $selected
  IFS=$original_ifs

  local version
  for version in "$@"; do
    version="$(trim "$version")"
    if [ -z "$version" ]; then
      continue
    fi

    matrix_entry_for_version "$version" >/dev/null || {
      echo "Unknown matrix version requested: $version" >&2
      echo "Available versions: $(plan_versions)" >&2
      exit 1
    }

    if ! in_list "$version" "$selected_versions"; then
      if [ -z "$selected_versions" ]; then
        selected_versions="$version"
      else
        selected_versions="$selected_versions $version"
      fi
    fi
  done

  if [ -z "$selected_versions" ]; then
    echo "No matrix versions selected." >&2
    exit 1
  fi

  echo "$selected_versions"
}

run_check() {
  local matrix="$1"
  local check_name="$2"
  local command="$3"

  echo "  -> ${check_name}: ${command}"
  if ! eval "$command"; then
    echo "❌ CI check '${check_name}' failed in matrix slot ${matrix}." >&2
    echo "   Plan file: ${PLAN_FILE}" >&2
    echo "   Command: ${command}" >&2
    echo "   Re-run with: ./scripts/ci_local.sh --matrix ${matrix}" >&2
    exit 1
  fi
}

ensure_toolchain() {
  local version="$1"
  local expected_elixir="$2"
  local expected_otp="$3"

  local actual_elixir actual_otp expected_otp_major

  if ! command -v elixir >/dev/null 2>&1; then
    echo "❌ Matrix slot ${version} requires Elixir ${expected_elixir} and OTP ${expected_otp}, but 'elixir' is not installed or not on PATH." >&2
    echo "   Configure your local toolchain (asdf/mise/kerl) before running CI parity locally." >&2
    exit 1
  fi

  actual_elixir="$(elixir -e 'IO.puts(System.version())' 2>/dev/null || true)"
  actual_otp="$(elixir -e 'IO.puts(:erlang.system_info(:otp_release))' 2>/dev/null || true)"

  if [ -z "$actual_elixir" ] || [ -z "$actual_otp" ]; then
    echo "❌ Unable to read local Elixir/OTP versions from 'elixir'." >&2
    echo "   Ensure mix and elixir are fully available before running this script." >&2
    exit 1
  fi

  expected_otp_major="${expected_otp%%.*}"
  if [ "$actual_elixir" != "$expected_elixir" ] || (
    [ "$actual_otp" != "$expected_otp" ] && [ "$actual_otp" != "$expected_otp_major" ]
  ); then
    echo "❌ Matrix slot ${version} requires Elixir ${expected_elixir} + OTP ${expected_otp}, but local runtime is Elixir ${actual_elixir}, OTP ${actual_otp}." >&2
    echo "   Switch to the expected toolchain before running: ./scripts/ci_local.sh --matrix ${version}" >&2
    exit 1
  fi

  echo "  -> runtime ok: Elixir ${actual_elixir}, OTP ${actual_otp}"
}

dry_run_checks() {
  local version="$1"
  local entry="$2"
  local checks_csv
  local check
  local command

  local elixir otp
  IFS='|' read -r version elixir otp checks_csv <<< "$entry"

  echo "==> Plan for matrix slot ${version} (elixir ${elixir}, otp ${otp})"

  IFS=,
  set -- $checks_csv
  IFS=$' \t\n'
  for check in "$@"; do
    check="$(trim "$check")"
    if [ -z "$check" ]; then
      continue
    fi

    command="$(command_for_check "$check")" || {
      echo "Unknown check '${check}' for matrix slot ${version} in $PLAN_FILE" >&2
      exit 1
    }
    echo "  - ${check}: ${command}"
  done
}

run_matrix() {
  local version="$1"
  local entry="$2"
  local elixir otp checks_csv
  local check
  local command

  IFS='|' read -r version elixir otp checks_csv <<< "$entry"

  echo "==> Running matrix slot ${version} (elixir ${elixir}, otp ${otp})"
  ensure_toolchain "$version" "$elixir" "$otp"

  IFS=,
  set -- $checks_csv
  IFS=$' \t\n'
  for check in "$@"; do
    check="$(trim "$check")"
    if [ -z "$check" ]; then
      continue
    fi

    command="$(command_for_check "$check")" || {
      echo "Unknown check '${check}' for matrix slot ${version} in $PLAN_FILE" >&2
      exit 1
    }
    run_check "$version" "$check" "$command"
  done
}

load_plan

selected_matrix=""
dry_run="false"
while (( "$#" > 0 )); do
  case "$1" in
    --dry-run)
      dry_run="true"
      shift
      ;;
    --matrix)
      if (( "$#" < 2 )); then
        echo "--matrix requires an argument like '1.15,1.19'" >&2
        exit 1
      fi
      selected_matrix="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [ -z "$selected_matrix" ]; then
  selected_matrix="$(plan_versions)"
fi

echo "==> CI matrix plan: $selected_matrix"
selected_entries="$(parse_matrix_arg "$selected_matrix")"

if [ "$dry_run" = "true" ]; then
  for version in $selected_entries; do
    entry="$(matrix_entry_for_version "$version")"
    dry_run_checks "$version" "$entry"
  done
  echo "No checks were run. Remove --dry-run to execute."
  exit 0
fi

for version in $selected_entries; do
  entry="$(matrix_entry_for_version "$version")"
  run_matrix "$version" "$entry"
done

echo "==> Local CI passed"
