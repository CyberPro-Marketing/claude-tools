#!/usr/bin/env bash
# Entry point for a Claude Code cloud environment's setup script:
#
#   curl -fsSL https://raw.githubusercontent.com/CyberPro-Marketing/claude-tools/main/setup.sh | bash
#
# Runs every installer in tools/, in name order, whatever repo the session
# opened. One tool failing is logged and skipped; it never fails the setup
# script, because a broken video tool should not stop every session on every
# project from starting.
#
#   CLAUDE_TOOLS_SKIP="hyperframes musicgen"  skip whole tools or named parts
#   CLAUDE_TOOLS_REF=some-branch              install from a branch, not main
set -uo pipefail

REPO=CyberPro-Marketing/claude-tools
REF=${CLAUDE_TOOLS_REF:-main}
log() { printf '[claude-tools] %s\n' "$*"; }

# A shallow clone rather than a tarball: the cloud proxy refuses GitHub's
# archive downloads (codeload, /archive/) but lets a public clone through,
# measured 2026-10-06. Public, so no credential is needed either way.
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
if ! git clone -q --depth 1 --branch "$REF" "https://github.com/$REPO.git" "$dir"; then
  log "could not download $REPO@$REF; nothing installed"
  exit 0
fi

failed=()
for tool in "$dir"/tools/*.sh; do
  name=$(basename "$tool" .sh)
  if [[ " ${CLAUDE_TOOLS_SKIP:-} " == *" $name "* ]]; then
    log "$name skipped"
    continue
  fi
  log "$name: installing"
  start=$SECONDS
  if bash "$tool"; then
    log "$name: ready in $((SECONDS - start))s"
  else
    log "$name: FAILED (exit $?) after $((SECONDS - start))s"
    failed+=("$name")
  fi
done

if ((${#failed[@]})); then
  log "finished with failures: ${failed[*]}"
else
  log "all tools ready"
fi
exit 0
