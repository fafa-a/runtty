# AGENTS.md - RunTTY Development Guide

## Project Overview

RunTTY is a terminal emulator with a modern web-based UI consisting of two components:
- **UI** (`apps/ui/`): SolidJS + TypeScript + Vite + Bun
- **Host** (`apps/host-zig/`): Zig 0.15.2 + zig-webui (main branch)

## Build Commands

### Development Workflow (Full Stack with WebUI)

**Important:** `window.webui` is only available when the UI is served by the Zig backend, not in Vite dev mode.

```bash
# 1. Build UI for production (generates dist/ folder)
cd apps/ui
bun run build

# 2. Run the Host (serves UI from dist/ with window.webui available)
cd ../host-zig
zig build run
```

### UI Development Only (without Zig backend)

```bash
cd apps/ui
bun run dev          # Start Vite dev server on localhost:5173
                     # Note: window.webui will be unavailable
                     # APIs will show "Not running in WebUI context"
```

### Production Build

```bash
cd apps/ui
bun run build        # TypeScript compile + Vite build → dist/

cd ../host-zig
zig build            # Build executable
zig build run        # Run and serve UI from dist/
```

### Host (Zig) Commands

```bash
cd apps/host-zig
zig build            # Build executable
zig build run        # Build and run (serves UI from ../ui/dist)
zig build test       # Run all tests
```

### Single Test (Zig)

```bash
# Run a specific test by name
zig test src/root.zig --test-filter "basic add functionality"

# Or run tests in a specific file
zig test src/main.zig
```

## Code Style Guidelines

### TypeScript/SolidJS (UI)

**Imports:**
- Group imports: 1) external libs, 2) internal aliases (`~/`), 3) relative
- Use `~/*` alias for all internal imports (configured in vite.config.ts)
- Example:
```typescript
import { createSignal } from "solid-js"
import { Button } from "~/components/ui/button"
import { cn } from "~/lib/utils"
```

**Formatting:**
- No semicolons (enforced by TypeScript)
- Double quotes for strings
- 2-space indentation
- No trailing commas

**Types:**
- Strict TypeScript enabled (`strict: true`)
- Always define interface props for components
- Use `JSX.Element` for children type
- Export component props types when reusable

**Naming:**
- PascalCase for components and interfaces (e.g., `Sidebar`, `ButtonProps`)
- camelCase for functions and variables (e.g., `createSignal`, `handleOpen`)
- `handle*` prefix for event handlers (e.g., `handlePlay`, `handleStop`)

**Components:**
- Use SolidJS primitives: `createSignal`, `splitProps`, `For`
- Destructure props with `splitProps` for variant extraction
- Style with Tailwind CSS utility classes
- Use `cn()` utility from `~/lib/utils` for class merging

**Error Handling:**
- TypeScript strict mode catches most errors at compile time
- Use optional chaining and nullish coalescing where appropriate

### Zig (Host)

**Imports:**
```zig
const std = @import("std");
const webui = @import("webui");
```

**Naming:**
- `snake_case` for functions and variables
- TitleCase for types
- Prefix errors with error type

**Error Handling:**
- Use `try` for propagating errors
- Use `defer` for cleanup
- Check errors with `std.testing.expect()` in tests

**Testing:**
```zig
test "descriptive test name" {
    try std.testing.expect(actual == expected);
}
```

## Technology Versions

| Component | Version |
|-----------|---------|
| Zig | 0.15.2 |
| Bun | Latest stable |
| SolidJS | 1.9.11 |
| TypeScript | 5.9.3 |
| Vite | 7.2.4 |
| TailwindCSS | 3.4.19 |
| zig-webui | main branch |

## Project Structure

```
apps/
  ui/
    src/
      components/ui/   # UI components (Button, Sidebar, etc.)
      lib/utils.ts     # Utility functions (cn)
      App.tsx          # Main app component
      index.tsx        # Entry point
  host-zig/
    src/
      main.zig         # Entry point
      root.zig         # Library root + tests
```

## Key Dependencies

**UI:**
- `@kobalte/core`: Accessible UI primitives
- `class-variance-authority`: Component variants
- `tailwind-merge`: Merge Tailwind classes
- `restty`: Terminal emulator library

**Host:**
- `zig_webui`: WebUI bindings (main branch for Zig 0.15+)

## Testing Strategy

- No JavaScript test framework currently configured
- Zig tests: `zig build test` runs all tests
- TypeScript strict mode provides compile-time checks
- No linting tools (ESLint, Prettier) currently configured

## Path Aliases

- `~/*` maps to `./src/*` (configured in vite.config.ts and tsconfig.json)
- Always use `~/*` for internal imports, never relative paths like `../`
