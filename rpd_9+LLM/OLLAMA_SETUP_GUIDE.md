# Ollama Setup Guide for Workforce Development App

## Overview
This guide will help you set up Ollama (local LLM) to power the AI-generated learning content in your workforce development app.

## Prerequisites
- macOS 11.0+ (for Mac)
- At least 8GB RAM (16GB+ recommended)
- 10GB free disk space per model

## Installation Steps

### 1. Install Ollama

**Option A: Using Homebrew (Recommended)**
```bash
brew install ollama
```

**Option B: Direct Download**
1. Visit [ollama.ai](https://ollama.ai)
2. Download the macOS installer
3. Run the installer

### 2. Verify Installation
```bash
ollama --version
```

You should see the version number printed.

### 3. Start Ollama Service

**In Terminal, run:**
```bash
ollama serve
```

Keep this terminal window open! The service needs to run while your app is using it.

**Expected output:**
```
Ollama is running on http://localhost:11434
```

### 4. Pull a Model

Open a **new terminal window** (keep `ollama serve` running in the other) and run:

**For testing with smaller models:**
```bash
ollama pull llama2
```

**For this app (recommended - gpt-oss:20b):**
```bash
ollama pull gpt-oss:20b
```

**Alternative models:**
```bash
ollama pull llama2    # Smaller, faster for testing
ollama pull llama3    # Good balance
ollama pull mistral   # Alternative option
```

### 5. Test the Model

```bash
ollama run gpt-oss:20b "Explain HVAC basics in 3 sentences"
```

You should see a response generated.

## Updating Your App Configuration

The app is pre-configured to use `gpt-oss:20b` as the default model.

If you want to use a different model, update the model name in `OllamaService.swift`:

```swift
// Around line 56 in OllamaService.swift
func generateContent(prompt: String, model: String = "gpt-oss:20b", ...) 
// Change "gpt-oss:20b" to your preferred model name
```

## Common Issues & Solutions

### Issue 1: "Cannot connect to Ollama"

**Solution:**
1. Make sure Ollama is running:
   ```bash
   ollama serve
   ```
2. Check if the service is accessible:
   ```bash
   curl http://localhost:11434/api/tags
   ```
3. If port 11434 is in use, stop other services using it

### Issue 2: "Model not found"

**Solution:**
1. List available models:
   ```bash
   ollama list
   ```
2. Pull the required model:
   ```bash
   ollama pull gpt-oss:20b
   ```

### Issue 3: Generation is very slow

**Solutions:**
1. Use a smaller model (llama2 instead of llama3)
2. Close other memory-intensive apps
3. Consider using a machine with more RAM
4. Adjust timeout in `OllamaService.swift` (line ~198):
   ```swift
   request.timeoutInterval = 180 // Increase from 120 to 180 seconds
   ```

### Issue 4: App says "Service not running" but Ollama is running

**Solution:**
1. Restart Ollama:
   ```bash
   # Press Ctrl+C in the terminal running ollama serve
   ollama serve
   ```
2. Check firewall settings - ensure localhost connections are allowed
3. Try accessing from browser: http://localhost:11434

## Using the LLM Diagnostics Tool

Your app includes a built-in diagnostics tool:

1. Open the app
2. Go to **Admin** tab (you may need to set `isAdmin` to `true` in your user record)
3. Tap **"LLM Diagnostics"**
4. Tap **"Refresh Status"** to check connection

The diagnostics will show:
- ✅ Ollama Status: Connected or Not Running
- Available Models: List of downloaded models
- Setup Instructions: Quick reference

## Recommended Models for This App

| Model | Size | Speed | Quality | Best For |
|-------|------|-------|---------|----------|
| **gpt-oss:20b** | ~12GB | Medium | Excellent | **Default for this app** |
| llama2 | 3.8GB | Fast | Good | Testing, development |
| llama3 | 4.7GB | Medium | Better | Alternative option |
| mistral | 4.1GB | Medium | Better | Alternative option |
| codellama | 3.8GB | Fast | Specialized | Code examples |

**Note:** The app is pre-configured to use `gpt-oss:20b`. Make sure you have sufficient RAM (16GB+ recommended).

## Running Ollama Automatically

### Option 1: Launch on System Startup (macOS)

Create a launch agent:

```bash
# Create the plist file
mkdir -p ~/Library/LaunchAgents
cat > ~/Library/LaunchAgents/com.ollama.server.plist << EOF
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
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF

# Load the launch agent
launchctl load ~/Library/LaunchAgents/com.ollama.server.plist
```

### Option 2: Create a Shortcut Script

Create a file `start-ollama.sh`:

```bash
#!/bin/bash
echo "Starting Ollama service..."
ollama serve
```

Make it executable:
```bash
chmod +x start-ollama.sh
```

Run it:
```bash
./start-ollama.sh
```

## Performance Tips

### 1. Free up RAM
Close unnecessary applications before using AI features

### 2. Use Metal Acceleration (macOS)
Ollama automatically uses Metal on Apple Silicon for better performance

### 3. Batch Multiple Requests
Instead of generating content one task at a time, consider generating multiple at once

### 4. Cache Responses
Consider storing generated content in the database to avoid regenerating

## Testing Without Ollama

If you want to test the app without setting up Ollama:

1. Open `rpd_9_LLMApp.swift`
2. Find the `loadLearningContent()` function
3. Replace with mock content:

```swift
private func loadLearningContent() {
    // Mock content for testing
    learningContent = """
    # \(task.title)
    
    ## Introduction
    This is sample content for \(task.description).
    
    ## Key Concepts
    1. Core concept one
    2. Core concept two
    3. Core concept three
    
    ## Practice Tips
    - Start with the basics
    - Practice regularly
    - Ask questions when unsure
    
    [AI content will appear here when Ollama is running]
    """
    isLoadingContent = false
}
```

## Alternative: Using OpenAI API Instead

If local LLM setup is too complex, you can modify the app to use OpenAI's API:

1. Get an API key from platform.openai.com
2. Update `OllamaService.swift` to use OpenAI endpoint
3. Replace the URL and add authentication header

**Note:** This will require internet and incur API costs, but removes local setup requirements.

## Next Steps

Once Ollama is running:

1. ✅ Check connection in LLM Diagnostics
2. ✅ Select a learning track in the app
3. ✅ Open a task to see AI-generated content
4. ✅ Complete tasks to earn points

## Support & Resources

- **Ollama Documentation:** https://github.com/ollama/ollama
- **Model Library:** https://ollama.ai/library
- **Discord Community:** https://discord.gg/ollama

## Troubleshooting Checklist

- [ ] Ollama is installed (`ollama --version` works)
- [ ] Ollama service is running (`ollama serve`)
- [ ] At least one model is downloaded (`ollama list`)
- [ ] Port 11434 is accessible (try in browser)
- [ ] No firewall blocking localhost connections
- [ ] App shows "Connected ✅" in LLM Diagnostics
- [ ] Sample generation works in terminal

---

**Still having issues?** Check the console logs in Xcode for detailed error messages, or review the error display in the app's task detail view.
