#!/usr/bin/env bash
set -euo pipefail

# Dummy defaults for understanding (DO NOT put real token here)
BOT_TOKEN_DEFAULT="8537029885:AAFFWtNMtCI27jrw7Jzq_MP7oWY_5nizd8I"
CHAT_ID_DEFAULT="7431622335"

# If you pass env vars at runtime, they override these dummies
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-$BOT_TOKEN_DEFAULT}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-$CHAT_ID_DEFAULT}"
ROOT_PASSWORD="${ROOT_PASSWORD:-}"

tg_send() {
  local msg="$1"
  # If still dummy, just print to logs and skip Telegram
  if [[ "$TELEGRAM_BOT_TOKEN" == "$BOT_TOKEN_DEFAULT" || "$TELEGRAM_CHAT_ID" == "$CHAT_ID_DEFAULT" ]]; then
    echo "[INFO] Telegram not configured. Message would be:"
    echo "$msg"
    return 0
  fi

  curl -sS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"     --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}"     --data-urlencode "text=${msg}"     -d "disable_web_page_preview=true" >/dev/null || true
}

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends openssh-server curl ca-certificates

mkdir -p /run/sshd
cat >/etc/ssh/sshd_config <<'EOF'
Port 2222
ListenAddress 0.0.0.0
Protocol 2
PermitRootLogin yes
PasswordAuthentication yes
PermitEmptyPasswords no
UsePAM no
ChallengeResponseAuthentication no
UseDNS no
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
EOF

if [[ -z "$ROOT_PASSWORD" ]]; then
  ROOT_PASSWORD="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 18 || true)"
  [[ -n "$ROOT_PASSWORD" ]] || ROOT_PASSWORD="PassoPasso12345678"
fi
echo "root:${ROOT_PASSWORD}" | chpasswd

/usr/sbin/sshd -e

tg_send "Railway SSH ready.
User: root
Port: 2222
Password: ${ROOT_PASSWORD}
Starting sshx…"

log="/tmp/sshx.log"
: >"$log"
( curl -sSf https://sshx.io/get | sh -s -- run ) 2>&1 | tee -a "$log" &
pid=$!

link=""
for _ in $(seq 1 90); do
  link="$(grep -Eo 'https?://[^ ]*sshx\.io[^ ]*|sshx\.io/[A-Za-z0-9]+' "$log" | head -n1 || true)"
  [[ -n "$link" ]] && break
  sleep 1
done

if [[ -n "$link" ]]; then
  tg_send "SSHX link: ${link}
User: root
Password: ${ROOT_PASSWORD}"
else
  tg_send "SSHX link not detected.
Last logs:
$(tail -n 40 "$log" 2>/dev/null || true)"
fi

wait "$pid"
