#!/usr/bin/env python3
"""
Check Status of All Services
Quickly verify what's running and what's not
"""

import requests
import sys

def check_service(name, url, timeout=2):
    """Check if a service is responding"""
    try:
        response = requests.get(url, timeout=timeout)
        if response.status_code == 200:
            print(f"✅ {name}: Running")
            return True
        else:
            print(f"⚠️  {name}: Responded with status {response.status_code}")
            return False
    except requests.exceptions.ConnectionError:
        print(f"❌ {name}: Not running")
        return False
    except requests.exceptions.Timeout:
        print(f"⏱️  {name}: Timeout (service may be slow)")
        return False
    except Exception as e:
        print(f"❌ {name}: Error ({str(e)})")
        return False

def get_ollama_models():
    """Get list of available Ollama models"""
    try:
        response = requests.get("http://localhost:11434/api/tags", timeout=5)
        if response.status_code == 200:
            data = response.json()
            models = data.get('models', [])
            if models:
                print("\n📦 Available Ollama Models:")
                for model in models:
                    name = model.get('name', 'unknown')
                    size = model.get('size', 0) / (1024**3)  # Convert to GB
                    print(f"   • {name} ({size:.1f} GB)")
            else:
                print("\n⚠️  No Ollama models found. Run: ollama pull llama3")
    except:
        pass

def get_rag_stats():
    """Get RAG service statistics"""
    try:
        response = requests.get("http://localhost:8000/health", timeout=2)
        if response.status_code == 200:
            data = response.json()
            print(f"\n🔍 RAG Service Details:")
            print(f"   Status: {data.get('status', 'unknown')}")
            if 'collections' in data:
                print(f"   Knowledge Base:")
                for track, count in data['collections'].items():
                    print(f"      • {track}: {count} documents")
    except:
        pass

def main():
    print("=" * 60)
    print("  Service Status Check")
    print("=" * 60)
    print()
    
    # Check Ollama
    print("Core Services:")
    ollama_running = check_service(
        "Ollama", 
        "http://localhost:11434/api/tags"
    )
    
    # Check RAG
    rag_running = check_service(
        "RAG Service", 
        "http://localhost:8000/health"
    )
    
    print()
    print("-" * 60)
    
    # Get details
    if ollama_running:
        get_ollama_models()
    
    if rag_running:
        get_rag_stats()
    
    print()
    print("-" * 60)
    print()
    
    # Summary and recommendations
    print("Summary:")
    print()
    
    if ollama_running and rag_running:
        print("🎉 All services running! Your app has full functionality.")
        print()
        print("Next steps:")
        print("  • Run your Swift app")
        print("  • Check 'LLM Diagnostics' tab")
        print("  • Try generating learning content")
    
    elif ollama_running and not rag_running:
        print("✅ Ollama is running - your app will work!")
        print("ℹ️  RAG service is optional for enhanced content.")
        print()
        print("To enable RAG:")
        print("  • cd rag_service")
        print("  • ./start_rag.sh")
        print()
        print("Or continue using direct Ollama generation (works great!)")
    
    elif not ollama_running and rag_running:
        print("⚠️  RAG is running but Ollama is not.")
        print()
        print("Start Ollama:")
        print("  • Open Terminal")
        print("  • Run: ollama serve")
    
    else:
        print("❌ No services are running.")
        print()
        print("To get started:")
        print()
        print("1. Start Ollama:")
        print("   $ ollama serve")
        print()
        print("2. Pull a model (in another terminal):")
        print("   $ ollama pull llama3")
        print()
        print("3. (Optional) Start RAG service:")
        print("   $ cd rag_service")
        print("   $ ./start_rag.sh")
        print()
        print("4. Run your Swift app!")
    
    print()
    print("For more help:")
    print("  • See RAG_QUICK_START.md")
    print("  • Check 'LLM Diagnostics' in your app")
    print()

if __name__ == "__main__":
    main()
