#!/bin/bash

# Grant Platform MVP Setup Script
# Uses SQLite instead of PostgreSQL for simpler setup

set -e  # Exit on error

echo "🚀 Setting up Grant Platform MVP..."
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Base directory
BASE_DIR="$HOME/Desktop/grant_platform_services"
DB_DIR="$BASE_DIR/databases"

echo -e "${BLUE}Step 1: Creating directory structure...${NC}"
mkdir -p "$BASE_DIR"
mkdir -p "$DB_DIR"
cd "$BASE_DIR"

echo -e "${GREEN}✓ Directories created${NC}"
echo ""

echo -e "${BLUE}Step 2: Setting up Python virtual environment...${NC}"
if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo -e "${GREEN}✓ Virtual environment created${NC}"
else
    echo -e "${YELLOW}⚠ Virtual environment already exists${NC}"
fi

# Activate virtual environment
source venv/bin/activate

echo ""
echo -e "${BLUE}Step 3: Installing Python dependencies...${NC}"
pip install --upgrade pip > /dev/null 2>&1

cat > requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn[standard]==0.24.0
sqlalchemy==2.0.23
chromadb==0.4.18
ollama==0.1.6
pydantic==2.5.0
playwright==1.40.0
pypdf==3.17.0
pdfplumber==0.10.3
python-multipart==0.0.6
scikit-learn==1.3.2
sentence-transformers==2.2.2
aiosqlite==0.19.0
httpx==0.25.2
EOF

pip install -r requirements.txt
echo -e "${GREEN}✓ Dependencies installed${NC}"

echo ""
echo -e "${BLUE}Step 4: Installing Playwright browsers...${NC}"
playwright install chromium
echo -e "${GREEN}✓ Playwright installed${NC}"

echo ""
echo -e "${BLUE}Step 5: Checking Ollama installation...${NC}"
if command -v ollama &> /dev/null; then
    echo -e "${GREEN}✓ Ollama is installed${NC}"

    # Check if Ollama is running
    if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Ollama is running${NC}"
    else
        echo -e "${YELLOW}⚠ Ollama is not running. Starting it...${NC}"
        echo "Run in another terminal: ollama serve"
    fi

    # Check for required models
    echo -e "${BLUE}Checking for required models...${NC}"
    if ollama list | grep -q "llama3.2:3b"; then
        echo -e "${GREEN}✓ llama3.2:3b is installed${NC}"
    else
        echo -e "${YELLOW}⚠ Pulling llama3.2:3b (this may take a few minutes)...${NC}"
        ollama pull llama3.2:3b
    fi
else
    echo -e "${YELLOW}⚠ Ollama is not installed${NC}"
    echo "Install from: https://ollama.ai"
fi

echo ""
echo -e "${GREEN}✅ Setup complete!${NC}"
echo ""
echo -e "${BLUE}Directory structure:${NC}"
echo "  $BASE_DIR/"
echo "    ├── venv/              (Python virtual environment)"
echo "    ├── databases/         (SQLite databases)"
echo "    ├── services/          (FastAPI services - create next)"
echo "    └── requirements.txt"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Activate environment: source $BASE_DIR/venv/bin/activate"
echo "  2. Create service files (I'll help with this)"
echo "  3. Run the server: uvicorn main:app --reload"
echo ""
echo -e "${YELLOW}Note: If you need PostgreSQL later, we can migrate from SQLite${NC}"
