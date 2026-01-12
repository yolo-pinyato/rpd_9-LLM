# Testing RAG Integration - Quick Start

## 🚀 Quick Test (30 seconds)

```bash
cd rpd_9+LLM
./quick_test_rag.sh
```

This will verify:
- ✅ RAG service is running
- ✅ Knowledge base has documents
- ✅ Content generation works
- ✅ RAG is actually retrieving sources

## 📋 Comprehensive Test (2-3 minutes)

```bash
cd rpd_9+LLM
python3 test_rag_integration.py
```

This runs 5 detailed tests:
1. RAG Service Health Check
2. Knowledge Base Statistics
3. Content Generation with RAG
4. RAG vs Direct Ollama Comparison
5. Swift App Integration Simulation

## 🧪 Manual Testing in Swift App

1. **Start Services:**
   ```bash
   # Terminal 1: Start Ollama
   ollama serve
   
   # Terminal 2: Start RAG (optional)
   cd rpd_9+LLM
   python3 rag_service.py
   ```

2. **In Your Swift App:**
   - Go to **Admin Tab → LLM Diagnostics**
   - Should show:
     - ✅ Ollama: Connected
     - ✅ RAG: Connected (if running)

3. **Test Content Generation:**
   - Select a track (e.g., HVAC)
   - Open any task
   - View learning content
   - Content should load from RAG if available

## 🔍 What to Look For

### ✅ RAG is Working If:
- Health check returns `status: "healthy"`
- `/stats` shows documents in collections
- Generated content includes `sources` array
- Swift app shows "RAG: Connected ✅"
- RAG service logs show: `📚 Retrieved X documents`

### ❌ RAG is NOT Working If:
- Health check fails
- No documents in knowledge base
- Generated content has no `sources`
- Swift app shows "RAG: Not Running"

## 📁 Files Created

- `test_rag_integration.py` - Comprehensive Python test suite
- `quick_test_rag.sh` - Quick bash test script
- `TESTING_RAG.md` - Detailed testing guide
- `README_TESTING.md` - This quick reference

## 🐛 Troubleshooting

**RAG service not running?**
```bash
python3 rag_service.py
```

**No documents in knowledge base?**
```bash
python3 setup_rag.py
```

**Swift app can't connect?**
- Check iOS Simulator can reach localhost
- Verify ports 8000 (RAG) and 11434 (Ollama) are open
- Check firewall settings

## 📊 Integration Points

Your Swift app uses RAG in:
- **TaskDetailView** (line ~1660): `loadLearningContent()`
- **OllamaService.swift** (line ~128): `generateTrackContent()`
- **RAG Service** (`rag_service.py` line ~77): `/generate` endpoint

## 🎯 Success Checklist

- [ ] Run `./quick_test_rag.sh` - all tests pass
- [ ] Swift app shows "RAG: Connected ✅"
- [ ] Opening a task loads learning content
- [ ] RAG service logs show document retrieval
- [ ] Generated content references knowledge base

---

**Need more details?** See `TESTING_RAG.md` for comprehensive guide.

