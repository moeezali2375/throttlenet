#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🚀 Building and running ThrottleNet..."
cd "$PROJECT_DIR"
swift run ThrottleNet
