#!/bin/bash

# Quick test script to verify wallet service is accessible and CORS is working

echo "🔍 Testing Wallet Service API..."
echo ""

# Test 1: Check if service is reachable
echo "1️⃣ Testing service availability..."
curl -I https://wallet-service.devsinkenya.com/v1/wallet/1/balance 2>&1 | head -n 10
echo ""

# Test 2: Test with token (using the token from your example)
echo "2️⃣ Testing with authentication token..."
TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoxLCJyb2xlX2lkIjozLCJleHAiOjE3NjUyOTMxMzQsImlhdCI6MTc2NTI4OTUzNH0.tJZwoBc8Lm-GX1zjVcpE2iIwmXE79xGWQ_PAK3Gk7xs"

curl -X GET "https://wallet-service.devsinkenya.com/v1/wallet/1/balance" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -v 2>&1 | grep -E "(HTTP|Access-Control|userId|balance)"

echo ""
echo "3️⃣ Checking CORS headers specifically..."
curl -X OPTIONS "https://wallet-service.devsinkenya.com/v1/wallet/1/balance" \
  -H "Origin: http://localhost:3000" \
  -H "Access-Control-Request-Method: GET" \
  -H "Access-Control-Request-Headers: Authorization" \
  -v 2>&1 | grep -i "access-control"

echo ""
echo "✅ Test complete!"
