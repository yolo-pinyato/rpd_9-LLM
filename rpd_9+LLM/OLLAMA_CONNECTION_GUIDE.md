# Ollama Connection Guide for iOS App

This guide will help you resolve connection issues between your iOS app and Ollama running on your Mac.

## Understanding the Issue

The error you're seeing:
```
Task <...> finished with error [-1001] Error Domain=NSURLErrorDomain Code=-1001 "The request timed out."
```

This happens because:
1. **Simulator**: Needs to connect to `localhost` on your Mac
2. **Physical Device**: Needs to connect to your Mac's IP address on the same network

## Solution Overview

The app now automatically handles both scenarios:
- **Simulator**: Uses `http://localhost:11434`
- **Physical Device**: Uses your Mac's IP address (configurable in the app)

## Setup Instructions

### For Simulator Testing

1. **Start Ollama on your Mac**:
   ```bash
   ollama serve
   ```

2. **Allow network access**:
   - Ollama should automatically bind to `127.0.0.1:11434`
   - The simulator can access this via `localhost:11434`

3. **Test the connection**:
   - Open the app in the simulator
   - Go to **Profile** tab
   - Scroll to **Network Settings**
   - Tap "Test Connection"
   - You should see "Connected" status

### For Physical Device Testing

1. **Find your Mac's IP address**:

   **Method 1 - Terminal**:
   ```bash
   ipconfig getifaddr en0
   ```

   **Method 2 - System Preferences**:
   - Open System Preferences > Network
   - Select your active connection (Wi-Fi or Ethernet)
   - Your IP address is shown (e.g., `192.168.1.100`)

2. **Configure Ollama to accept external connections**:

   By default, Ollama only listens on localhost. You need to allow it to accept connections from your network.

   **Option A - Environment Variable (Recommended)**:
   ```bash
   export OLLAMA_HOST=0.0.0.0:11434
   ollama serve
   ```

   **Option B - Launchctl (Persistent)**:
   ```bash
   launchctl setenv OLLAMA_HOST "0.0.0.0:11434"
   # Then restart Ollama
   ```

3. **Configure firewall** (if enabled):
   ```bash
   # Allow Ollama through macOS firewall
   sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/local/bin/ollama
   sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp /usr/local/bin/ollama
   ```

4. **Set IP address in the app**:
   - Open the app on your physical device
   - Go to **Profile** tab
   - Scroll to **Network Settings**
   - Tap "Edit" next to Mac IP Address
   - Enter your Mac's IP (e.g., `192.168.1.100`)
   - Tap "Save"
   - Tap "Test Connection"
   - You should see "Connected" status

## Troubleshooting

### Connection Timeout

**Symptoms**: "The request timed out" error

**Solutions**:
1. Verify Ollama is running: `ollama list` in Terminal
2. Check if Ollama is listening on the correct interface:
   ```bash
   lsof -i :11434
   ```
   Should show ollama listening on `*:11434` or `0.0.0.0:11434`

3. Test connection from your Mac:
   ```bash
   curl http://localhost:11434/api/tags
   ```

4. Test from another device on the same network:
   ```bash
   curl http://YOUR_MAC_IP:11434/api/tags
   ```

### Firewall Blocking

**Symptoms**: Connection works from Mac but not from physical device

**Solutions**:
1. Temporarily disable macOS firewall to test:
   - System Preferences > Security & Privacy > Firewall
   - Turn off firewall temporarily
   - Test connection
   - Re-enable and configure if it works

2. Add firewall rule for Ollama (see step 3 in Physical Device setup)

### Wrong IP Address

**Symptoms**: Connection fails immediately

**Solutions**:
1. Verify your Mac's IP hasn't changed:
   ```bash
   ipconfig getifaddr en0
   ```

2. Ensure both Mac and iPhone are on the same network

3. Try using your Mac's hostname:
   ```bash
   hostname
   ```
   Then in the app, enter: `YOUR-HOSTNAME.local` (e.g., `MacBook-Pro.local`)

### Network Issues

**Symptoms**: Intermittent connection

**Solutions**:
1. Ensure stable Wi-Fi connection
2. Disable VPN if active
3. Use 5GHz Wi-Fi instead of 2.4GHz for better performance
4. Restart your router if issues persist

## Advanced Configuration

### Using mDNS/Bonjour

Instead of entering IP addresses manually, you can use your Mac's hostname:

1. Find your hostname:
   ```bash
   hostname
   ```

2. In the app, enter: `YOUR-HOSTNAME.local` (e.g., `MacBook-Pro.local`)

This allows automatic resolution even if your IP changes.

### Increase Timeout

If you have a slow network, you can increase the timeout in `OllamaService.swift`:

```swift
request.timeoutInterval = 180 // Already set to 3 minutes
```

### Static IP Address

For consistent connections, set a static IP on your Mac:
1. System Preferences > Network
2. Select your connection
3. Click "Advanced"
4. Go to "TCP/IP"
5. Configure IPv4: Manually
6. Enter a static IP in your network range

## Testing the Setup

### Quick Test Script

Run this on your Mac to verify Ollama is accessible:

```bash
#!/bin/bash
echo "Testing Ollama connection..."
echo ""
echo "Local test:"
curl -s http://localhost:11434/api/tags | head -n 5
echo ""
echo "Network test (replace with your IP):"
IP=$(ipconfig getifaddr en0)
echo "Your Mac's IP: $IP"
curl -s http://$IP:11434/api/tags | head -n 5
```

### In-App Testing

1. Open the app (simulator or device)
2. Navigate to Profile tab
3. Find "Network Settings" section
4. Observe:
   - Current URL being used
   - Connection status (green = good, red = problem)
5. Tap "Test Connection" to verify

## Summary

### What Changed

1. **OllamaService.swift**:
   - Changed from `127.0.0.1` to `localhost` for simulator (better DNS resolution)
   - Added dynamic IP configuration for physical devices
   - Increased timeouts from 2-3 seconds to 5 seconds for connection checks
   - Increased generation timeout from 120s to 180s
   - Added debug logging to help troubleshoot

2. **WorkforceDevApp.swift**:
   - Added Network Settings section to Profile view
   - Shows current connection URL
   - Displays real-time connection status
   - Allows custom IP configuration for physical devices
   - Includes "Test Connection" button

3. **User Experience**:
   - Simulator: Works automatically with `localhost`
   - Physical Device: User configures Mac's IP once in the app
   - Both: Visual feedback on connection status

## Need Help?

If you continue to experience issues:

1. Check the Xcode console for detailed error messages
2. Look for debug logs starting with 🔗 or ❌
3. Verify all steps in the Physical Device setup
4. Ensure your Mac and iPhone are on the same Wi-Fi network
5. Test with `curl` from Terminal to isolate the issue
