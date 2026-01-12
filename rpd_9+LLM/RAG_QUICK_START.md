# RAG Service - Quick Start

## What's Happening?

Your app can generate learning content **with or without** the RAG (Retrieval-Augmented Generation) service:

- ✅ **Without RAG**: Uses Ollama directly (works great, just needs `ollama serve`)
- ✅ **With RAG**: Enhanced with custom knowledge base (optional upgrade)

## Current Status

Your app is configured to **automatically detect** if RAG is available:

```swift
// From TaskDetailView
let ragAvailable = await OllamaService.shared.checkRAGConnection()
let content = try await OllamaService.shared.generateTrackContent(
    // ...
    useRAG: ragAvailable  // ✨ Auto-detects RAG
)
```

## Quick Start (No RAG)

**Just want to get started? Here's all you need:**

1. **Start Ollama:**
   ```bash
   ollama serve
   ```

2. **Pull a model:**
   ```bash
   ollama pull llama3
   # or
   ollama pull mistral
   ```

3. **Run your app!** 🎉

The app will work perfectly using direct Ollama generation.

## Setting Up RAG (Optional)

**Want enhanced content with custom knowledge? Follow these steps:**

### Option A: Quick Setup (Recommended)

```bash
# Run the setup script
python3 setup_rag.py

# Start RAG service
cd rag_service
./start_rag.sh
```

### Option B: Manual Setup

1. **Create virtual environment:**
   ```bash
   mkdir rag_service
   cd rag_service
   python3 -m venv venv
   source venv/bin/activate
   ```

2. **Install dependencies:**
   ```bash
   pip install fastapi uvicorn chromadb sentence-transformers
   ```

3. **Create `rag_service.py`** (see setup_rag.py output)

4. **Start service:**
   ```bash
   python rag_service.py
   ```

5. **Verify it's working:**
   ```bash
   curl http://localhost:8000/health
   ```

### Option C: Full Vector Database Setup

For production-ready RAG with ChromaDB, see `RAG_SETUP_GUIDE.md`

## Checking Status

### In Your App

Go to **Admin Tab → LLM Diagnostics**

You'll see:
- ✅ Ollama Status (required)
- ✅ RAG Status (optional)
- Available models
- Setup instructions

### Via Terminal

```bash
# Check Ollama
curl http://localhost:11434/api/tags

# Check RAG (if running)
curl http://localhost:8000/health
```

## Troubleshooting

### "Cannot connect to Ollama"

```bash
# Start Ollama
ollama serve

# In another terminal, verify
curl http://localhost:11434/api/tags
```

### "RAG Service not running"

**This is OK!** The app works without RAG. But if you want to set it up:

```bash
cd rag_service
source venv/bin/activate
python rag_service.py
```

### Port 8000 already in use

```bash
# Find what's using it
lsof -i :8000

# Kill it
kill -9 <PID>

# Or use a different port
python rag_service.py --port 8001
```

Then update `OllamaService.swift`:
```swift
private let ragURL = URL(string: "http://localhost:8001/generate")!
```

## Architecture

```
┌─────────────────────────────────────┐
│         Your Swift App              │
│                                     │
│  ┌──────────────────────────────┐  │
│  │   OllamaService.swift        │  │
│  │   - Auto-detects RAG         │  │
│  │   - Falls back to Ollama     │  │
│  └──────────┬───────────────────┘  │
└─────────────┼──────────────────────┘
              │
       ┌──────┴──────┐
       │             │
       ▼             ▼
  ┌─────────┐  ┌─────────┐
  │ Ollama  │  │   RAG   │ (optional)
  │ :11434  │  │  :8000  │
  └─────────┘  └─────────┘
   Required     Optional
```

## What's the Difference?

### Without RAG (Current Setup)
- ✅ Works immediately with just Ollama
- ✅ Generates good quality content
- ✅ Uses model's built-in knowledge
- ✅ Fast and simple

**Example output:**
> "HVAC systems use refrigeration cycles to transfer heat. The main components are..."

### With RAG (Enhanced)
- ✅ All benefits of direct Ollama
- ✅ Enhanced with your custom knowledge base
- ✅ More accurate, domain-specific content
- ✅ Cites specific procedures and standards

**Example output:**
> "HVAC systems use refrigeration cycles to transfer heat. The main components are... 
> [Based on HVAC Excellence standards, residential systems typically operate at...]"

## Next Steps

1. ✅ **Test current setup**: Run your app with just Ollama
2. 📚 **Add content**: If you want RAG, run `python3 setup_rag.py`
3. 🔍 **Monitor**: Check "LLM Diagnostics" in your app
4. 📝 **Customize**: Add your own knowledge to `rag_service/`

## Resources

- **Ollama**: https://ollama.ai
- **FastAPI**: https://fastapi.tiangolo.com
- **ChromaDB**: https://docs.trychroma.com

## Support

The app is designed to work great in both modes:
- **Development**: Use direct Ollama (simpler)
- **Production**: Add RAG for enhanced content

Questions? Check:
1. LLM Diagnostics tab in your app
2. RAG_SETUP_GUIDE.md for detailed setup
3. Terminal output for error messages

---

**TL;DR**: Your app works now with just `ollama serve`. RAG is an optional enhancement you can add later! 🚀
