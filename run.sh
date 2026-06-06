#!/bin/bash
set -e
swift build
cp .build/debug/Writoe Writoe.app/Contents/MacOS/Writoe
pkill -f "Writoe.app/Contents/MacOS/Writoe" 2>/dev/null || true
sleep 0.3
open Writoe.app
