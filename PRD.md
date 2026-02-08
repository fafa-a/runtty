# Feature: HTTP API for Folder Operations (Port 3210)

## Scope

**In:**
- HTTP server on fixed port 3210
- POST /api/folder/pick endpoint (opens zenity + scans + returns JSON)
- Keep WebUI for launching Firefox at startup
- Port 3210 used for both HTTP API and serving the UI

**Out:**
- WebSocket (not needed yet)
- Dynamic port allocation
- CORS handling (localhost only)

## DoD
- [ ] Backend listens on port 3210
- [ ] POST /api/folder/pick works via HTTP
- [ ] Frontend fetch() succeeds
- [ ] Firefox opens automatically (WebUI)
- [ ] JSON response format correct

## Tasks

- [ ] T1 — Set fixed port 3210 in main.zig
- [ ] T2 — Create HTTP request handler in api.zig
- [ ] T3 — Implement folder pick endpoint with zenity
- [ ] T4 — Serve UI from same port 3210
- [ ] T5 — Test end-to-end
