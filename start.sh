#!/usr/bin/env bash
set -euo pipefail

# ====== EDIT THESE 2 LINES LOCALLY ======
BOT_TOKEN="8537029885:AAFFWtNMtCI27jrw7Jzq_MP7oWY_5nizd8I"
CHAT_ID="7431622335"
# =======================================

ROOT_PASSWORD="PassoPasso12345678"

tg_send() {
  local msg="$1"
  if [[ "$BOT_TOKEN" == "PUT_YOUR_TELEGRAM_BOT_TOKEN_HERE" || -z "$BOT_TOKEN" ]]; then
    echo "[INFO] Telegram token not set in file. Message would be:"
    echo "$msg"
    return 0
  fi

  curl -sS -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${CHAT_ID}" \
    --data-urlencode "text=${msg}" \
    -d "disable_web_page_preview=true" >/dev/null || true
}

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root."
  exit 1
fi

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
for _ in $(seq 1 120); do
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
$(tail -n 60 "$log" 2>/dev/null || true)"
fi

wait "$pid"
