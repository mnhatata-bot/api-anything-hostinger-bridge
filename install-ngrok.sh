#!/usr/bin/env bash
# API Anything only: separate ngrok tunnel, no changes to existing Compose stacks.
set -Eeuo pipefail
umask 077
if [ "$EUID" -ne 0 ]; then
  echo "Run in Hostinger VPS Web console as root (HOST, not container terminal)." >&2
  exit 1
fi
for cmd in docker curl python3; do
  command -v "$cmd" >/dev/null || { echo "Missing: $cmd" >&2; exit 1; }
done
app_id="$(docker ps --filter name=api-anything-bridge --format '{{.ID}}')"
if [ -z "$app_id" ] || [ "$(printf '%s\n' "$app_id" | wc -l)" -ne 1 ]; then
  echo 'Expected one running API Anything container; refusing to change anything.' >&2
  exit 1
fi
ports="$(docker inspect --format '{{json .NetworkSettings.Ports}}' "$app_id")"
printf '%s' "$ports" | python3 -c '
import json,sys
try:
 p=json.load(sys.stdin).get("18765/tcp",[])
 assert len(p)==1 and p[0]["HostIp"]=="127.0.0.1" and p[0]["HostPort"]=="18765"
except Exception:
 sys.exit("Unsafe 18765 binding: only 127.0.0.1:18765 is permitted.")
'
[ "$(curl -fsS --max-time 10 http://127.0.0.1:18765/health)" = ok ] || {
  echo 'API Anything health check failed; refusing tunnel.' >&2; exit 1;
}
if docker container inspect api-anything-ngrok >/dev/null 2>&1; then
  echo 'api-anything-ngrok already exists; no changes made.' >&2; exit 1
fi
echo 'Private API Anything gateway checked. Enter ngrok authtoken below.'
echo 'Find it at https://dashboard.ngrok.com/get-started/your-authtoken'
IFS= read -rs -p 'ngrok AUTHTOKEN (hidden): ' token
echo
if [[ ! "$token" =~ ^[A-Za-z0-9._-]{15,250}$ ]]; then
  echo 'Token format appears invalid; no changes made.' >&2
  unset token
  exit 1
fi
dir=/opt/api-anything-ngrok
config=$dir/ngrok.yml
install -d -m 0700 "$dir"
if [ -e "$config" ]; then
  echo 'Existing ngrok config found; refusing overwrite.' >&2
  unset token
  exit 1
fi
temp="$(mktemp "$dir/config.tmp.XXXXXXXX")"
trap 'rm -f "$temp"; unset token' EXIT
printf 'version: 3\nagent:\n  authtoken: %s\n' "$token" > "$temp"
unset token
chmod 0600 "$temp"
docker pull ngrok/ngrok:latest >/dev/null
docker run --rm --network none --mount "type=bind,source=$temp,target=/etc/ngrok.yml,readonly" ngrok/ngrok:latest config check --config /etc/ngrok.yml >/dev/null
mv "$temp" "$config"
trap - EXIT
docker run -d --name api-anything-ngrok --restart unless-stopped --network host --mount "type=bind,source=$config,target=/etc/ngrok.yml,readonly" ngrok/ngrok:latest http 18765 --url https:// --config /etc/ngrok.yml >/dev/null
echo 'Started a separate tunnel container without changing the API Anything container.'
url=''
for i in $(seq 1 15); do
  url="$(curl -sS --max-time 3 http://127.0.0.1:4040/api/tunnels 2>/dev/null | python3 -c '
import json,sys
try:
 urls=[t.get("public_url","") for t in json.load(sys.stdin).get("tunnels",[])]
 print(next((u for u in urls if u.startswith("https://")),""))
except Exception: print("")
' || true)"
  [ -n "$url" ] && break
  sleep 2
done
if [ -n "$url" ]; then
  echo "NGROK URL: $url"
  echo "MCP URL: $url/mcp"
else
  echo 'No tunnel URL yet; inspect: docker logs --tail 30 api-anything-ngrok'
  exit 2
fi
echo 'DO NOT share your ngrok authtoken or API Anything gateway bearer key.'
