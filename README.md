# RunTTY

A terminal emulator with a modern web-based UI.

## Prerequisites

- **Zig 0.15.2** (stable) - [Download](https://ziglang.org/download/)
- **Bun** (latest stable) - [Install](https://bun.sh/)

⚠️ **Note on zig-webui**: We use the `main` branch which supports Zig 0.15.x. The stable tag (2.5.0-beta.2) only supports Zig 0.13.0.

## Project Structure

```
runtty/
├── apps/
│   ├── host-zig/     # Zig 0.15.2 + zig-webui (main branch)
│   └── ui/           # SolidJS + TypeScript + Vite + Bun + restty
├── docs/
│   ├── ARCHITECTURE.md
│   └── API.md
└── README.md
```

## Quick Start

### UI (SolidJS + Vite)

```bash
cd apps/ui
bun install
bun run dev
```

### Host (Zig 0.15.2)

```bash
cd apps/host-zig
zig build
# Or to build and run:
zig build run
```

## Technologies

| Component | Version | Status |
|-----------|---------|--------|
| Zig | 0.15.2 | Stable |
| zig-webui | main branch | Stable for Zig 0.15 |
| Bun | Latest | Stable |
| SolidJS | 1.9.x | Stable |
| Vite | 7.x | Stable |
| restty | 0.1.14 | Stable |

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [API Reference](docs/API.md)
