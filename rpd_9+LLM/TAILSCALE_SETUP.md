# Tailscale Setup for Remote Ollama Access

## What is Tailscale?

Tailscale creates a secure, encrypted VPN between your devices. Your iPhone can access your Mac's Ollama server from anywhere - home, coffee shop, cellular data, anywhere in the world!

## Benefits

- ✅ Access Ollama from anywhere (not just same WiFi)
- ✅ Secure end-to-end encryption
- ✅ Easy setup (15 minutes)
- ✅ Free for personal use (up to 100 devices)
- ✅ Works with cellular data
- ✅ No port forwarding needed
- ✅ No router configuration needed

---

## Setup Instructions

### Part 1: Install on Your Mac

**1. Install Tailscale:**

```bash
# Using Homebrew (recommended)
brew install tailscale

# Or download from: https://tailscale.com/download/mac
```

**2. Start Tailscale:**

```bash
# Start and authenticate
sudo tailscale up

# This will open a browser window
# Sign in with your preferred account:
# - Google
# - Microsoft
# - GitHub
# - Email
```

**3. Get your Mac's Tailscale IP:**

```bash
tailscale ip -4
```

**Example output:**
```
100.115.92.45
```

**Copy this IP address** - you'll need it later!

**4. Verify Tailscale is running:**

```bash
tailscale status
```

Should show your Mac connected.

**5. (Optional) Set a nice hostname:**

```bash
# Makes it easier to remember
# Mac will be accessible as: macbook.tail-xxxxx.ts.net
sudo tailscale set --hostname macbook
```

---

### Part 2: Configure Ollama

**Important:** Ollama must listen on all interfaces for Tailscale to work.

**1. Set OLLAMA_HOST:**

```bash
export OLLAMA_HOST=0.0.0.0:11434
```

**2. Start Ollama:**

```bash
ollama serve
```

**Keep this terminal window open!**

**3. Test from Mac (local):**

```bash
curl http://localhost:11434/api/tags
```

Should return JSON with your models.

**4. Test from Mac (Tailscale IP):**

```bash
# Use YOUR Tailscale IP from step 3
curl http://100.115.92.45:11434/api/tags
```

Should return the same JSON. If this works, you're ready for iPhone!

---

### Part 3: Install on iPhone

**1. Install Tailscale App:**
- Open App Store
- Search "Tailscale"
- Install the app

**2. Sign in:**
- Open Tailscale app
- Tap "Sign in"
- Use the **same account** as your Mac
- Approve any authentication prompts

**3. Enable the VPN:**
- Tailscale will ask to add VPN configuration
- Tap "Allow"
- Enter your passcode/Face ID
- Toggle the connection ON (should turn green)

**4. Verify connection:**
- In Tailscale app, you should see:
  - Your Mac (online)
  - Your iPhone (this device)
- Both should show green indicators

---

### Part 4: Configure Your iOS App

**1. Open your learning app**

**2. Go to Profile Tab**

**3. Scroll to Network Settings**

**4. Enter your Mac's Tailscale IP:**
- Tap "Edit" or "Set Now"
- Enter the IP from Step 1.3 (e.g., `100.115.92.45`)
- Tap "Save"

**5. Test the connection:**
- Tap "Test Connection"
- Should show ✅ "Connected"

**6. Try generating content:**
- Go to Tasks tab
- Open any task
- Content should generate successfully!

---

## Making It Permanent

### Auto-start Tailscale on Mac Boot

**Option A - Using Tailscale Menu Bar:**
1. Click Tailscale icon in menu bar
2. Preferences
3. Check "Launch at Login"

**Option B - Command Line:**
```bash
sudo tailscale set --auto-update
```

### Keep OLLAMA_HOST Permanent

**Add to your shell profile:**

```bash
# For zsh (default on macOS)
echo 'export OLLAMA_HOST=0.0.0.0:11434' >> ~/.zshrc
source ~/.zshrc

# For bash
echo 'export OLLAMA_HOST=0.0.0.0:11434' >> ~/.bash_profile
source ~/.bash_profile
```

Now you can just run `ollama serve` anytime!

### Auto-start Ollama on Mac Boot

**Option A - LaunchAgent (Recommended):**

Create: `~/Library/LaunchAgents/com.ollama.server.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.ollama.server</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/ollama</string>
        <string>serve</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>OLLAMA_HOST</key>
        <string>0.0.0.0:11434</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/ollama.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/ollama.error.log</string>
</dict>
</plist>
```

**Load it:**
```bash
launchctl load ~/Library/LaunchAgents/com.ollama.server.plist
```

**Option B - Simple startup script:**

Create `~/start_ollama.sh`:
```bash
#!/bin/bash
export OLLAMA_HOST=0.0.0.0:11434
/usr/local/bin/ollama serve
```

Make executable:
```bash
chmod +x ~/start_ollama.sh
```

Add to System Preferences > Users & Groups > Login Items

---

## Testing Your Setup

### Quick Test Checklist

**On your Mac:**
- [ ] Tailscale is running: `tailscale status`
- [ ] Ollama is running: `curl http://localhost:11434/api/tags`
- [ ] Ollama accessible via Tailscale: `curl http://YOUR_TAILSCALE_IP:11434/api/tags`

**On your iPhone:**
- [ ] Tailscale app shows connected (green)
- [ ] Can see your Mac in Tailscale app
- [ ] iOS app > Profile > Network Settings shows Tailscale IP
- [ ] Test Connection shows ✅ Connected
- [ ] Can open a task and see content generate

### Test from Different Networks

**1. Home WiFi:**
- iPhone on home WiFi
- Open app
- Generate content
- Should work ✅

**2. Cellular Data:**
- Turn off WiFi on iPhone
- Open app
- Generate content
- Should work ✅ (from anywhere!)

**3. Coffee Shop WiFi:**
- Connect to public WiFi
- Open app
- Generate content
- Should work ✅

---

## Troubleshooting

### Problem: "Cannot connect" on iPhone

**Solution 1 - Check Tailscale is connected:**
```
Open Tailscale app
Both devices should show green indicators
```

**Solution 2 - Verify IP hasn't changed:**
```bash
# On Mac
tailscale ip -4
# Update in iOS app if different
```

**Solution 3 - Restart Tailscale on iPhone:**
```
Toggle connection OFF then ON in Tailscale app
Wait 10 seconds
Try again
```

### Problem: Tailscale connected but Ollama fails

**Check OLLAMA_HOST:**
```bash
echo $OLLAMA_HOST
# Should show: 0.0.0.0:11434
```

**Test Ollama is accessible:**
```bash
# Replace with YOUR Tailscale IP
curl http://100.115.92.45:11434/api/tags
```

If curl fails, Ollama isn't configured correctly.

### Problem: Works on WiFi but not cellular

**Check cellular data for Tailscale:**
1. iPhone Settings
2. Cellular
3. Scroll to Tailscale
4. Enable cellular data

### Problem: Slow generation on cellular

**Normal!** Cellular upload speeds are slower than WiFi.

**Tips:**
- Use WiFi when possible for faster generation
- Cellular works but may take 2-3x longer
- Model responses are text-based (small data)
- Initial content generation may be slower

---

## Advanced Configuration

### Using MagicDNS (Easier than IP addresses)

**Enable MagicDNS:**
1. Go to https://login.tailscale.com/admin/dns
2. Enable MagicDNS
3. Your Mac becomes: `macbook.tail-xxxxx.ts.net`

**In your iOS app:**
- Instead of IP: `100.115.92.45`
- Use hostname: `macbook.tail-xxxxx.ts.net`
- No need to update if IP changes!

### Multiple Macs

If you have multiple Macs running Ollama:

**Mac 1:** `macbook-work.tail-xxxxx.ts.net`
**Mac 2:** `macbook-home.tail-xxxxx.ts.net`

Switch between them in Network Settings!

### Access Control

**Limit which devices can access:**
1. Go to https://login.tailscale.com/admin/machines
2. Click on your Mac
3. Enable "Subnet routes" or ACLs as needed

---

## Security Notes

### Is it secure?

**Yes!** Tailscale provides:
- ✅ WireGuard encryption (military-grade)
- ✅ End-to-end encryption
- ✅ Zero-trust network architecture
- ✅ Only your devices can connect
- ✅ No open ports on your router
- ✅ Secure key exchange

### Best Practices

1. **Use strong account:** Use 2FA on your Tailscale account
2. **Device management:** Remove old devices you no longer use
3. **Keep updated:** Update Tailscale app regularly
4. **Firewall:** macOS firewall can stay enabled
5. **No port forwarding:** Never needed with Tailscale

---

## Cost

**Free Tier (Personal):**
- Up to 100 devices
- All features included
- Perfect for personal use
- No credit card needed

**Paid Plans:**
- If you need more features
- Starting at $5/month
- Not needed for this use case

---

## Alternative: Tailscale + RAG Server

If you're also running the RAG server on port 8000:

**It automatically works!** The app already uses the same IP for both:
- Ollama: `100.115.92.45:11434`
- RAG: `100.115.92.45:8000`

Just make sure RAG server is also listening on `0.0.0.0`:
```bash
# In your RAG server config
HOST=0.0.0.0 python rag_service.py
```

---

## Summary

Once set up, you can:
- 🏠 Use app at home (same as before)
- ☕ Use app at coffee shops
- 📱 Use app on cellular data
- ✈️ Use app while traveling
- 🌍 Use app from anywhere in the world

All with the same secure, encrypted connection to your Mac!

**Key Points:**
1. Install Tailscale on both devices
2. Sign in with same account
3. Get Mac's Tailscale IP: `tailscale ip -4`
4. Configure Ollama: `OLLAMA_HOST=0.0.0.0:11434`
5. Enter Tailscale IP in iOS app
6. Works everywhere! 🚀

---

## Quick Reference

### Mac Commands
```bash
# Get Tailscale IP
tailscale ip -4

# Check Tailscale status
tailscale status

# Restart Tailscale
sudo tailscale down && sudo tailscale up

# Start Ollama with network access
export OLLAMA_HOST=0.0.0.0:11434
ollama serve
```

### iPhone
- Tailscale app: Toggle VPN on
- Your app: Profile > Network Settings
- Enter: Mac's Tailscale IP
- Test Connection: Should show ✅

### Support
- Tailscale docs: https://tailscale.com/kb
- Tailscale forum: https://forum.tailscale.com
- Your app logs: Check Xcode console for debugging

---

**Ready to set up? Start with Step 1!** 🎉
