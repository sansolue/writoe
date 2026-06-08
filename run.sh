#!/bin/bash
set -e
swift build
cp .build/debug/Writoe Writoe.app/Contents/MacOS/Writoe
cp AppIcon.icns Writoe.app/Contents/Resources/AppIcon.icns
pkill -f "Writoe.app/Contents/MacOS/Writoe" 2>/dev/null || true
sleep 0.3
open Writoe.app
