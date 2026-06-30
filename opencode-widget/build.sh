#!/bin/bash
cd "$(dirname "$0")"
swift build
echo "Build complete. Binary at .build/debug/OpencodeWidgetApp"
