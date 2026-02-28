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
  local elixir="$2"
  local otp="$3"
  local check_name="$4"
  local command="$5"
  local runtime
  local actual_elixir
  local actual_otp
  local runtime_otp_major

  echo "  -> ${check_name}: ${command}"

  if command -v elixir >/dev/null 2>&1; then
    runtime="$(elixir -e 'IO.puts(System.version())' 2>/dev/null || true)|$(elixir -e 'IO.puts(:erlang.system_info(:otp_release))' 2>/dev/null || true)"
    actual_elixir="${runtime%%|*}"
    actual_otp="${runtime##*|}"
    runtime_otp_major="${otp%%.*}"

    if [ "$actual_elixir" = "$elixir" ] && ([ "$actual_otp" = "$otp" ] || [ "$actual_otp" = "$runtime_otp_major" ]); then
      echo "  -> runtime ok: Elixir ${actual_elixir}, OTP ${actual_otp}"
      if eval "$command"; then
        return 0
      else
        echo "❌ CI check '${check_name}' failed in matrix slot ${matrix}." >&2
        echo "   Plan file: ${PLAN_FILE}" >&2
        echo "   Command: ${command}" >&2
        echo "   Re-run with: ./scripts/ci_local.sh --matrix ${matrix}" >&2
        exit 1
      fi
    fi
  fi

  if command -v asdf >/dev/null 2>&1; then
    if asdf shell erlang "$otp" asdf shell elixir "$elixir" bash -lc "$command"; then
      echo "  -> runtime ok via asdf: Elixir ${elixir}, OTP ${otp} for slot ${matrix}"
      return 0
    fi
  fi

  echo "❌ Matrix slot ${matrix} requires Elixir ${elixir} + OTP ${otp}, but local runtime does not match." >&2
  echo "   Configure your local toolchain manager to select the required runtime, or run each slot separately." >&2
  echo "   Re-run with: ./scripts/ci_local.sh --matrix ${matrix}" >&2
  echo "   Tip: 'asdf shell erlang ${otp}' then 'asdf shell elixir ${elixir}' can be used to switch in-band, if supported." >&2
  exit 1
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
    run_check "$version" "$elixir" "$otp" "$check" "$command"
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
