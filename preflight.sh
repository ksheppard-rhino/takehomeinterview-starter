#!/usr/bin/env bash
# Environment check. Run from the repo root and send us the output.
# It verifies your machine can run the starter and pre-builds the Docker
# images so you are not waiting on downloads later.
set -uo pipefail

FAIL=0
pass() { printf '  \033[32mPASS\033[0m  %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; FAIL=1; }
warn() { printf '  \033[33mWARN\033[0m  %s\n' "$1"; }

echo ""
echo "Starter -- preflight"
echo "===================="
echo "  date      $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "  host      $(uname -srm)"
echo ""

echo "Tooling"
command -v git >/dev/null 2>&1 \
  && pass "git $(git --version | awk '{print $3}')" \
  || fail "git not found"

if command -v docker >/dev/null 2>&1; then
  pass "docker $(docker --version | awk '{print $3}' | tr -d ,)"
  if docker info >/dev/null 2>&1; then
    pass "docker daemon is running"
  else
    fail "docker is installed but the daemon is not running (start Docker Desktop)"
  fi
  docker compose version >/dev/null 2>&1 \
    && pass "docker compose $(docker compose version --short 2>/dev/null)" \
    || fail "'docker compose' (v2) not available"
else
  fail "docker not found"
fi

command -v curl >/dev/null 2>&1 && pass "curl present" || fail "curl not found"
command -v make >/dev/null 2>&1 && pass "make present" || fail "make not found"

# Only needed if you want to run the services outside Docker. Not required.
command -v node >/dev/null 2>&1 \
  && pass "node $(node --version) (optional)" \
  || warn "node not found (optional -- Docker provides it)"
command -v python3 >/dev/null 2>&1 \
  && pass "python3 $(python3 --version | awk '{print $2}') (optional)" \
  || warn "python3 not found (optional -- Docker provides it)"

echo ""
echo "Resources"
FREE_GB=$(df -Pg . 2>/dev/null | awk 'NR==2 {print $4}')
if [ -n "${FREE_GB:-}" ]; then
  if [ "$FREE_GB" -ge 10 ]; then pass "${FREE_GB}GB free disk"; else fail "${FREE_GB}GB free disk (need 10GB)"; fi
else
  warn "could not determine free disk space"
fi

for PORT in 3000 8000; do
  if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    warn "port $PORT is already in use -- free it or change docker-compose.yml"
  else
    pass "port $PORT is free"
  fi
done

echo ""
echo "Building images (this is the slow part -- doing it now saves later waits)"
if [ "$FAIL" -eq 0 ]; then
  if docker compose build >/tmp/preflight-build.log 2>&1; then
    pass "docker images built"
  else
    fail "docker build failed -- see /tmp/preflight-build.log"
    tail -20 /tmp/preflight-build.log
  fi
else
  warn "skipped -- fix the failures above first"
fi

echo ""
echo "Editor"
warn "Not checkable from here. Confirm your editor and any AI assistant"
warn "are installed, signed in, and can edit this repo."

echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "RESULT: READY -- paste this whole output back to us."
  exit 0
fi
echo "RESULT: NOT READY -- send us this output and we will help."
exit 1
