#!/bin/sh
# crucible-launch.sh -- start Crucible's rails and serve the door, with one command.
#
# Ships in the release tarball at its root. A stranger unpacks the tarball, points their MCP host
# at this script, and the door comes up already connected to the tower:
#
#     claude mcp add crucible -- /absolute/path/to/crucible-v0.2.1/crucible-launch.sh
#
# WHY IT IS NEEDED. The door resolves config/rail.conf, tower/base.bundle, config/reef-relay.conf
# and state/ RELATIVE TO THE DIRECTORY IT IS STARTED IN. Started anywhere else it refuses every
# forge with tower_base_missing. And the three rails it needs (prover, vacuity, and the reef relay
# that reaches thereef.ink) are separate processes nobody was starting. This launcher starts them
# from the right directory and STOPS THEM AFTERWARDS -- nothing is left listening once the door exits.
#
# Ruled 2026-09-23 (Tony): a fresh install must connect to the one tower automatically, so this
# launcher starts the REEF RELAY alongside prover and vacuity -- the earlier launcher started only
# two of the three, which is why a fresh install never reached the tower.
#
# NOT AN INSTALLER. It installs nothing and downloads nothing, and it touches nothing OUTSIDE this
# directory. The one thing it writes is the two LOCAL-rail configs (config/prover-service.conf,
# config/vacuity-service.conf) when they are absent -- their machine-specific paths (where THIS box's
# gnatprove lives, where the shipped battery lives, where each keeps scratch) cannot be baked into a
# shipped tarball, so the launcher fills them in from what it finds here, inside this dir only. A
# config already present is left untouched. If the install itself is not ready it says so and refuses.
#
# PRIVACY. With the reef relay up, the start of every forge asks your tower (https://thereef.ink/rail)
# what catalogue is current, and may fetch one public, signed catalogue file. It sends NO unit of
# yours -- no specification, no code, no proof. Delete the "reef" line in config/rail.conf (or do not
# run this launcher) to forge fully offline; everything else works unchanged.
#
# Usage:  crucible-launch.sh            # start the rails, serve the door on stdio
#         crucible-launch.sh --check    # start the rails, report which are up, stop, exit
# Exit:   the door's exit code | 1 install not ready | 2 no factory here

set -u

# The install directory is this script's own directory.
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT" || { echo "cannot enter $ROOT" >&2; exit 2; }

CONF="$ROOT/config/rail.conf"

DOOR="$ROOT/bin/crucible-agpl"
[ -x "$DOOR" ] || DOOR="$ROOT/bin/crucible-commercial"

if [ ! -x "$DOOR" ]; then
  echo "no crucible door in $ROOT/bin" >&2
  exit 2
fi

# Refuse rather than repair: a missing base or config is a packaging defect, not something to paper
# over here (that would hide exactly the fault that shipped a broken tarball).
not_ready=0
[ -f "$ROOT/tower/base.bundle" ] || { echo "this install is not ready: missing tower/base.bundle" >&2; not_ready=1; }
[ -f "$CONF" ]                   || { echo "this install is not ready: missing config/rail.conf"  >&2; not_ready=1; }
[ "$not_ready" -eq 0 ] || exit 1

# rail_port RAIL -> the port of the first config line naming that rail, or empty.
rail_port() {
  grep "\"rail\":\"$1\"" "$CONF" 2>/dev/null | head -n1 \
    | sed -n 's/.*"port":"\([0-9][0-9]*\)".*/\1/p'
}

# port_up PORT -> 0 if something already listens on 127.0.0.1:PORT. nc is used when present; without
# it we assume the port is free (a second bind attempt fails and that rail exits, leaving the first).
port_up() {
  if command -v nc >/dev/null 2>&1; then nc -z 127.0.0.1 "$1" >/dev/null 2>&1; return $?; fi
  return 1
}

# ---- local-rail configuration (install-time, written HERE, only inside this dir) -----------------
# The prover and vacuity rails need machine-specific paths that a shipped tarball cannot carry: where
# THIS box's gnatprove is, where the shipped battery is, and where each keeps scratch. When their
# config is absent, the launcher writes it from what it finds on this machine. Nothing outside this
# install directory is written; a config already present (e.g. from an installer) is left untouched.
STATE="$ROOT/state"

# find_gnatprove -> absolute path to a gnatprove on this box, or empty.
find_gnatprove() {
  if command -v gnatprove >/dev/null 2>&1; then command -v gnatprove; return; fi
  for g in "$HOME"/.local/share/alire/releases/gnatprove_*/bin/gnatprove "$HOME"/.alire/bin/gnatprove; do
    [ -x "$g" ] && { echo "$g"; return; }
  done
  echo ""
}

GNATPROVE="$(find_gnatprove)"
# Put the discovered SPARK toolchain on PATH for the rails we start: the prover is handed an absolute
# gnatprove, but the vacuity battery shells out to gnatprove/gprbuild BY NAME.
if [ -n "$GNATPROVE" ]; then PATH="$(dirname "$GNATPROVE"):$PATH"; export PATH; fi

# ensure_prover_conf -- write config/prover-service.conf if absent and a gnatprove was found.
ensure_prover_conf() {
  pc="$ROOT/config/prover-service.conf"
  [ -f "$pc" ] && return 0
  pp="$(rail_port prover)"; [ -n "$pp" ] || pp="8471"
  if [ -z "$GNATPROVE" ]; then
    echo "prover: no gnatprove found on this box; local proving is off." >&2
    echo "        install a GNAT/SPARK toolchain (see INSTALL.md) to enable the prover rail." >&2
    return 1
  fi
  printf '{"port":"%s","staging_root":"%s","gnatprove":"%s","timeout_seconds":"600"}\n' \
    "$pp" "$STATE/prover-staging" "$GNATPROVE" > "$pc" || { echo "prover: could not write $pc" >&2; return 1; }
  echo "prover: wrote config/prover-service.conf (gnatprove=$GNATPROVE)" >&2
}

# ensure_vacuity_conf -- write config/vacuity-service.conf if absent and the shipped battery is here.
ensure_vacuity_conf() {
  vc="$ROOT/config/vacuity-service.conf"
  [ -f "$vc" ] && return 0
  vp="$(rail_port vacuity)"; [ -n "$vp" ] || vp="8472"
  bat="$ROOT/bin/check-cores-mcp"
  if [ ! -x "$bat" ]; then
    echo "vacuity: no bin/check-cores-mcp shipped here; the vacuity rail is off." >&2
    return 1
  fi
  printf '{"port":"%s","staging_root":"%s","battery":"%s","timeout_seconds":"600"}\n' \
    "$vp" "$STATE/vacuity-staging" "$bat" > "$vc" || { echo "vacuity: could not write $vc" >&2; return 1; }
  echo "vacuity: wrote config/vacuity-service.conf (battery=$bat)" >&2
}

mkdir -p "$STATE" 2>/dev/null || true
ensure_prover_conf  || true
ensure_vacuity_conf || true

PIDS=""
cleanup() {
  for p in $PIDS; do kill "$p" 2>/dev/null || true; done
}
trap cleanup EXIT INT TERM

# start_rail NAME EXE -- start a declared rail whose binary we ship and that is not already up.
# Rails must never touch the MCP stdio channel: stdin from /dev/null, all output to stderr, so the
# door's stdout stays clean for the protocol.
start_rail() {
  name="$1"; exe="$ROOT/bin/$2"
  port="$(rail_port "$name")"
  if [ -z "$port" ]; then echo "no $name rail declared; not starting one" >&2; return; fi
  if port_up "$port"; then echo "$name rail already up on $port; leaving it alone" >&2; return; fi
  if [ ! -x "$exe" ]; then echo "$name rail declared on $port but no bin/$2 shipped here" >&2; return; fi
  if [ "$name" = "reef" ] && [ ! -f "$ROOT/config/reef-relay.conf" ]; then
    echo "reef rail declared on $port but config/reef-relay.conf is missing; not starting the relay" >&2
    return
  fi
  if [ "$name" = "prover" ] && [ ! -f "$ROOT/config/prover-service.conf" ]; then
    echo "prover rail declared on $port but no config/prover-service.conf (no toolchain found); not starting" >&2
    return
  fi
  if [ "$name" = "vacuity" ] && [ ! -f "$ROOT/config/vacuity-service.conf" ]; then
    echo "vacuity rail declared on $port but no config/vacuity-service.conf (no battery here); not starting" >&2
    return
  fi
  echo "starting $name on $port" >&2
  "$exe" </dev/null >&2 2>&1 &
  PIDS="$PIDS $!"
}

start_rail prover  prover_service_main
start_rail vacuity vacuity_service_main
start_rail reef    reef_relay_main

# The model rail is the user's own -- Crucible ships no model -- so it is never started here.
mp="$(rail_port model)"; [ -n "$mp" ] || mp="$(rail_port ollama)"
if [ -n "$mp" ] && ! port_up "$mp"; then
  echo "model rail declared on $mp but nothing is answering there." >&2
  echo "Crucible ships no model. Point the model line in config/rail.conf at the endpoint you run." >&2
fi

if [ "${1:-}" = "--check" ]; then
  sleep 1
  for r in prover vacuity reef; do
    p="$(rail_port "$r")"; [ -n "$p" ] || continue
    if port_up "$p"; then echo "  $r $p up" >&2; else echo "  $r $p DOWN" >&2; fi
  done
  exit 0
fi

# Serve the door on stdio from the install directory. NOT exec, so the trap runs and stops the rails
# when the door exits.
"$DOOR"
code=$?
exit "$code"
