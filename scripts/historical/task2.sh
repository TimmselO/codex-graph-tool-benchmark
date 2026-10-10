#!/usr/bin/env bash
set -o pipefail

BENCH="${BENCH_ROOT:?Set BENCH_ROOT to your disposable benchmark directory}"
MODEL="${MODEL:-gpt-5.6-sol}"
EFFORT="${EFFORT:-high}"

# Publication adaptation: require an explicit disposable-directory marker.
# Implementation scripts reset and clean the three checkout directories.
[[ -f "$BENCH/.disposable-benchmark" ]] || {
  echo "ERROR: Create .disposable-benchmark only in your disposable benchmark root" >&2
  exit 1
}

mkdir -p "$BENCH/results"
RUN_DIR=$(mktemp -d "$BENCH/results/$(date +%Y%m%d-%H%M%S)-XXXX")

TASK="Trace map export through the runtime
Do not modify any code."

echo "Results: $RUN_DIR"

for variant in baseline graft codegraph; do
  echo
  echo "=== Running: $variant ==="

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
        -c 'mcp_servers.graft.env.GRAFT_NO_REFRESH="1"'
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

  if (
    cd "$BENCH/$variant" || exit 1

    export PATH="$BENCH/guards/$variant:$PATH"

    /usr/bin/time -f '%e' \
      -o "$RUN_DIR/$variant.time" \
      codex exec \
        --json \
        --ephemeral \
        --ignore-user-config \
        --sandbox read-only \
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
    echo "FAILED: Codex process returned an error"
    tail -20 "$RUN_DIR/$variant.stderr"
    continue
  fi

  LOG="$RUN_DIR/$variant.jsonl"

  if ! jq -e 'select(.type=="turn.completed")' \
      "$LOG" >/dev/null; then
    echo "INVALID: No completed turn"
    continue
  fi

  # Reject failed MCP calls.
  if jq -e '
    select(.type=="item.completed"
      and .item.type=="mcp_tool_call"
      and .item.status!="completed")
  ' "$LOG" >/dev/null; then
    echo "INVALID: Failed MCP call"
    continue
  fi

  # Reject any shell invocation of the context tools.
  # This benchmark is MCP-only.
  if jq -e '
    select(.type=="item.completed"
      and .item.type=="command_execution"
      and (.item.command |
        test("(^|[^A-Za-z0-9_-])(graft|codegraph)[[:space:]]"; "i")))
  ' "$LOG" >/dev/null; then
    echo "INVALID: Context tool invoked through CLI"
    continue
  fi

  if [[ "$variant" == "baseline" ]]; then
    if jq -e '
      select(.type=="item.completed"
        and .item.type=="mcp_tool_call")
    ' "$LOG" >/dev/null; then
      echo "INVALID: Baseline used MCP"
      continue
    fi
  else
    if ! jq -e --arg server "$variant" '
      select(.type=="item.completed"
        and .item.type=="mcp_tool_call"
        and .item.server==$server
        and .item.status=="completed")
    ' "$LOG" >/dev/null; then
      echo "INVALID: Required MCP server not used"
      continue
    fi
  fi

  echo "SUCCESS: $variant"

  jq -s '
    [.[] | select(.type=="turn.completed") | .usage]
    | {
        input: (map(.input_tokens // 0) | add // 0),
        cached: (map(.cached_input_tokens // 0) | add // 0),
        output: (map(.output_tokens // 0) | add // 0),
        total: (map(
          (.input_tokens // 0) +
          (.output_tokens // 0)
        ) | add // 0)
      }
  ' "$LOG"

  echo -n "Seconds: "
  cat "$RUN_DIR/$variant.time"

  echo "MCP calls:"
  jq -r '
    select(.type=="item.completed"
      and .item.type=="mcp_tool_call")
    | [.item.server, .item.tool, .item.status]
    | @tsv
  ' "$LOG"
done

echo
echo "Results saved to: $RUN_DIR"
