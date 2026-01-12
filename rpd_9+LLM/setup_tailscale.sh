#!/bin/bash

echo "=========================================="
echo "Tailscale + Ollama Setup Helper"
echo "=========================================="
echo ""

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "❌ Homebrew not found. Install it first:"
    echo "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    exit 1
fi

echo "✅ Homebrew found"
echo ""

# Check if Tailscale is installed
if ! command -v tailscale &> /dev/null; then
    echo "📦 Installing Tailscale..."
    brew install tailscale
    echo ""
else
    echo "✅ Tailscale already installed"
    echo ""
fi

# Check if Ollama is installed
if ! command -v ollama &> /dev/null; then
    echo "❌ Ollama not found. Install it first:"
    echo "   curl https://ollama.ai/install.sh | sh"
    exit 1
fi

echo "✅ Ollama found"
echo ""

# Check if Tailscale is running
if ! sudo tailscale status &> /dev/null; then
    echo "🚀 Starting Tailscale..."
    echo "   This will open a browser window for authentication"
    echo "   Sign in with your preferred account"
    echo ""
    read -p "Press Enter to continue..."
    sudo tailscale up
    echo ""
else
    echo "✅ Tailscale is running"
    echo ""
fi

# Get Tailscale IP
TAILSCALE_IP=$(tailscale ip -4)
if [ -z "$TAILSCALE_IP" ]; then
    echo "❌ Could not get Tailscale IP. Make sure Tailscale is connected."
    exit 1
fi

echo "=========================================="
echo "✅ Setup Complete!"
echo "=========================================="
echo ""
echo "Your Mac's Tailscale IP: $TAILSCALE_IP"
echo ""
echo "Next Steps:"
echo ""
echo "1. ADD TO YOUR SHELL PROFILE (makes OLLAMA_HOST permanent):"
echo "   echo 'export OLLAMA_HOST=0.0.0.0:11434' >> ~/.zshrc"
echo "   source ~/.zshrc"
echo ""
echo "2. START OLLAMA:"
echo "   export OLLAMA_HOST=0.0.0.0:11434"
echo "   ollama serve"
echo ""
echo "3. ON YOUR IPHONE:"
echo "   - Install Tailscale app from App Store"
echo "   - Sign in with same account"
echo "   - Enable VPN"
echo "   - Open your learning app"
echo "   - Go to Profile > Network Settings"
echo "   - Enter this IP: $TAILSCALE_IP"
echo "   - Tap Save and Test Connection"
echo ""
echo "4. TEST FROM THIS MAC:"
echo "   curl http://$TAILSCALE_IP:11434/api/tags"
echo ""
echo "=========================================="
echo "Want to auto-start Ollama on boot?"
echo "Run: ./setup_ollama_autostart.sh"
echo "=========================================="
