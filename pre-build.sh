#!/bin/bash
# Pre-build optimization script for Padavan firmware
# Removes unnecessary language files to save space

echo "=== PRE-BUILD OPTIMIZATION ==="

echo "Keeping only necessary languages: EN (English), RU (Russian), UK (Ukrainian)"

# Go to language directory
cd padavan-ng/trunk/user/www/n56u_ribbon_fixed/lang 2>/dev/null || {
    echo "Error: Language directory not found"
    exit 0  # Don't fail if directory doesn't exist
}

echo "Language files before:"
ls -la *.js 2>/dev/null || echo "No language files found"

# Remove all languages except needed ones
find . -maxdepth 1 -name "*.js" ! -name 'EN.js' ! -name 'RU.js' ! -name 'UK.js' -delete 2>/dev/null || true

echo "Language files after:"
ls -la *.js 2>/dev/null || echo "No language files remaining"

# Remove demo files
cd ../../..
rm -rf demo 2>/dev/null && echo "Demo files removed" || echo "No demo files found"

echo "=== PRE-BUILD OPTIMIZATION COMPLETE ==="