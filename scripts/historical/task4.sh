#!/usr/bin/env bash
set -Eeuo pipefail

BENCH="${BENCH_ROOT:?Set BENCH_ROOT to your disposable benchmark directory}"
MODEL="${MODEL:-gpt-5.6-sol}"
EFFORT="${EFFORT:-high}"

# Publication adaptation: require an explicit disposable-directory marker.
# Implementation scripts reset and clean the three checkout directories.
[[ -f "$BENCH/.disposable-benchmark" ]] || {
  echo "ERROR: Create .disposable-benchmark only in your disposable benchmark root" >&2
  exit 1
}

# --------------------------------------------------
# TASK
# --------------------------------------------------

TASK=$(cat <<'EOF'
I want to be able to import and export a application project in the native format and transfer a project from one instance to the other.
EOF
)

# --------------------------------------------------
# SETUP
# --------------------------------------------------

[[ -f "$BENCH/base-commit" ]] || {
  echo "ERROR: $BENCH/base-commit does not exist"
  exit 1
}

BASE_COMMIT=$(<"$BENCH/base-commit")

mkdir -p "$BENCH/results"

RUN_DIR=$(mktemp -d \
  "$BENCH/results/$(date +%Y%m%d-%H%M%S)-XXXX")

echo "Results: $RUN_DIR"
echo "Base commit: $BASE_COMMIT"
echo "Model: $MODEL"
echo "Effort: $EFFORT"

# --------------------------------------------------
# RESET WORKTREE
# --------------------------------------------------

reset_variant() {
  local variant="$1"
  local dir="$BENCH/$variant"

  echo "Restoring $variant to $BASE_COMMIT"

  # Discard tracked changes and local commits.
  git -C "$dir" reset --hard "$BASE_COMMIT" || return 1

  # Remove untracked and ignored artifacts.
  # Preserve dependencies and context indexes.
  #
  # WARNING: This deletes all other untracked and
  # ignored files in the disposable benchmark worktree.
  git -C "$dir" clean -fdx \
    -e 'node_modules/' \
    -e 'graft/' \
    -e '.graft/' \
    -e '.codegraph/' || return 1

  # Update indexes to match restored source.
  case "$variant" in
    graft)
      (
        cd "$dir" || exit 1
        graft build
      ) || return 1
      ;;

    codegraph)
      (
        cd "$dir" || exit 1

        if [[ -d .codegraph ]]; then
          codegraph sync
        else
          codegraph init
        fi
      ) || return 1
      ;;
  esac

  # Verify starting commit.
  if [[ "$(git -C "$dir" rev-parse HEAD)" != "$BASE_COMMIT" ]]; then
    echo "ERROR: Wrong starting commit"
    return 1
  fi

  # Verify index preparation did not modify tracked source.
  if ! git -C "$dir" diff --quiet HEAD -- ||
     ! git -C "$dir" diff --cached --quiet; then
    echo "ERROR: Tracked files differ before Codex starts"
    git -C "$dir" status --short
    return 1
  fi
}

# --------------------------------------------------
# SAVE IMPLEMENTATION
# --------------------------------------------------

save_variant() {
  local variant="$1"
  local dir="$BENCH/$variant"

  # Preserve modifications to tracked files.
  git -C "$dir" diff --binary "$BASE_COMMIT" -- \
    > "$RUN_DIR/$variant.patch"

  # Preserve newly created, non-ignored files.
  (
    cd "$dir" || exit 1

    git ls-files --others --exclude-standard -z |
      tar \
        --create \
        --gzip \
        --file="$RUN_DIR/$variant-new-files.tar.gz" \
        --null \
        --exclude='graft/*' \
        --exclude='.graft/*' \
        --exclude='.codegraph/*' \
        --files-from=-
  )

  # Save working tree status.
  git -C "$dir" status --short \
    > "$RUN_DIR/$variant-git-status.txt"
}

# --------------------------------------------------
# BENCHMARK
# --------------------------------------------------

for variant in baseline graft codegraph; do
  echo
  echo "========================================"
  echo "Running: $variant"
  echo "========================================"

  reset_variant "$variant" || exit 1

  mcp=()
  instructions=""

  case "$variant" in
    baseline)
      instructions="Use normal source-code navigation.
Do not use Graft, CodeGraph, or their indexes."
      ;;

    graft)
      mcp=(
        -c 'mcp_servers.graft.command="graft"'
        -c 'mcp_servers.graft.args=["mcp"]'
        -c 'mcp_servers.graft.required=true'
        -c 'mcp_servers.graft.default_tools_approval_mode="approve"'
      )

      instructions="Use the Graft MCP server and call graft_find_code
at least once before answering.
Do not execute graft or codegraph shell commands."
      ;;

    codegraph)
      mcp=(
        -c 'mcp_servers.codegraph.command="codegraph"'
        -c 'mcp_servers.codegraph.args=["serve","--mcp"]'
        -c 'mcp_servers.codegraph.required=true'
        -c 'mcp_servers.codegraph.default_tools_approval_mode="approve"'
      )

      instructions="Use the CodeGraph MCP server and call codegraph_explore
at least once before answering.
Do not execute graft or codegraph shell commands."
      ;;
  esac

  # ------------------------------------------------
  # RUN CODEX
  # ------------------------------------------------

  run_exit=0

  if (
    cd "$BENCH/$variant" || exit 1

    export PATH="$BENCH/guards/$variant:$PATH"

    /usr/bin/time -f '%e' \
      -o "$RUN_DIR/$variant.time" \
      codex exec \
        --json \
        --ephemeral \
        --ignore-user-config \
        --sandbox workspace-write \
        --model "$MODEL" \
        -c "model_reasoning_effort=\"$EFFORT\"" \
        "${mcp[@]}" \
        "$instructions

$TASK" \
        > "$RUN_DIR/$variant.jsonl" \
        2> "$RUN_DIR/$variant.stderr"

  ); then
    :
  else
    run_exit=$?
  fi

  # Always save changes, including failed runs.
  save_variant "$variant"

  LOG="$RUN_DIR/$variant.jsonl"

  # ------------------------------------------------
  # VALIDATION
  # ------------------------------------------------

  if (( run_exit != 0 )); then
    echo "FAILED: Codex returned exit code $run_exit"
    tail -20 "$RUN_DIR/$variant.stderr"
    continue
  fi

  # Require a completed turn.
  if ! jq -e '
    select(.type=="turn.completed")
  ' "$LOG" >/dev/null; then
    echo "INVALID: No completed turn"
    continue
  fi

  # Reject failed MCP calls.
  if jq -e '
    select(
      .type=="item.completed"
      and .item.type=="mcp_tool_call"
      and .item.status!="completed"
    )
  ' "$LOG" >/dev/null; then
    echo "INVALID: Failed MCP call"
    continue
  fi

  # Reject shell invocation of context tools.
  # This benchmark is MCP-only.
  if jq -e '
    select(
      .type=="item.completed"
      and .item.type=="command_execution"
      and (
        (.item.command // "") |
        test(
          "(^|[^A-Za-z0-9_-])(graft|codegraph)[[:space:]]";
          "i"
        )
      )
    )
  ' "$LOG" >/dev/null; then
    echo "INVALID: Context tool invoked through CLI"
    continue
  fi

  # Require correct MCP usage.
  if [[ "$variant" == "baseline" ]]; then

    if jq -e '
      select(
        .type=="item.completed"
        and .item.type=="mcp_tool_call"
      )
    ' "$LOG" >/dev/null; then
      echo "INVALID: Baseline used MCP"
      continue
    fi

  else

    if ! jq -e --arg server "$variant" '
      select(
        .type=="item.completed"
        and .item.type=="mcp_tool_call"
        and .item.server==$server
        and .item.status=="completed"
      )
    ' "$LOG" >/dev/null; then
      echo "INVALID: Required MCP server not used"
      continue
    fi

  fi

  echo "VALID RUN: $variant"

  # ------------------------------------------------
  # TOKEN STATISTICS
  # ------------------------------------------------

  jq -s '
    [.[] | select(.type=="turn.completed") | .usage]
    | {
        input: (
          map(.input_tokens // 0) | add // 0
        ),
        cached: (
          map(.cached_input_tokens // 0) | add // 0
        ),
        output: (
          map(.output_tokens // 0) | add // 0
        ),
        total: (
          map(
            (.input_tokens // 0) +
            (.output_tokens // 0)
          ) | add // 0
        )
      }
  ' "$LOG"

  echo -n "Seconds: "
  cat "$RUN_DIR/$variant.time"

  echo "MCP calls:"

  jq -r '
    select(
      .type=="item.completed"
      and .item.type=="mcp_tool_call"
    )
    | [
        .item.server,
        .item.tool,
        .item.status
      ]
    | @tsv
  ' "$LOG"

  echo "Saved patch: $RUN_DIR/$variant.patch"

done

# --------------------------------------------------
# FINISHED
# --------------------------------------------------

echo
echo "========================================"
echo "Benchmark completed"
echo "========================================"
echo "Results saved to: $RUN_DIR"