#!/bin/bash
echo "Applying YouTube bypass patches..."
mkdir -p configs
cat > configs/dnsmasq_youtube.conf << 'EOF'
# YouTube domains for bypass
server=/googlevideo.com/8.8.8.8
server=/youtube.com/8.8.8.8
server=/youtu.be/8.8.8.8
server=/ytimg.com/8.8.8.8
server=/googleapis.com/8.8.8.8
server=/ggpht.com/8.8.8.8
server=/gstatic.com/8.8.8.8
EOF

cat > configs/youtube_bypass.sh << 'EOF'
#!/bin/sh
if [ "$1" = "start" ]; then
  if [ -f /etc/storage/dnsmasq_youtube.conf ]; then
    cat /etc/storage/dnsmasq_youtube.conf >> /etc/storage/dnsmasq/dnsmasq.conf
  fi
  killall dnsmasq 2>/dev/null || true
  dnsmasq --conf-file=/etc/storage/dnsmasq/dnsmasq.conf
fi
EOF
chmod +x configs/youtube_bypass.sh

cat > configs/iptables_youtube.sh << 'EOF'
#!/bin/sh
iptables -t mangle -N YOUTUBE_BYPASS 2>/dev/null
iptables -t mangle -F YOUTUBE_BYPASS
iptables -t mangle -A YOUTUBE_BYPASS -d 173.194.0.0/16 -j MARK --set-mark 0x100
iptables -t mangle -A YOUTUBE_BYPASS -d 74.125.0.0/16 -j MARK --set-mark 0x100
iptables -t mangle -A YOUTUBE_BYPASS -d 64.233.0.0/16 -j MARK --set-mark 0x100
iptables -t mangle -I OUTPUT -j YOUTUBE_BYPASS
iptables -t mangle -I PREROUTING -j YOUTUBE_BYPASS
ip route add default via $(nvram get wan_gateway) table 100 2>/dev/null || true
ip rule add fwmark 0x100 lookup 100 2>/dev/null || true
EOF
chmod +x configs/iptables_youtube.sh
echo "YouTube bypass patches applied successfully!"
