#!/bin/bash

echo "=========================================="
echo "Ollama Auto-Start Setup"
echo "=========================================="
echo ""

PLIST_PATH="$HOME/Library/LaunchAgents/com.ollama.server.plist"

# Check if Ollama is installed
if ! command -v ollama &> /dev/null; then
    echo "❌ Ollama not found. Install it first:"
    echo "   curl https://ollama.ai/install.sh | sh"
    exit 1
fi

# Get ollama path
OLLAMA_PATH=$(which ollama)

echo "Creating LaunchAgent plist file..."
echo ""

# Create the LaunchAgent directory if it doesn't exist
mkdir -p "$HOME/Library/LaunchAgents"

# Create the plist file
cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.ollama.server</string>
    <key>ProgramArguments</key>
    <array>
        <string>$OLLAMA_PATH</string>
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
EOF

echo "✅ Created: $PLIST_PATH"
echo ""

# Unload if already loaded
launchctl unload "$PLIST_PATH" 2>/dev/null

# Load the plist
echo "Loading LaunchAgent..."
launchctl load "$PLIST_PATH"

if [ $? -eq 0 ]; then
    echo "✅ LaunchAgent loaded successfully"
    echo ""

    # Wait a moment for it to start
    sleep 2

    # Test if Ollama is running
    if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
        echo "✅ Ollama is now running!"
    else
        echo "⚠️  LaunchAgent loaded, but Ollama isn't responding yet"
        echo "   It may take a moment to start"
        echo "   Check logs: tail -f /tmp/ollama.log"
    fi
else
    echo "❌ Failed to load LaunchAgent"
    exit 1
fi

echo ""
echo "=========================================="
echo "✅ Setup Complete!"
echo "=========================================="
echo ""
echo "Ollama will now:"
echo "  • Start automatically when you log in"
echo "  • Restart if it crashes"
echo "  • Listen on 0.0.0.0:11434 (accessible from network)"
echo ""
echo "Useful Commands:"
echo "  • View logs: tail -f /tmp/ollama.log"
echo "  • Stop: launchctl unload $PLIST_PATH"
echo "  • Start: launchctl load $PLIST_PATH"
echo "  • Restart: launchctl kickstart -k gui/\$(id -u)/com.ollama.server"
echo ""
echo "To uninstall auto-start:"
echo "  launchctl unload $PLIST_PATH"
echo "  rm $PLIST_PATH"
echo ""
echo "=========================================="
