#!/bin/bash
# Claude Code Notification hook. Reads the hook's JSON payload from stdin and
# only signals "needs-input" for notification types that mean Claude is
# genuinely blocked waiting on the user (not purely informational ones).
#
# This script lives inside CapsLockLED.app/Contents/Resources and finds the
# caps-signal helper relative to itself, so it works no matter where the app
# is installed. No python/jq dependency — pure bash + sed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CAPS_SIGNAL="$SCRIPT_DIR/../MacOS/caps-signal"

INPUT="$(cat)"

# Extract the "notification_type" string value from the flat JSON payload.
NOTIFICATION_TYPE="$(printf '%s' "$INPUT" \
  | sed -n 's/.*"notification_type"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
  | head -1)"

case "$NOTIFICATION_TYPE" in
  permission_prompt|idle_prompt|agent_needs_input|elicitation_dialog)
    if [ -x "$CAPS_SIGNAL" ]; then
      "$CAPS_SIGNAL" needs-input
    fi
    ;;
esac

exit 0
