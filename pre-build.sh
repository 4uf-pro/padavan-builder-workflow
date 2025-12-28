#!/bin/bash
set -euo pipefail

echo "========================================"
echo "Pre-build optimization"
echo "========================================"

# Language files optimization
LANG_DIR="padavan-ng/trunk/user/www/n56u_ribbon_fixed/lang"

if [[ -d "$LANG_DIR" ]]; then
    echo "Optimizing language files..."
    echo "Keeping only: EN.js, RU.js, UK.js"
    
    cd "$LANG_DIR"
    
    # Remove all languages except required ones
    for file in *.js; do
        case "$file" in
            EN.js|RU.js|UK.js)
                echo "  Keeping: $file"
                ;;
            *)
                echo "  Removing: $file"
                rm -f "$file"
                ;;
        esac
    done
    
    echo "Language files optimization completed"
else
    echo "Warning: Language directory not found: $LANG_DIR"
fi

# Remove demo files
DEMO_DIR="padavan-ng/trunk/user/www/n56u_ribbon_fixed/demo"
if [[ -d "$DEMO_DIR" ]]; then
    echo "Removing demo files..."
    rm -rf "$DEMO_DIR"
fi

echo "========================================"
echo "Pre-build optimization completed"
echo "========================================"