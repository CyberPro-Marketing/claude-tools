#!/usr/bin/env bash
# Installs Ghidra for REA, in one session, when a task needs it. Not run by
# setup.sh: it is ~840 MB unpacked, and most sessions never decompile anything.
#
# Source: Kali Linux's package archive, which carries the exact Ghidra 12.1.x
# REA supports. GitHub release downloads are blocked in these containers (only
# git clones get through), so the official zip is not reachable. The .deb is
# checked against the SHA-256 in Kali's package index before it is unpacked,
# and only its files are used: nothing is installed through apt, so Kali's
# dependency list (which names Java 25) never applies. Ghidra 12.1 needs Java
# 21 or newer, which these containers already have.
set -euo pipefail

DEST=/opt/ghidra
MIRROR=https://kali.download/kali
WANT='^12\.1\.'
log() { printf '[ghidra-setup] %s\n' "$*"; }
fail() { printf '[ghidra-setup] FAILED: %s\n' "$*" >&2; exit 1; }

if [ -x "$DEST/support/analyzeHeadless" ] && grep -qE "application.version=12\.1\." "$DEST/Ghidra/application.properties" 2>/dev/null; then
  ln -sf "$DEST/ghidraRun" /usr/local/bin/ghidraRun
  log "already installed: $(grep application.version "$DEST/Ghidra/application.properties")"
  exit 0
fi

java_major=$(java -XshowSettings:properties -version 2>&1 | awk -F'= ' '/java.specification.version/{print $2}' | cut -d. -f1)
if [ -z "$java_major" ] || [ "$java_major" -lt 21 ]; then
  log "Java 21+ not found; installing openjdk-21-jdk-headless"
  apt-get install -y -qq openjdk-21-jdk-headless >/dev/null || fail "could not install Java 21"
fi

arch=$(dpkg --print-architecture)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
curl -fsSL -o "$tmp/Packages.gz" "$MIRROR/dists/kali-rolling/main/binary-$arch/Packages.gz" \
  || fail "could not read Kali's package index"
entry=$(zcat "$tmp/Packages.gz" | awk -v RS= '/^Package: ghidra\n/')
version=$(sed -n 's/^Version: //p' <<<"$entry")
file=$(sed -n 's/^Filename: //p' <<<"$entry")
sha=$(sed -n 's/^SHA256: //p' <<<"$entry")
[ -n "$file" ] || fail "Kali's index has no ghidra package for $arch"
grep -qE "$WANT" <<<"$version" \
  || fail "Kali now ships Ghidra $version; REA supports 12.1.x. Update WANT here after checking REA's docs."

log "downloading Ghidra $version (~500 MB)"
curl -fsSL -o "$tmp/ghidra.deb" "$MIRROR/$file" || fail "download failed"
echo "$sha  $tmp/ghidra.deb" | sha256sum -c --quiet || fail "checksum mismatch; not installing"

dpkg -x "$tmp/ghidra.deb" "$tmp/x"
rm -rf "$DEST"
mv "$tmp/x/usr/share/ghidra" "$DEST"
ln -sf "$DEST/ghidraRun" /usr/local/bin/ghidraRun
log "installed Ghidra $version at $DEST"
