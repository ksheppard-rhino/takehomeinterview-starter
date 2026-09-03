#!/usr/bin/env bash
# Environment check. Run from the repo root and send us the output.
# It verifies your machine can run the starter: it builds the images, starts the
# stack, checks the API and frontend answer, then stops the stack again. The
# images stay cached so you are not waiting on downloads later.
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
echo "Stack (build, start, check, stop -- this is the slow part)"
STACK_LOG=/tmp/preflight-stack.log
if [ "$FAIL" -ne 0 ]; then
  warn "skipped -- fix the failures above first"
elif [ ! -f docker-compose.yml ]; then
  fail "docker-compose.yml not found -- run this script from the repo root"
elif ! docker compose up --build -d >"$STACK_LOG" 2>&1; then
  fail "'docker compose up --build -d' failed -- see $STACK_LOG"
  tail -20 "$STACK_LOG"
else
  pass "images built and containers started"

  API_OK=0
  for _ in $(seq 1 60); do
    if curl -fsS http://127.0.0.1:8000/api/health >/dev/null 2>&1; then API_OK=1; break; fi
    sleep 2
  done
  if [ "$API_OK" -eq 1 ]; then
    pass "API answered on http://127.0.0.1:8000/api/health"
  else
    fail "API did not answer within 120s"
  fi

  WEB_OK=0
  for _ in $(seq 1 30); do
    if curl -fsS -o /dev/null http://127.0.0.1:3000/ >/dev/null 2>&1; then WEB_OK=1; break; fi
    sleep 2
  done
  if [ "$WEB_OK" -eq 1 ]; then
    pass "frontend answered on http://127.0.0.1:3000"
  else
    fail "frontend did not answer within 60s"
  fi

  if [ "$API_OK" -ne 1 ] || [ "$WEB_OK" -ne 1 ]; then
    docker compose logs --no-color --tail 40 >>"$STACK_LOG" 2>&1
    echo "  --- last 40 log lines (full log: $STACK_LOG) ---"
    tail -40 "$STACK_LOG"
  fi

  if docker compose down >>"$STACK_LOG" 2>&1; then
    pass "stack stopped (database volume kept)"
  else
    fail "'docker compose down' failed -- see $STACK_LOG"
  fi
fi

echo ""
echo "Screen sharing (Zoom or Chrome Remote Desktop -- either one is enough)"
ZOOM=0
CRD=0
case "$(uname -s)" in
  Darwin)
    for P in /Applications/zoom.us.app "$HOME/Applications/zoom.us.app"; do
      [ -d "$P" ] && ZOOM=1
    done
    for P in "/Applications/Chrome Remote Desktop Host Uninstaller.app" \
             /Library/PrivilegedHelperTools/org.chromium.chromoting.me2me_host.app \
             /Library/LaunchAgents/org.chromium.chromoting.plist; do
      [ -e "$P" ] && CRD=1
    done
    ;;
  *)
    command -v zoom >/dev/null 2>&1 && ZOOM=1
    [ -d /opt/zoom ] && ZOOM=1
    [ -d /opt/google/chrome-remote-desktop ] && CRD=1
    # WSL: the apps live on the Windows side.
    for P in /mnt/c/Users/*/AppData/Roaming/Zoom/bin/Zoom.exe "/mnt/c/Program Files/Zoom/bin/Zoom.exe"; do
      [ -e "$P" ] && ZOOM=1
    done
    for P in "/mnt/c/Program Files (x86)/Google/Chrome Remote Desktop" \
             "/mnt/c/Program Files/Google/Chrome Remote Desktop"; do
      [ -e "$P" ] && CRD=1
    done
    ;;
esac
[ "$ZOOM" -eq 1 ] && pass "Zoom found"
[ "$CRD" -eq 1 ] && pass "Chrome Remote Desktop found"
if [ "$ZOOM" -eq 0 ] && [ "$CRD" -eq 0 ]; then
  fail "neither Zoom nor Chrome Remote Desktop found -- install one of them"
  warn "if you do have one installed somewhere unusual, tell us and ignore this"
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
