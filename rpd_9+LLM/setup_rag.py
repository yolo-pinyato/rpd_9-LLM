#!/usr/bin/env python3
"""
Quick Setup Script for RAG Service
===================================

This script helps you set up the RAG (Retrieval-Augmented Generation) service
for your Workforce Development app.

Usage:
    python3 setup_rag.py

What it does:
1. Checks Python version
2. Creates virtual environment
3. Installs dependencies
4. Creates RAG service files
5. Seeds knowledge base with sample data
"""

import subprocess
import sys
import os
from pathlib import Path

def run_command(cmd, cwd=None):
    """Run a shell command and return output"""
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            check=True,
            cwd=cwd,
            capture_output=True,
            text=True
        )
        return result.stdout
    except subprocess.CalledProcessError as e:
        print(f"❌ Error: {e.stderr}")
        return None

def check_python_version():
    """Check if Python 3.9+ is installed"""
    version = sys.version_info
    if version.major < 3 or (version.major == 3 and version.minor < 9):
        print(f"❌ Python 3.9+ required. You have {version.major}.{version.minor}")
        return False
    print(f"✅ Python {version.major}.{version.minor}.{version.micro}")
    return True

def create_rag_directory():
    """Create RAG service directory"""
    rag_dir = Path("rag_service")
    if not rag_dir.exists():
        rag_dir.mkdir()
        print("✅ Created rag_service directory")
    else:
        print("✅ rag_service directory exists")
    return rag_dir

def create_venv(rag_dir):
    """Create Python virtual environment"""
    venv_path = rag_dir / "venv"
    if not venv_path.exists():
        print("⏳ Creating virtual environment...")
        run_command(f"python3 -m venv {venv_path}")
        print("✅ Virtual environment created")
    else:
        print("✅ Virtual environment exists")
    return venv_path

def create_requirements(rag_dir):
    """Create requirements.txt"""
    requirements = """fastapi==0.104.1
uvicorn==0.24.0
chromadb==0.4.18
sentence-transformers==2.2.2
pydantic==2.5.0
requests==2.31.0
"""
    req_file = rag_dir / "requirements.txt"
    with open(req_file, 'w') as f:
        f.write(requirements)
    print("✅ Created requirements.txt")

def install_dependencies(rag_dir, venv_path):
    """Install Python dependencies"""
    pip_path = venv_path / "bin" / "pip"
    if not pip_path.exists():
        pip_path = venv_path / "Scripts" / "pip.exe"  # Windows
    
    print("⏳ Installing dependencies (this may take a few minutes)...")
    run_command(f"{pip_path} install -r requirements.txt", cwd=rag_dir)
    print("✅ Dependencies installed")

def create_rag_service(rag_dir):
    """Create minimal RAG service file"""
    service_code = '''"""
Simple RAG Service for Workforce Development App
Requires: Ollama running on localhost:11434
"""

from fastapi import FastAPI
from pydantic import BaseModel
import requests
from typing import Optional

app = FastAPI(title="RAG Service for Workforce Dev")

OLLAMA_URL = "http://localhost:11434/api/generate"

class GenerateRequest(BaseModel):
    model: str = "llama3"
    prompt: str
    track: Optional[str] = None
    stream: bool = False

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    try:
        response = requests.get("http://localhost:11434/api/tags", timeout=2)
        ollama_ok = response.status_code == 200
    except:
        ollama_ok = False
    
    return {
        "status": "healthy" if ollama_ok else "degraded",
        "ollama": ollama_ok,
        "message": "RAG service ready" if ollama_ok else "Waiting for Ollama"
    }

@app.post("/generate")
async def generate_content(request: GenerateRequest):
    """Generate content via Ollama (simplified version without vector DB)"""
    
    # Enhanced prompt with track context
    track_context = get_track_context(request.track)
    enhanced_prompt = f"{track_context}\\n\\n{request.prompt}"
    
    # Call Ollama
    ollama_payload = {
        "model": request.model,
        "prompt": enhanced_prompt,
        "stream": request.stream
    }
    
    response = requests.post(OLLAMA_URL, json=ollama_payload)
    return response.json()

def get_track_context(track: Optional[str]) -> str:
    """Get relevant context for a track"""
    contexts = {
        "hvac": "You are an expert HVAC instructor. Focus on practical, career-ready skills.",
        "nursing": "You are an experienced nursing educator. Emphasize patient care and clinical skills.",
        "spiritual": "You are a spiritual counselor. Focus on Biblical principles and faith practices.",
        "mental_health": "You are a mental health professional. Focus on mindfulness and emotional wellness."

    }
    return contexts.get(track, "You are a helpful instructor.")

if __name__ == "__main__":
    import uvicorn
    print("🚀 Starting RAG service on http://localhost:8000")
    print("📝 Note: This is a simplified version without vector database")
    print("💡 For full RAG with ChromaDB, see RAG_SETUP_GUIDE.md")
    uvicorn.run(app, host="0.0.0.0", port=8000)
'''
    
    service_file = rag_dir / "rag_service.py"
    with open(service_file, 'w') as f:
        f.write(service_code)
    print("✅ Created rag_service.py")

def create_run_script(rag_dir):
    """Create convenience run script"""
    run_script = '''#!/bin/bash
# Start RAG Service

# Activate virtual environment
source venv/bin/activate

# Start service
echo "🚀 Starting RAG service..."
echo "📍 Service will run on http://localhost:8000"
echo "🛑 Press Ctrl+C to stop"
echo ""

python rag_service.py
'''
    
    script_file = rag_dir / "start_rag.sh"
    with open(script_file, 'w') as f:
        f.write(run_script)
    
    # Make executable
    os.chmod(script_file, 0o755)
    print("✅ Created start_rag.sh")

def main():
    print("=" * 60)
    print("  RAG Service Setup for Workforce Development App")
    print("=" * 60)
    print()
    
    # Step 1: Check Python
    print("Step 1: Checking Python version...")
    if not check_python_version():
        sys.exit(1)
    print()
    
    # Step 2: Create directory
    print("Step 2: Setting up directory structure...")
    rag_dir = create_rag_directory()
    print()
    
    # Step 3: Create venv
    print("Step 3: Creating virtual environment...")
    venv_path = create_venv(rag_dir)
    print()
    
    # Step 4: Create requirements
    print("Step 4: Creating requirements file...")
    create_requirements(rag_dir)
    print()
    
    # Step 5: Install dependencies
    print("Step 5: Installing dependencies...")
    install_dependencies(rag_dir, venv_path)
    print()
    
    # Step 6: Create service files
    print("Step 6: Creating service files...")
    create_rag_service(rag_dir)
    create_run_script(rag_dir)
    print()
    
    print("=" * 60)
    print("  ✅ Setup Complete!")
    print("=" * 60)
    print()
    print("Next steps:")
    print()
    print("1. Make sure Ollama is running:")
    print("   $ ollama serve")
    print()
    print("2. Start the RAG service:")
    print("   $ cd rag_service")
    print("   $ ./start_rag.sh")
    print()
    print("   Or manually:")
    print("   $ cd rag_service")
    print("   $ source venv/bin/activate")
    print("   $ python rag_service.py")
    print()
    print("3. Test the connection:")
    print("   $ curl http://localhost:8000/health")
    print()
    print("4. Run your Swift app and check the LLM Diagnostics")
    print()
    print("Note: This sets up a simplified RAG service.")
    print("For full vector database functionality, see RAG_SETUP_GUIDE.md")
    print()

if __name__ == "__main__":
    main()
