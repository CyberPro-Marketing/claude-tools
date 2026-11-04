#!/usr/bin/env bash
# Hand-picked skills from two large public collections, chosen for Adam's work
# rather than installed whole (177 and 818 skills would crowd every session's
# skill list). Each collection is pinned to a commit and fetched sparsely, so
# only the chosen folders download (~1 s).
#
# From K-Dense-AI/scientific-agent-skills (MIT):
#   market-research-reports, timesfm-forecasting, markitdown
# From mukul975/Anthropic-Cybersecurity-Skills (Apache-2.0; an independent
# project, not made by Anthropic): defensive checks for Adam's own sites,
# domains and code.
# A short local rule is appended to each security skill, and one to
# timesfm-forecasting about the licence of its model weights.
set -euo pipefail

SKILLS="$HOME/.claude/skills"
log() { printf '[skill-picks-setup] %s\n' "$*"; }

fetch() { # fetch <repo> <commit> <stamp-name> <folder>...
  local repo=$1 commit=$2 name=$3; shift 3
  local stamp="$SKILLS/.$name.commit"
  [ "$(cat "$stamp" 2>/dev/null)" = "$commit:$*" ] && return 1
  local tmp; tmp=$(mktemp -d)
  # Explicit failure checks: set -e does not apply inside a function called
  # from an `if`, and a failed fetch must never be stamped as installed.
  { git -C "$tmp" init -q \
    && git -C "$tmp" remote add origin "https://github.com/$repo.git" \
    && git -C "$tmp" sparse-checkout set --no-cone $(printf '/%s/ ' "$@") \
    && git -C "$tmp" fetch -q --depth 1 --filter=blob:none origin "$commit" \
    && git -C "$tmp" checkout -q FETCH_HEAD; } \
    || { log "could not fetch $repo@${commit:0:7}"; rm -rf "$tmp"; exit 1; }
  for d in "$@"; do
    [ -f "$tmp/$d/SKILL.md" ] || { log "missing $d in $repo"; rm -rf "$tmp"; exit 1; }
  done
  mkdir -p "$SKILLS"
  for d in "$@"; do
    rm -rf "$SKILLS/$(basename "$d")"
    cp -r "$tmp/$d" "$SKILLS/"
  done
  echo "$commit:$*" > "$stamp"
  rm -rf "$tmp"
  return 0
}

SCI=(skills/market-research-reports skills/timesfm-forecasting skills/markitdown)
if fetch K-Dense-AI/scientific-agent-skills a25cf9ec00e2745d03f8704acf6f6919694ccd9a scientific "${SCI[@]}"; then
  cat >> "$SKILLS/timesfm-forecasting/SKILL.md" <<'MD'

## Adam's rule (added by CyberPro-Marketing/claude-tools)

Use the **TimesFM 2.5** model (Apache-2.0 weights) for Adam's businesses. The
TimesFM 3.0 weights are licensed for non-commercial, non-production use only.
The first run installs PyTorch and downloads the model; say so before starting.
MD
fi
log "scientific picks ready (${#SCI[@]})"

SEC=(
  skills/performing-security-headers-audit
  skills/performing-ssl-tls-security-assessment
  skills/implementing-dmarc-dkim-spf-email-security
  skills/implementing-secret-scanning-with-gitleaks
  skills/detecting-malicious-npm-packages
  skills/testing-api-security-with-owasp-top-10
  skills/performing-web-application-vulnerability-triage
  skills/analyzing-typosquatting-domains-with-dnstwist
)
if fetch mukul975/Anthropic-Cybersecurity-Skills 54a798831d2266a3ca61ce68a7acb80b81160d57 security "${SEC[@]}"; then
  for d in "${SEC[@]}"; do
    cat >> "$SKILLS/$(basename "$d")/SKILL.md" <<'MD'

## Adam's rule (added by CyberPro-Marketing/claude-tools)

Use this only on systems Adam owns or runs: his websites, domains, email
domains, repositories and services. Never point it at anyone else's site or
system. Prefer passive checks (reading headers, certificates, DNS records, code)
and ask Adam before any active test against a live site.
MD
  done
fi
log "security picks ready (${#SEC[@]})"
