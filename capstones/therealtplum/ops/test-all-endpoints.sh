#!/bin/bash
# Comprehensive test script for all API endpoint combinations
# Tests health endpoints, versioned routes, and different environments
# Usage: ./ops/test-all-endpoints.sh [base_url]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Base URL - default to localhost, can override
BASE_URL="${1:-http://localhost:3000}"
LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || echo "192.168.1.214")
NETWORK_URL="http://${LOCAL_IP}:3000"

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Test function
test_endpoint() {
    local name=$1
    local url=$2
    local expected_status=$3
    local expected_env=${4:-""}
    local description=$5
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Test #${TOTAL_TESTS}: ${name}${NC}"
    echo -e "${YELLOW}URL: ${url}${NC}"
    if [ -n "$description" ]; then
        echo -e "${YELLOW}Description: ${description}${NC}"
    fi
    echo ""
    
    # Make request
    response=$(curl -s -w "\n%{http_code}" "$url" 2>/dev/null || echo -e "\n000")
    # Extract body and status code (cross-platform)
    body=$(echo "$response" | sed '$d')
    status_code=$(echo "$response" | tail -n 1)
    
    # Check status code
    if [ "$status_code" = "$expected_status" ]; then
        echo -e "${GREEN}✅ Status Code: ${status_code} (expected ${expected_status})${NC}"
        
        # If we expect a specific environment, check it
        if [ -n "$expected_env" ] && command -v jq &> /dev/null; then
            env=$(echo "$body" | jq -r '.env' 2>/dev/null || echo "")
            if [ "$env" = "$expected_env" ]; then
                echo -e "${GREEN}✅ Environment: ${env} (expected ${expected_env})${NC}"
                PASSED_TESTS=$((PASSED_TESTS + 1))
            else
                echo -e "${RED}❌ Environment mismatch! Expected: ${expected_env}, Got: ${env}${NC}"
                FAILED_TESTS=$((FAILED_TESTS + 1))
            fi
        else
            PASSED_TESTS=$((PASSED_TESTS + 1))
        fi
        
        # Show response body (truncated if long)
        if [ -n "$body" ]; then
            echo -e "${CYAN}Response:${NC}"
            if command -v jq &> /dev/null; then
                echo "$body" | jq '.' 2>/dev/null || echo "$body" | head -10
            else
                echo "$body" | head -10
            fi
        fi
    else
        echo -e "${RED}❌ Status Code: ${status_code} (expected ${expected_status})${NC}"
        echo -e "${RED}Response: ${body}${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    echo ""
}

# Check if jq is available
if command -v jq &> /dev/null; then
    USE_JQ=true
else
    USE_JQ=false
    echo -e "${YELLOW}⚠️  jq not found. Install for better JSON output:${NC}"
    echo "   macOS: brew install jq"
    echo "   Linux: sudo apt-get install jq"
    echo ""
fi

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     FMHub API - Comprehensive Endpoint Testing            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Base URL: ${BASE_URL}${NC}"
echo -e "${CYAN}Network URL: ${NETWORK_URL}${NC}"
echo ""

# ============================================================================
# Health Endpoints
# ============================================================================
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}  HEALTH ENDPOINTS${NC}"
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
echo ""

test_endpoint \
    "Health Check (Base)" \
    "${BASE_URL}/health" \
    "200" \
    "" \
    "Basic health endpoint"

test_endpoint \
    "System Health" \
    "${BASE_URL}/system/health" \
    "200" \
    "" \
    "Detailed system health check"

# ============================================================================
# Versioned API Routes - V1
# ============================================================================
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}  VERSIONED ROUTES - V1${NC}"
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
echo ""

test_endpoint \
    "V1 Root" \
    "${BASE_URL}/v1" \
    "501" \
    "" \
    "V1 API root - should return coming soon"

test_endpoint \
    "V1 Strategies" \
    "${BASE_URL}/v1/strategies" \
    "501" \
    "" \
    "V1 strategies endpoint - coming soon"

test_endpoint \
    "V1 Instruments" \
    "${BASE_URL}/v1/instruments" \
    "501" \
    "" \
    "V1 instruments endpoint - coming soon"

test_endpoint \
    "V1 Markets" \
    "${BASE_URL}/v1/markets" \
    "501" \
    "" \
    "V1 markets endpoint - coming soon"

test_endpoint \
    "V1 Nested Path" \
    "${BASE_URL}/v1/users/123/account" \
    "501" \
    "" \
    "V1 nested path - coming soon"

# ============================================================================
# Versioned API Routes - V1-Staged
# ============================================================================
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}  VERSIONED ROUTES - V1-STAGED${NC}"
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
echo ""

test_endpoint \
    "V1-Staged Root" \
    "${BASE_URL}/v1-staged" \
    "501" \
    "" \
    "V1-staged API root - should return coming soon"

test_endpoint \
    "V1-Staged Strategies" \
    "${BASE_URL}/v1-staged/strategies" \
    "501" \
    "" \
    "V1-staged strategies endpoint - coming soon"

test_endpoint \
    "V1-Staged Instruments" \
    "${BASE_URL}/v1-staged/instruments" \
    "501" \
    "" \
    "V1-staged instruments endpoint - coming soon"

test_endpoint \
    "V1-Staged Markets" \
    "${BASE_URL}/v1-staged/markets" \
    "501" \
    "" \
    "V1-staged markets endpoint - coming soon"

# ============================================================================
# Legacy Endpoints (for backward compatibility)
# ============================================================================
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}  LEGACY ENDPOINTS${NC}"
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
echo ""

test_endpoint \
    "Legacy Instruments List" \
    "${BASE_URL}/instruments" \
    "200" \
    "" \
    "Legacy instruments endpoint (backward compatibility)"

test_endpoint \
    "Legacy Market Status" \
    "${BASE_URL}/market/status" \
    "200" \
    "" \
    "Legacy market status endpoint"

test_endpoint \
    "Legacy Focus Ticker Strip" \
    "${BASE_URL}/focus/ticker-strip" \
    "200" \
    "" \
    "Legacy focus ticker strip endpoint"

# ============================================================================
# Network Access Tests (if different from base)
# ============================================================================
if [ "$BASE_URL" = "http://localhost:3000" ]; then
    echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  NETWORK ACCESS TESTS${NC}"
    echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    test_endpoint \
        "Network Health Check" \
        "${NETWORK_URL}/health" \
        "200" \
        "" \
        "Health endpoint via network IP"
fi

# ============================================================================
# Environment-Specific Tests (if multiple instances running)
# ============================================================================
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}  ENVIRONMENT-SPECIFIC TESTS${NC}"
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
echo ""

# Test different ports if multiple environments are running
for port in 3000 3001 3002 3003; do
    test_url="http://localhost:${port}/health"
    if curl -s --connect-timeout 2 "$test_url" > /dev/null 2>&1; then
        env_name=""
        case $port in
            3000) env_name="prod" ;;
            3001) env_name="sim" ;;
            3002) env_name="demo" ;;
            3003) env_name="dev" ;;
        esac
        
        test_endpoint \
            "Port ${port} Health (${env_name:-unknown})" \
            "$test_url" \
            "200" \
            "$env_name" \
            "Health check on port ${port}"
    fi
done

# ============================================================================
# Summary
# ============================================================================
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    TEST SUMMARY                            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Total Tests: ${TOTAL_TESTS}"
echo -e "${GREEN}Passed: ${PASSED_TESTS}${NC}"
if [ $FAILED_TESTS -gt 0 ]; then
    echo -e "${RED}Failed: ${FAILED_TESTS}${NC}"
else
    echo -e "${GREEN}Failed: ${FAILED_TESTS}${NC}"
fi
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed. Check output above.${NC}"
    exit 1
fi

