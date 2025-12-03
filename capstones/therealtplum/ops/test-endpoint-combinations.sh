#!/bin/bash
# Test all endpoint combinations - simplified version
# Tests both localhost and network IP
# Usage: ./ops/test-endpoint-combinations.sh

set -e

LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || echo "192.168.1.214")

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     Testing All API Endpoint Combinations                  ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Test function
test() {
    local name=$1
    local url=$2
    local expected=$3
    
    printf "%-50s " "$name"
    status=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    
    if [ "$status" = "$expected" ]; then
        echo "✅ $status"
    else
        echo "❌ $status (expected $expected)"
    fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  LOCALHOST TESTS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

test "Health (localhost)" "http://localhost:3000/health" "200"
test "System Health (localhost)" "http://localhost:3000/system/health" "200"
test "V1 Root (localhost)" "http://localhost:3000/v1" "501"
test "V1 Strategies (localhost)" "http://localhost:3000/v1/strategies" "501"
test "V1 Instruments (localhost)" "http://localhost:3000/v1/instruments" "501"
test "V1-Staged Root (localhost)" "http://localhost:3000/v1-staged" "501"
test "V1-Staged Strategies (localhost)" "http://localhost:3000/v1-staged/strategies" "501"
test "Legacy Instruments (localhost)" "http://localhost:3000/instruments" "200"
test "Legacy Market Status (localhost)" "http://localhost:3000/market/status" "200"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  NETWORK IP TESTS (192.168.1.214)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

test "Health (network)" "http://${LOCAL_IP}:3000/health" "200"
test "System Health (network)" "http://${LOCAL_IP}:3000/system/health" "200"
test "V1 Root (network)" "http://${LOCAL_IP}:3000/v1" "501"
test "V1 Strategies (network)" "http://${LOCAL_IP}:3000/v1/strategies" "501"
test "V1 Instruments (network)" "http://${LOCAL_IP}:3000/v1/instruments" "501"
test "V1-Staged Root (network)" "http://${LOCAL_IP}:3000/v1-staged" "501"
test "V1-Staged Strategies (network)" "http://${LOCAL_IP}:3000/v1-staged/strategies" "501"
test "Legacy Instruments (network)" "http://${LOCAL_IP}:3000/instruments" "200"
test "Legacy Market Status (network)" "http://${LOCAL_IP}:3000/market/status" "200"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ = Working correctly"
echo "❌ = Needs attention (may need API rebuild)"
echo ""
echo "Note: If versioned routes (v1, v1-staged) show 404 instead of 501,"
echo "      you need to rebuild the API container:"
echo ""
echo "      docker compose build api"
echo "      docker compose up -d api"
echo ""

