#!/usr/bin/env bash
# PreToolUse(Bash) guard — defense-in-depth for the GTM Foundation safety rule.
# The aggressive allowlist in settings.json lets routine work run without prompts;
# this guard is the backstop that still refuses the few things that must never be
# autonomous. Exit 2 = block the tool call (stderr is shown to Claude).
input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null)
[ -z "$cmd" ] && exit 0

# 1. No live sends. Foundation section: default is --dry-run; --live requires a human.
# Only fires when the command actually EXECUTES a launcher/script (first token is an
# interpreter or a script path) AND carries a live flag — so it does not false-positive
# on `git commit -m "...--live..."`, `grep --live`, or `echo`.
first=$(printf '%s' "$cmd" | sed -E 's/^[[:space:]]*//; s/^cd[[:space:]][^&]*&&[[:space:]]*//; s/^[[:space:]]*//')
if printf '%s' "$first" | grep -Eq '^(python3?|bash|sh|make|node|npm|npx|\./|scripts/|src/)' \
   && printf '%s' "$cmd" | grep -Eq -- '(^|[[:space:]])(--live|--no-dry-run|--send-live)([[:space:]]|=|$)'; then
  echo "BLOCKED: a live flag was passed to an executed script. Per CLAUDE.md and 00_GTM_Foundation.md, live sends / production PlusVibe calls require explicit human authorization and must not run autonomously." >&2
  exit 2
fi

# 2. No force-push and no push to shared branches.
if printf '%s' "$cmd" | grep -Eq '\bgit\b.*\bpush\b'; then
  if printf '%s' "$cmd" | grep -Eq -- '(--force|--force-with-lease|-f)\b'; then
    echo "BLOCKED: force-push refused. Work stays on the feature branch with a normal push." >&2
    exit 2
  fi
  if printf '%s' "$cmd" | grep -Eq '\borigin[[:space:]]+(main|master)\b|:[[:space:]]*(main|master)\b'; then
    echo "BLOCKED: refusing to push to main/master. Push to the claude/* feature branch only." >&2
    exit 2
  fi
fi

# 3. No catastrophic deletes on root/home.
if printf '%s' "$cmd" | grep -Eq 'rm\s+-[a-zA-Z]*r[a-zA-Z]*f?\s+(/|~|\$HOME|/\*)(\s|$)'; then
  echo "BLOCKED: refusing recursive delete on a root/home path." >&2
  exit 2
fi

exit 0
