#!/bin/bash

# Script to trigger Flutter hot reload and capture logs

echo "🔄 Triggering Flutter hot reload..."
echo ""

# Find the Flutter process
FLUTTER_PID=$(ps aux | grep "flutter run" | grep -v grep | awk '{print $2}' | head -1)

if [ -z "$FLUTTER_PID" ]; then
    echo "❌ Flutter is not running"
    exit 1
fi

echo "✅ Found Flutter process: $FLUTTER_PID"
echo "📝 To see logs, check the terminal where 'flutter run' is active"
echo ""
echo "💡 In your Flutter terminal, press 'r' to hot reload"
echo "💡 Then navigate to a screen that calls WalletService.getWalletBalance()"
echo ""
echo "🔍 Look for these log messages:"
echo "   - 🔍 [WALLET] Fetching balance for user: X"
echo "   - 🔍 [WALLET] URL: ..."
echo "   - 🔍 [WALLET] Token (first 50 chars): ..."
echo "   - Either: ✅ [WALLET] Balance fetched successfully"
echo "   - Or: ❌ [WALLET] ClientException / Other error"
