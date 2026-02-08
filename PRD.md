# Feature: Real Process Spawn with std.process.Child

## Scope

**In:**
- Spawn actual process with std.process.Child
- Capture PID for stop capability
- Stream stdout/stderr to UI via webui.send()
- Handle process exit (success/error)
- Store running processes in HashMap

**Out:**
- Process restart on crash
- Multiple parallel processes per project
- Environment variables injection
- Working directory change after start

## DoD
- [ ] Process actually starts when clicking Play
- [ ] Logs appear in UI in real-time
- [ ] Stop button kills the process
- [ ] UI shows "Running" only while process is alive
- [ ] Process exit updates UI to "Stopped"

## Tasks

- [ ] T1 — Modify ProjectInfo to store Child process
- [ ] T2 — Spawn process in startProjectHandler with pipes
- [ ] T3 — Create thread to read stdout/stderr and send to UI
- [ ] T4 — Implement stopProjectHandler with process.kill()
- [ ] T5 — Monitor process exit and update UI status
- [ ] T6 — Test with real project (npm run dev, cargo run, etc.)
