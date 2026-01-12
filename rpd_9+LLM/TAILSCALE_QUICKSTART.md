# Tailscale Quick Start - 5 Minutes

## On Your Mac

**1. Run the setup script:**
```bash
cd "/Users/chris/Desktop/RPD Apple Tests/rpd_9+LLM/rpd_9+LLM"
./setup_tailscale.sh
```

This will:
- Install Tailscale (if needed)
- Start Tailscale
- Show you your Tailscale IP

**2. Make OLLAMA_HOST permanent:**
```bash
echo 'export OLLAMA_HOST=0.0.0.0:11434' >> ~/.zshrc
source ~/.zshrc
```

**3. Start Ollama:**
```bash
ollama serve
```

**4. (Optional) Auto-start Ollama on boot:**
```bash
./setup_ollama_autostart.sh
```

---

## On Your iPhone

**1. Install Tailscale:**
- Open App Store
- Search "Tailscale"
- Install

**2. Sign in:**
- Open Tailscale app
- Sign in with **same account** as Mac
- Enable VPN (toggle to ON)

**3. Configure your learning app:**
- Open app
- Profile tab
- Network Settings
- Enter your Mac's Tailscale IP (from step 1)
- Save
- Test Connection → ✅

---

## That's It!

Your app now works from anywhere:
- ✅ Home WiFi
- ✅ Coffee shop WiFi
- ✅ Cellular data
- ✅ Anywhere in the world

---

## Quick Commands

**Get your Tailscale IP:**
```bash
tailscale ip -4
```

**Check Tailscale status:**
```bash
tailscale status
```

**Test Ollama:**
```bash
curl http://localhost:11434/api/tags
```

**View Ollama logs (if using autostart):**
```bash
tail -f /tmp/ollama.log
```

---

## Troubleshooting

**Connection fails:**
1. Check Tailscale is running on both devices
2. Verify IP: `tailscale ip -4`
3. Test: `curl http://YOUR_IP:11434/api/tags`
4. Update IP in iOS app if changed

**Need help?**
See full guide: `TAILSCALE_SETUP.md`
