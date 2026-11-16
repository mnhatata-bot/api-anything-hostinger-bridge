# API Anything — Hostinger isolated MCP bridge

This repository holds deployment configuration and setup instructions **only**, without credentials. It does not contain the upstream API Anything code.

## Verified deployment baseline (2026-11-16)
- Hostinger VPS: `srv2150700`, separate Docker Compose application `api-anything-bridge`.
- User-provided Docker Manager screenshot: the application is Running.
- User-provided container terminal evidence: `GET http://127.0.0.1:18765/health` returned `HTTP 200` and `ok`.
- HTTP listener: inside container `0.0.0.0:18765`; mapped on VPS host only to `127.0.0.1:18765`.
- Supergateway requires a generated bearer key stored privately in its Docker volume. Do not print it, add it to GitHub, or share it in chat.
- The existing `ci-twenty-isolated` stack has not been changed by this integration.

## Optional: create private ngrok tunnel from host Web console
Run from **Hostinger VPS > Web console (host shell)**, not the API Anything container terminal:

```bash
curl -fsSL 'https://raw.githubusercontent.com/mnhatata-bot/api-anything-hostinger-bridge/b220252ac3164699e18d335ffb5d857890805b97/install-ngrok.sh' -o /tmp/api-anything-ngrok.sh && bash /tmp/api-anything-ngrok.sh
```

This prompts privately for a ngrok **authtoken** (not an API key), then confirms the existing MCP gateway health and loopback-only Docker port. It creates only a separate, restricted `api-anything-ngrok` container. The pinned ngrok agent is `3.39.11-debian`. It refuses to overwrite existing ngrok resources.

If successful, the script prints a `https://...ngrok-free.dev/mcp` endpoint. The endpoint still requires the MCP gateway's bearer credential. A `401 Unauthorized` without authorization is expected.

## Pending: ChatGPT plugin authentication
The existing private API Anything ChatGPT plugin v0.2.0 is a **skill-only** wrapper; it is not yet connected to this MCP service. Official ChatGPT plugin portal connection does **not** accept arbitrary static API keys in its setup form. A properly authenticated OAuth 2.1 MCP integration (or a separately verified supported authorization mechanism) is needed before connecting it. Do **not** remove bearer authentication or mark the plugin connected because ngrok TLS works.

## Security rules
- Keep the host loopback-only port, API bearer key, ngrok authtoken, and user data private.
- Do not modify, restart, or attach to Corporate Interface, Twenty CRM, SoundCode or other applications.
- Never enable `--allow-writes` or upstream catalog publishing without explicit authorization.
- ngrok free limits apply. HTTPS tunnel success is not application certification.
