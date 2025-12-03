#!/bin/bash
# Show the network URL for accessing the API from other devices
# Usage: ./ops/show-network-url.sh

set -e

# Get local IP address
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "unknown")
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    LOCAL_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "unknown")
else
    LOCAL_IP="unknown"
fi

# Get port from docker-compose or default
PORT=${PORT:-3000}

# Check if API is running
if docker ps --format '{{.Names}}' | grep -q 'fmhub_api'; then
    STATUS="🟢 Running"
else
    STATUS="🔴 Not Running"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  FMHub API - Network Access Information"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Status: $STATUS"
echo "Local IP: $LOCAL_IP"
echo "Port: $PORT"
echo ""
echo "📍 Access from this Mac:"
echo "   http://localhost:$PORT/health"
echo ""
if [ "$LOCAL_IP" != "unknown" ]; then
    echo "🌐 Access from other devices on your network:"
    echo "   http://$LOCAL_IP:$PORT/health"
    echo ""
    echo "📱 Quick test from another device:"
    echo "   curl http://$LOCAL_IP:$PORT/health"
    echo ""
    echo "🔗 Useful endpoints:"
    echo "   Health:        http://$LOCAL_IP:$PORT/health"
    echo "   System Health: http://$LOCAL_IP:$PORT/system/health"
    echo "   V1 API:        http://$LOCAL_IP:$PORT/v1/strategies"
    echo ""
else
    echo "⚠️  Could not determine local IP address"
    echo "   Try: ipconfig getifaddr en0"
    echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "💡 Tips:"
echo "   • Make sure macOS Firewall allows connections"
echo "   • Both devices must be on the same WiFi network"
echo "   • Test locally first: curl http://localhost:$PORT/health"
echo ""

