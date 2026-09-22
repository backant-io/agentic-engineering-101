#!/usr/bin/env bash
# PreToolUse hook: refuse any write that touches a protected path.
# The agent cannot talk its way past this, because it is not asked.
#
# Install:
#   cp guard-paths.sh .claude/hooks/ && chmod +x .claude/hooks/guard-paths.sh
#   register it in .claude/settings.json (see settings.json next to this file)
# Test:
#   ./guard-paths.sh --self-test
set -euo pipefail

# Paths no agent may write, matched against the path relative to the repo root.
# A "*" also matches "/", so "infra/*" covers everything below infra/.
PROTECTED=(
  ".env" ".env.*" "*.pem" "*.key"
  "secrets/*" "*/secrets/*"
  "infra/*" "terraform/*"
  ".github/workflows/*"
  "migrations/*"
  ".claude/settings.json" ".claude/hooks/*"
  "AGENTS.md" "CLAUDE.md"
)

deny() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

path_is_protected() {
  local p="${1#./}"
  for pat in "${PROTECTED[@]}"; do
    # shellcheck disable=SC2053
    [[ "$p" == $pat ]] && return 0
  done
  return 1
}

# ponytail: substring scan, so an agent that builds a path from variables gets
# through. Local hooks stop accidents; branch protection stops everything else.
command_is_protected() {
  local cmd="$1"
  for pat in "${PROTECTED[@]}"; do
    local literal="${pat//\*/}"
    [ -z "$literal" ] && continue
    [[ "$cmd" == *"$literal"* ]] && return 0
  done
  return 1
}

main() {
  local input tool cwd path cmd
  input="$(cat)"
  tool="$(jq -r '.tool_name // ""' <<<"$input")"
  cwd="$(jq -r '.cwd // ""' <<<"$input")"

  case "$tool" in
    Edit | Write | NotebookEdit)
      path="$(jq -r '.tool_input.file_path // ""' <<<"$input")"
      [ -n "$cwd" ] && path="${path#"$cwd"/}"
      path_is_protected "$path" &&
        deny "$path is a protected path. Ask a human, or change it in a PR a human reviews."
      ;;
    Bash)
      cmd="$(jq -r '.tool_input.command // ""' <<<"$input")"
      command_is_protected "$cmd" &&
        deny "That command names a protected path. Ask a human, or change it in a PR a human reviews."
      ;;
  esac
  exit 0 # no decision, the normal permission flow applies
}

self_test() {
  local out
  hook() { printf '%s' "$1" | "$0"; }

  out="$(hook '{"tool_name":"Edit","cwd":"/repo","tool_input":{"file_path":"/repo/.env"}}')"
  [[ "$out" == *'"deny"'* ]] || { echo "FAIL: .env was not blocked"; exit 1; }

  out="$(hook '{"tool_name":"Write","cwd":"/repo","tool_input":{"file_path":"/repo/infra/deep/main.tf"}}')"
  [[ "$out" == *'"deny"'* ]] || { echo "FAIL: nested infra path was not blocked"; exit 1; }

  out="$(hook '{"tool_name":"Edit","cwd":"/repo","tool_input":{"file_path":"/repo/src/app.ts"}}')"
  [ -z "$out" ] || { echo "FAIL: normal source file was blocked"; exit 1; }

  out="$(hook '{"tool_name":"Bash","cwd":"/repo","tool_input":{"command":"rm -rf terraform/"}}')"
  [[ "$out" == *'"deny"'* ]] || { echo "FAIL: bash touching terraform was not blocked"; exit 1; }

  out="$(hook '{"tool_name":"Bash","cwd":"/repo","tool_input":{"command":"npm test"}}')"
  [ -z "$out" ] || { echo "FAIL: harmless command was blocked"; exit 1; }

  echo "all checks passed"
}

[ "${1:-}" = "--self-test" ] && { self_test; exit 0; }
main
