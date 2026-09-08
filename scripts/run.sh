#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$DIR"

echo "⚡ Building SKALA-MenuBar in release mode..."
swift build -c release

# Kill any existing instance if running
pkill -f "SKALA-MenuBar" || true
pkill -f "PangyoBus" || true

echo "🚀 Starting SKALA-MenuBar in background..."
"$DIR/.build/release/SKALA-MenuBar" > /dev/null 2>&1 &

echo "✨ SKALA-MenuBar is now running in your macOS menu bar!"
