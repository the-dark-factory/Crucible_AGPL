#!/bin/sh
# check-version.sh -- fail the build/package if the reported version disagrees with the crate
# version, or with the release tag when one is given.
#
# WHY THIS EXISTS. The version the door reports (serverInfo.version) is a hand-typed string in
# src/reply_text_pkg.ads. It has been typed wrong before: v0.1.1 reported 0.1.0, v0.2.0 shipped
# reporting 0.1.0, and v0.2.1 nearly did too (crucible.gpr line 13 records the first). This guard
# closes that class of bug for good, at BUILD/PACKAGE time -- not at runtime, where a wrong version
# would already have shipped.
#
# WHAT IT CHECKS.
#   1. src/reply_text_pkg.ads  Server_Version_Word  == alire.toml  version
#   2. if a tag/expected version is given (arg 1, or $CRUCIBLE_EXPECTED_VERSION), both == that.
# A leading "v" on the tag is tolerated (v0.2.1 == 0.2.1).
#
# USAGE (wire into the build and the packaging step, before gprbuild and before tar):
#   scripts/check-version.sh              # source files must agree with each other
#   scripts/check-version.sh v0.2.1       # ...and with the tag you are about to cut
#   CRUCIBLE_EXPECTED_VERSION=0.2.1 scripts/check-version.sh
# EXIT: 0 all agree | 1 a mismatch (message on stderr) | 2 could not read a version

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ADS="$ROOT/src/reply_text_pkg.ads"
TOML="$ROOT/alire.toml"

expected="${1:-${CRUCIBLE_EXPECTED_VERSION:-}}"
expected="${expected#v}"   # tolerate a leading v

reported="$(sed -n 's/.*Server_Version_Word[[:space:]]*:[[:space:]]*constant String[[:space:]]*:=[[:space:]]*Q[[:space:]]*("\([^"]*\)").*/\1/p' "$ADS" 2>/dev/null | head -n1)"
crate="$(sed -n 's/^[[:space:]]*version[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$TOML" 2>/dev/null | head -n1)"

if [ -z "$reported" ]; then echo "check-version: cannot read Server_Version_Word from $ADS" >&2; exit 2; fi
if [ -z "$crate" ];    then echo "check-version: cannot read version from $TOML" >&2; exit 2; fi

rc=0
if [ "$reported" != "$crate" ]; then
  echo "check-version: MISMATCH  reported(serverInfo.version)=$reported  crate(alire.toml)=$crate" >&2
  rc=1
fi
if [ -n "$expected" ]; then
  if [ "$reported" != "$expected" ]; then
    echo "check-version: MISMATCH  reported(serverInfo.version)=$reported  tag=$expected" >&2
    rc=1
  fi
  if [ "$crate" != "$expected" ]; then
    echo "check-version: MISMATCH  crate(alire.toml)=$crate  tag=$expected" >&2
    rc=1
  fi
fi

if [ "$rc" -eq 0 ]; then
  echo "check-version: OK  version=$reported${expected:+ (matches tag)}"
fi
exit "$rc"
