// Test script to verify wallet API endpoint
// Run this in browser console (F12) when the Flutter app is running

const testWalletAPI = async () => {
    const token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoxLCJyb2xlX2lkIjozLCJleHAiOjE3NjUyOTMxMzQsImlhdCI6MTc2NTI4OTUzNH0.tJZwoBc8Lm-GX1zjVcpE2iIwmXE79xGWQ_PAK3Gk7xs";
    const userId = 1;
    const url = `https://wallet-service.devsinkenya.com/v1/wallet/${userId}/balance`;

    console.log("🔍 Testing wallet API...");
    console.log("🔍 URL:", url);
    console.log("🔍 Token:", token.substring(0, 50) + "...");

    try {
        const response = await fetch(url, {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${token}`,
                'Content-Type': 'application/json',
                'Accept': 'application/json',
            },
        });

        console.log("✅ Response status:", response.status);
        console.log("✅ Response headers:", Object.fromEntries(response.headers.entries()));

        const data = await response.json();
        console.log("✅ Response data:", data);

        return data;
    } catch (error) {
        console.error("❌ Error:", error);
        console.error("❌ Error type:", error.constructor.name);
        console.error("❌ Error message:", error.message);

        // Check if it's a CORS error
        if (error instanceof TypeError && error.message.includes('Failed to fetch')) {
            console.error("❌ This is likely a CORS error!");
            console.error("❌ Check:");
            console.error("   1. Network tab in DevTools");
            console.error("   2. Console for CORS-related messages");
            console.error("   3. Server CORS configuration");
        }

        throw error;
    }
};

// Run the test
testWalletAPI();
