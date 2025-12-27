#!/bin/bash
#
# Padavan Firmware Post-Build Processing Script
# Packages artifacts and creates distribution files
#

set -euo pipefail

log() {
    echo "[POST-BUILD] $1"
}

success() {
    echo "[OK] $1"
}

warning() {
    echo "[WARNING] $1"
}

main() {
    log "Starting post-build processing..."
    
    # Get build information
    BUILD_TIMESTAMP=$(date +"%Y.%m.%d_%H.%M.%S")
    GIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    FIRMWARE_VERSION="3.4.3.9-${GIT_HASH}"
    
    log "Build info: Version $FIRMWARE_VERSION, Time: $BUILD_TIMESTAMP"
    
    # ============================================
    # Copy Configuration Files
    # ============================================
    
    CONFIG_FILES=(
        "configs/dnsmasq_youtube.conf"
        "configs/youtube_bypass.sh"
        "configs/iptables_youtube.sh"
        "configs/README.md"
    )
    
    log "Copying configuration files..."
    
    for config_file in "${CONFIG_FILES[@]}"; do
        if [[ -f "$config_file" ]]; then
            filename=$(basename "$config_file")
            cp "$config_file" "./$filename"
            success "Copied: $filename"
        else
            warning "Not found: $config_file"
        fi
    done
    
    # ============================================
    # Create Distribution Package
    # ============================================
    
    log "Creating distribution package..."
    
    # Create directory for distribution
    DIST_DIR="dist"
    mkdir -p "$DIST_DIR"
    
    # Move all build artifacts to dist directory
    if ls *.trx *.bin 2>/dev/null; then
        mv *.trx *.bin "$DIST_DIR/" 2>/dev/null || true
    fi
    
    # Move configuration files
    for file in dnsmasq_youtube.conf youtube_bypass.sh iptables_youtube.sh README.md; do
        if [[ -f "$file" ]]; then
            mv "$file" "$DIST_DIR/" 2>/dev/null || true
        fi
    done
    
    # ============================================
    # Create Installation Instructions
    # ============================================
    
    cat > "$DIST_DIR/INSTALL.md" << EOF
# Padavan Firmware Installation Guide

## Firmware Files
- .trx or .bin - Main firmware file for flashing
- Configuration files for YouTube bypass

## Flashing Instructions

### Method 1: Web Interface (Recommended)
1. Open router web interface (usually 192.168.1.1)
2. Go to Administration -> Firmware Upgrade
3. Click Choose File and select the firmware file
4. Click Upload and wait for completion
5. Router will reboot automatically

### Method 2: Recovery Mode
1. Turn off router
2. Hold Reset button and power on
3. Keep holding for 10 seconds until LED blinks
4. Connect computer via Ethernet (IP: 192.168.1.2)
5. Open browser to 192.168.1.1
6. Upload firmware file

## YouTube Bypass Setup

After flashing:

1. Copy config files to router:
   \`\`\`
   scp dnsmasq_youtube.conf admin@192.168.1.1:/etc/storage/
   scp youtube_bypass.sh admin@192.168.1.1:/etc/storage/
   scp iptables_youtube.sh admin@192.168.1.1:/etc/storage/
   \`\`\`

2. Make scripts executable:
   \`\`\`
   ssh admin@192.168.1.1 "chmod +x /etc/storage/*.sh"
   \`\`\`

3. Add to startup (/etc/storage/start_script.sh):
   \`\`\`
   /etc/storage/youtube_bypass.sh start
   \`\`\`

## Verification

Check if YouTube bypass is working:
\`\`\`
ssh admin@192.168.1.1 "/etc/storage/iptables_youtube.sh status"
\`\`\`

## Important Notes

- Backup your configuration before flashing
- Do not interrupt the flashing process
- First boot may take 3-5 minutes
- Reset to defaults if experiencing issues

## Support

- GitHub: https://github.com/shvchk/padavan-builder-workflow
- Build: $FIRMWARE_VERSION
- Date: $BUILD_TIMESTAMP
EOF
    
    success "Created installation guide"
    
    # ============================================
    # Create ZIP Archive
    # ============================================
    
    log "Creating ZIP archive..."
    
    # Determine device name from environment or config
    DEVICE_NAME="${DEVICE_NAME:-ASUS_RT-N11P}"
    ZIP_NAME="${DEVICE_NAME}_Padavan_${BUILD_TIMESTAMP}.zip"
    
    # Create ZIP with all distribution files
    if [[ -d "$DIST_DIR" ]]; then
        cd "$DIST_DIR"
        zip -r9 "../$ZIP_NAME" ./*
        cd ..
        
        ZIP_SIZE=$(stat -c %s "$ZIP_NAME" | numfmt --to=iec --format="%.2fB")
        success "Created archive: $ZIP_NAME ($ZIP_SIZE)"
    else
        warning "Distribution directory not found, skipping ZIP creation"
    fi
    
    # ============================================
    # Generate Build Report
    # ============================================
    
    cat > "build-report.txt" << EOF
============================================
PADAVAN FIRMWARE BUILD REPORT
============================================
Build Date:      $(date)
Build Timestamp: $BUILD_TIMESTAMP
Firmware Version: $FIRMWARE_VERSION
Git Commit:      $GIT_HASH
Device:          $DEVICE_NAME

ARTIFACTS GENERATED:
$(find . -maxdepth 1 -type f -name "*.zip" -o -name "*.trx" -o -name "*.bin" | sort | sed 's|^./|  - |')

CONFIGURATION FILES:
$(find dist/ -type f 2>/dev/null | sort | sed 's|^|  - |')

BUILD SUMMARY:
- YouTube bypass system: Included
- Custom scripts: Included
- Documentation: Included
- Installation guide: Included

NEXT STEPS:
1. Flash firmware using INSTALL.md instructions
2. Configure YouTube bypass as needed
3. Enjoy enhanced functionality!

============================================
BUILD PROCESS COMPLETED SUCCESSFULLY
============================================
EOF
    
    success "Generated build report"
    
    # ============================================
    # Final Output
    # ============================================
    
    echo ""
    echo "========================================================"
    echo "POST-BUILD PROCESSING COMPLETE"
    echo "========================================================"
    echo "Distribution files ready in: $DIST_DIR/"
    echo "ZIP Archive: $ZIP_NAME"
    echo "Build Report: build-report.txt"
    echo ""
    echo "Ready for distribution!"
    echo "========================================================"
    
    # Cleanup temporary files
    log "Cleaning up temporary files..."
    rm -rf configs/ 2>/dev/null || true
}

# Run main function
main "$@"
