#!/bin/bash
echo "Post-build processing..."

if [ -f configs/dnsmasq_youtube.conf ]; then
  cp configs/dnsmasq_youtube.conf .
  echo "✓ dnsmasq_youtube.conf"
fi

if [ -f configs/youtube_bypass.sh ]; then
  cp configs/youtube_bypass.sh .
  echo "✓ youtube_bypass.sh"
fi

if [ -f configs/iptables_youtube.sh ]; then
  cp configs/iptables_youtube.sh .
  echo "✓ iptables_youtube.sh"
fi

echo "Post-build completed!"
