#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$DIR"

echo "🚌 Building PangyoBus in release mode..."
swift build -c release

# Kill any existing instance if running
pkill -f "\.build/release/PangyoBus" || true
pkill -f "\.build/debug/PangyoBus" || true

echo "🚀 Starting PangyoBus in background..."
"$DIR/.build/release/PangyoBus" > /dev/null 2>&1 &

echo "✨ PangyoBus is now running in your macOS menu bar!"
