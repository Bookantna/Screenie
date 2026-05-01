#!/bin/bash
# Resets the Screen Recording TCC entry for Screenie.
# Run this whenever macOS keeps re-prompting for permission after an Xcode rebuild.

BUNDLE_ID="com.screenie.app"

echo "Resetting Screen Recording permission for $BUNDLE_ID..."
tccutil reset ScreenCapture "$BUNDLE_ID"

if [ $? -eq 0 ]; then
    echo "Done. Relaunch Screenie from Xcode and grant Screen Recording permission when prompted."
else
    echo "Failed. Try running with sudo: sudo $0"
fi
