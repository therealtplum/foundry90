#!/bin/bash
# Test script to verify all API environments locally
# Usage: ./ops/test-all-envs.sh

set -e

echo "🧪 Testing All API Environments"
echo "================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
ORANGE='\033[0;33m'
NC='\033[0m' # No Color

# Test function
test_endpoint() {
    local env_name=$1
    local url=$2
    local expected_env=$3
    
    echo -e "${BLUE}Testing ${env_name}...${NC}"
    echo "  URL: $url"
    
    response=$(curl -s -w "\n%{http_code}" "$url" 2>/dev/null || echo -e "\n000")
    body=$(echo "$response" | head -n -1)
    status_code=$(echo "$response" | tail -n 1)
    
    if [ "$status_code" = "200" ]; then
        env=$(echo "$body" | jq -r '.env' 2>/dev/null || echo "unknown")
        message=$(echo "$body" | jq -r '.message' 2>/dev/null || echo "unknown")
        
        if [ "$env" = "$expected_env" ]; then
            echo -e "  ${GREEN}✅ Status: $status_code | Env: $env${NC}"
            echo "  Message: $message"
            echo "$body" | jq '.' 2>/dev/null || echo "$body"
        else
            echo -e "  ${RED}❌ Wrong environment! Expected: $expected_env, Got: $env${NC}"
        fi
    else
        echo -e "  ${RED}❌ Failed! Status code: $status_code${NC}"
        echo "  Response: $body"
    fi
    echo ""
}

# Test versioned routes
test_versioned_route() {
    local env_name=$1
    local url=$2
    
    echo -e "${YELLOW}Testing versioned route for ${env_name}...${NC}"
    echo "  URL: $url"
    
    response=$(curl -s -i "$url" 2>/dev/null || echo "")
    status_code=$(echo "$response" | grep -i "HTTP" | awk '{print $2}' || echo "000")
    
    if [ "$status_code" = "501" ]; then
        echo -e "  ${GREEN}✅ Correctly returns 501 Not Implemented${NC}"
        echo "$response" | grep -A 5 "{" | head -5
    else
        echo -e "  ${RED}❌ Unexpected status code: $status_code${NC}"
    fi
    echo ""
}

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}⚠️  jq not found. Installing JSON parsing...${NC}"
    echo "Install jq for better output:"
    echo "  macOS: brew install jq"
    echo "  Linux: sudo apt-get install jq"
    echo ""
    USE_JQ=false
else
    USE_JQ=true
fi

echo "Testing Health Endpoints"
echo "-----------------------"
echo ""

# Test health endpoints (assuming all on different ports)
test_endpoint "Production" "http://localhost:3000/health" "prod"
test_endpoint "Simulation" "http://localhost:3001/health" "sim"
test_endpoint "Demo" "http://localhost:3002/health" "demo"
test_endpoint "Development" "http://localhost:3003/health" "dev"

echo ""
echo "Testing Versioned Routes"
echo "------------------------"
echo ""

test_versioned_route "Production" "http://localhost:3000/v1/strategies"
test_versioned_route "Development (staged)" "http://localhost:3003/v1-staged/strategies"

echo ""
echo "================================"
echo -e "${GREEN}✅ Testing Complete!${NC}"
echo ""
echo "Note: If endpoints are not responding, make sure:"
echo "  1. Docker containers are running"
echo "  2. Environment variables are set correctly"
echo "  3. Ports are accessible"
echo ""
echo "To start services:"
echo "  docker compose up -d"
echo "  # Then set F90_ENV and restart for each environment"

