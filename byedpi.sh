#!/usr/bin/env bash
set -euo pipefail

CMD="${1:-start}"
PROXY_PORT=1080

start() {
  systemctl --user start byedpi.service 2>/dev/null || true
  systemctl --user enable byedpi.service >/dev/null 2>&1 || true
  gsettings set org.gnome.system.proxy mode 'manual' 2>/dev/null || true
  gsettings set org.gnome.system.proxy.socks host '127.0.0.1' 2>/dev/null || true
  gsettings set org.gnome.system.proxy.socks port "$PROXY_PORT" 2>/dev/null || true
  echo "[OK] ByeDPI 프록시 시작됨 (socks5://127.0.0.1:$PROXY_PORT)"
}

stop() {
  systemctl --user stop byedpi.service 2>/dev/null || true
  gsettings set org.gnome.system.proxy mode 'none' 2>/dev/null || true
  echo "[OK] ByeDPI 프록시 중지됨"
}

status() {
  if systemctl --user is-active byedpi.service >/dev/null 2>&1; then
    local code
    code=$(curl -sI --max-time 8 --socks5-hostname 127.0.0.1:$PROXY_PORT https://www.pornhub.com -o /dev/null -w "%{http_code}" 2>/dev/null || echo "000")
    echo "상태: 실행 중 (차단사이트 HTTP $code)"
  else
    echo "상태: 중지됨"
  fi
}

heat() {
  echo "== CPU 온도 =="
  sensors 2>/dev/null | grep -iE 'package|tctl|temp1' | head -5 || echo "sensors 없음"
  echo "== 부하 TOP 5 =="
  ps -eo pcpu,pmem,comm --sort=-pcpu | head -6
}

case "$CMD" in
  start) start ;;
  stop)  stop ;;
  status) status ;;
  heat)  heat ;;
  *)
    echo "사용법: byedpi.sh {start|stop|status|heat}"
    exit 1
    ;;
esac
