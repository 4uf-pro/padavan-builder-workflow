#!/usr/bin/env bash
#
# Padavan Firmware Pre-Build Customization Script
# Adds YouTube bypass functionality and other customizations
#

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

main() {
    log_info "Starting pre-build customization..."
    
    # Create configuration directory
    CONFIG_DIR="configs"
    mkdir -p "$CONFIG_DIR"
    
    # ============================================
    # YouTube Bypass Configuration
    # ============================================
    
    log_info "Creating YouTube bypass configurations..."
    
    # DNS-based bypass configuration
    cat > "$CONFIG_DIR/dnsmasq_youtube.conf" << 'EOF'
# ===========================================================================
# YouTube Bypass DNS Configuration
# ===========================================================================
# This file contains DNS rules to bypass restrictions for YouTube services.
# Add to /etc/storage/dnsmasq/dnsmasq.conf or include via conf-file directive.
#
# Generated: $(date)
# ===========================================================================

# Primary YouTube domains (use reliable DNS servers)
server=/googlevideo.com/8.8.8.8
server=/googlevideo.com/8.8.4.4
server=/youtube.com/8.8.8.8
server=/youtube.com/8.8.4.4
server=/youtu.be/8.8.8.8
server=/youtubei.googleapis.com/8.8.8.8

# YouTube static content domains
server=/ytimg.com/1.1.1.1
server=/ytimg.com/1.0.0.1
server=/ggpht.com/9.9.9.9
server=/googleapis.com/9.9.9.9
server=/gstatic.com/9.9.9.9

# Additional Google services that may affect YouTube
server=/google.com/8.8.8.8
server=/google.ru/8.8.8.8
server=/googleusercontent.com/8.8.8.8

# IPv6 DNS servers (optional)
#server=/googlevideo.com/2001:4860:4860::8888
#server=/googlevideo.com/2001:4860:4860::8844

# DNS cache settings for better performance
cache-size=10000
local-ttl=300
neg-ttl=60
EOF
    
    # YouTube bypass startup script
    cat > "$CONFIG_DIR/youtube_bypass.sh" << 'EOF'
#!/bin/sh
#
# YouTube Bypass Startup Script
# Usage: youtube_bypass.sh [start|stop|restart]
#

CONFIG_FILE="/etc/storage/dnsmasq_youtube.conf"
DNSMASQ_CONF="/etc/storage/dnsmasq/dnsmasq.conf"
PID_FILE="/var/run/dnsmasq.pid"

start_service() {
    logger -t "YouTube-Bypass" "Starting YouTube bypass service..."
    
    # Check if config file exists
    if [ ! -f "$CONFIG_FILE" ]; then
        logger -t "YouTube-Bypass" "ERROR: Config file $CONFIG_FILE not found"
        return 1
    fi
    
    # Add YouTube bypass rules to dnsmasq config
    if ! grep -q "dnsmasq_youtube.conf" "$DNSMASQ_CONF" 2>/dev/null; then
        echo "# YouTube bypass rules" >> "$DNSMASQ_CONF"
        echo "conf-file=$CONFIG_FILE" >> "$DNSMASQ_CONF"
        logger -t "YouTube-Bypass" "Added YouTube rules to dnsmasq config"
    fi
    
    # Restart dnsmasq to apply changes
    if [ -f "$PID_FILE" ]; then
        kill -HUP $(cat "$PID_FILE") 2>/dev/null && \
        logger -t "YouTube-Bypass" "Reloaded dnsmasq configuration"
    else
        dnsmasq --conf-file="$DNSMASQ_CONF" && \
        logger -t "YouTube-Bypass" "Started dnsmasq with YouTube bypass"
    fi
    
    # Apply iptables rules if script exists
    if [ -x "/etc/storage/iptables_youtube.sh" ]; then
        /etc/storage/iptables_youtube.sh
        logger -t "YouTube-Bypass" "Applied iptables rules"
    fi
    
    logger -t "YouTube-Bypass" "Service started successfully"
    return 0
}

stop_service() {
    logger -t "YouTube-Bypass" "Stopping YouTube bypass service..."
    
    # Remove YouTube rules from dnsmasq config
    if [ -f "$DNSMASQ_CONF" ]; then
        sed -i '/# YouTube bypass rules/d' "$DNSMASQ_CONF"
        sed -i '/dnsmasq_youtube.conf/d' "$DNSMASQ_CONF"
        logger -t "YouTube-Bypass" "Removed YouTube rules from dnsmasq config"
    fi
    
    # Restart dnsmasq
    if [ -f "$PID_FILE" ]; then
        kill -HUP $(cat "$PID_FILE") 2>/dev/null
        logger -t "YouTube-Bypass" "Reloaded dnsmasq configuration"
    fi
    
    logger -t "YouTube-Bypass" "Service stopped"
    return 0
}

case "$1" in
    start)
        start_service
        ;;
    stop)
        stop_service
        ;;
    restart)
        stop_service
        sleep 2
        start_service
        ;;
    *)
        echo "Usage: $0 {start|stop|restart}"
        exit 1
        ;;
esac

exit $?
EOF
    
    # Advanced iptables rules for YouTube bypass
    cat > "$CONFIG_DIR/iptables_youtube.sh" << 'EOF'
#!/bin/sh
#
# Advanced YouTube Bypass iptables Rules
# Marks YouTube traffic for special routing treatment
#

# YouTube IP ranges (regularly updated)
YT_PREFIXES="
173.194.0.0/16
74.125.0.0/16
64.233.0.0/16
207.223.0.0/16
208.117.0.0/16
208.65.0.0/16
209.85.0.0/16
216.58.0.0/16
216.239.0.0/16
"

# Routing table for marked packets
RT_TABLE=100
RT_MARK=0x100

setup_routing() {
    # Create custom routing table if it doesn't exist
    if ! grep -q "^$RT_TABLE " /etc/iproute2/rt_tables 2>/dev/null; then
        echo "$RT_TABLE youtubebypass" >> /etc/iproute2/rt_tables
    fi
    
    # Get current gateway
    WAN_GW=$(nvram get wan_gateway 2>/dev/null || ip route | grep default | awk '{print $3}')
    
    if [ -n "$WAN_GW" ]; then
        # Add default route to custom table
        ip route replace default via "$WAN_GW" table $RT_TABLE 2>/dev/null
        
        # Add rule to route marked packets
        ip rule add fwmark $RT_MARK table $RT_TABLE 2>/dev/null
        
        logger -t "YouTube-IPTables" "Routing setup complete (Gateway: $WAN_GW)"
    else
        logger -t "YouTube-IPTables" "WARNING: Could not determine gateway"
    fi
}

setup_iptables() {
    # Create custom chain for YouTube traffic
    iptables -t mangle -N YOUTUBE_BYPASS 2>/dev/null
    iptables -t mangle -F YOUTUBE_BYPASS
    
    # Mark YouTube traffic
    for prefix in $YT_PREFIXES; do
        iptables -t mangle -A YOUTUBE_BYPASS -d "$prefix" -j MARK --set-mark $RT_MARK
    done
    
    # Also mark by port for YouTube (HTTP/HTTPS)
    iptables -t mangle -A YOUTUBE_BYPASS -p tcp --dport 80 -j MARK --set-mark $RT_MARK
    iptables -t mangle -A YOUTUBE_BYPASS -p tcp --dport 443 -j MARK --set-mark $RT_MARK
    iptables -t mangle -A YOUTUBE_BYPASS -p udp --dport 443 -j MARK --set-mark $RT_MARK
    
    # Apply chain to traffic
    iptables -t mangle -I OUTPUT -j YOUTUBE_BYPASS
    iptables -t mangle -I PREROUTING -j YOUTUBE_BYPASS
    
    # Logging (optional, for debugging)
    # iptables -t mangle -A YOUTUBE_BYPASS -m limit --limit 1/min -j LOG --log-prefix "YouTube-Traffic: "
    
    logger -t "YouTube-IPTables" "iptables rules applied"
}

cleanup() {
    # Remove iptables rules
    iptables -t mangle -D OUTPUT -j YOUTUBE_BYPASS 2>/dev/null || true
    iptables -t mangle -D PREROUTING -j YOUTUBE_BYPASS 2>/dev/null || true
    iptables -t mangle -F YOUTUBE_BYPASS 2>/dev/null || true
    iptables -t mangle -X YOUTUBE_BYPASS 2>/dev/null || true
    
    # Remove routing rules
    ip rule del fwmark $RT_MARK table $RT_TABLE 2>/dev/null || true
    ip route flush table $RT_TABLE 2>/dev/null || true
    
    logger -t "YouTube-IPTables" "Cleanup completed"
}

case "$1" in
    start|apply)
        setup_routing
        setup_iptables
        ;;
    stop|remove)
        cleanup
        ;;
    status)
        echo "=== YouTube Bypass iptables Status ==="
        iptables -t mangle -L YOUTUBE_BYPASS -n 2>/dev/null && echo "Chain exists" || echo "Chain not found"
        ip rule list | grep "lookup $RT_TABLE" && echo "Routing rule exists" || echo "No routing rule"
        echo "======================================"
        ;;
    *)
        echo "Usage: $0 {start|stop|status}"
        echo "  start/apply  - Apply YouTube bypass rules"
        echo "  stop/remove  - Remove all rules"
        echo "  status       - Show current status"
        exit 1
        ;;
esac

exit 0
EOF
    
    # Make scripts executable
    chmod +x "$CONFIG_DIR/youtube_bypass.sh"
    chmod +x "$CONFIG_DIR/iptables_youtube.sh"
    
    log_success "YouTube bypass configurations created"
    
    # ============================================
    # Additional Customizations
    # ============================================
    
    log_info "Creating additional customizations..."
    
    # Custom welcome message for web interface
    cat > "$CONFIG_DIR/webui_custom.html" << 'EOF'
<!-- Custom Web UI Modifications -->
<style>
.custom-welcome {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    padding: 15px;
    border-radius: 8px;
    margin: 10px 0;
    text-align: center;
    box-shadow: 0 4px 6px rgba(0,0,0,0.1);
}
.custom-welcome h3 {
    margin: 0;
    font-size: 18px;
}
</style>

<script>
$(document).ready(function() {
    // Add custom welcome message
    $('.content-header').after(
        '<div class="custom-welcome">' +
        '<h3>🚀 Padavan Custom Firmware</h3>' +
        '<p>Enhanced with YouTube bypass and performance optimizations</p>' +
        '</div>'
    );
    
    // Add build info to footer
    var buildInfo = 'Build: ' + new Date().toLocaleDateString() + ' | YouTube Bypass: Enabled';
    $('.main-footer').append('<div class="pull-right hidden-xs"><b>' + buildInfo + '</b></div>');
});
</script>
EOF
    
    log_success "Additional customizations created"
    
    # ============================================
    # Documentation
    # ============================================
    
    cat > "$CONFIG_DIR/README.md" << 'EOF'
# Custom Padavan Firmware Features

## 📦 Included Features

### 1. YouTube Bypass System
- **DNS-based bypass**: Special DNS rules for YouTube domains
- **iptables routing**: Traffic marking and custom routing
- **Automatic startup**: Integrated with system services

### 2. Configuration Files
- `dnsmasq_youtube.conf` - DNS rules for YouTube services
- `youtube_bypass.sh` - Service control script
- `iptables_youtube.sh` - Advanced traffic routing

### 3. Web UI Enhancements
- Custom welcome message
- Build information in footer

## 🚀 Installation

1. Copy config files to router:
   ```bash
   scp dnsmasq_youtube.conf admin@router:/etc/storage/
   scp youtube_bypass.sh admin@router:/etc/storage/
   scp iptables_youtube.sh admin@router:/etc/storage/
   