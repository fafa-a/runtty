#!/bin/bash
# dev.sh - Development workflow script for RunTTY
# Builds UI and runs the Zig host with webui context

set -e

echo "=== RunTTY Development Workflow ==="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo -e "${YELLOW}Step 1: Building UI...${NC}"
cd apps/ui
if ! bun run build 2>&1; then
    echo -e "${RED}UI build failed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ UI built successfully${NC}"
echo ""

echo -e "${YELLOW}Step 2: Running Zig Host...${NC}"
cd ../host-zig
echo -e "${GREEN}✓ Starting webui server${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
echo ""

# Force X11 backend to avoid Wayland issues
export GDK_BACKEND=x11
# Alternative: use WebUI's default browser detection
zig build run
