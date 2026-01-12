# RAG Database Configuration

## Overview

The app is now configured to:
1. **First**: Try to use the RAG database at `/Users/chris/Desktop/rag_service/chroma_db/`
2. **Fallback**: Use direct OllamaService if RAG is unavailable or fails

## Database Path Priority

The RAG service (`rag_service.py`) checks for databases in this order:

1. **Primary Path**: `/Users/chris/Desktop/rag_service/chroma_db/`
   - Used if the directory exists
   - This is your main RAG knowledge base

2. **Fallback Path**: `rpd_9+LLM/chroma_db/` (local to the app)
   - Used if primary path doesn't exist
   - Created automatically if needed

## How It Works

### RAG Service (`rag_service.py`)

```python
# Priority: Use specified RAG database path, fallback to local
RAG_DB_PATH = "/Users/chris/Desktop/rag_service/chroma_db"
LOCAL_DB_PATH = os.path.join(os.path.dirname(__file__), "chroma_db")

# Check if the specified RAG database exists, otherwise use local
if os.path.exists(RAG_DB_PATH):
    db_path = RAG_DB_PATH
    print(f"📊 Using RAG database at: {db_path}")
else:
    db_path = LOCAL_DB_PATH
    print(f"📊 Using local database at: {db_path}")
```

### Swift App (`OllamaService.swift`)

The app tries RAG first, then automatically falls back to direct Ollama:

```swift
// Try RAG first (will automatically fallback to direct Ollama if RAG fails)
let content = try await OllamaService.shared.generateTrackContent(
    trackType: track,
    title: task.title,
    description: task.description,
    difficulty: task.difficultyLevel ?? "intermediate",
    userGoals: viewModel.user.goals,
    useRAG: true  // Try RAG first, automatically falls back to direct Ollama
)
```

### Fallback Logic

1. **Check RAG Connection**: App checks if RAG service is running
2. **Try RAG Generation**: If available, tries to generate with RAG
3. **Automatic Fallback**: If RAG fails, automatically uses direct Ollama
4. **Error Handling**: User sees content either way (RAG-enhanced or direct)

## Content Generation Flow

```
Task Detail View Opens
    ↓
Check Ollama (required)
    ↓
Try RAG Service
    ├─ Success → Use RAG-enhanced content ✅
    └─ Failure → Fallback to direct Ollama ✅
    ↓
Display Content
```

## Verification

### Check Which Database is Being Used

When you start the RAG service, you'll see:

```
🚀 Starting RAG Service...
📊 Database path: /Users/chris/Desktop/rag_service/chroma_db
✅ Using primary RAG database at: /Users/chris/Desktop/rag_service/chroma_db
```

Or if the primary path doesn't exist:

```
🚀 Starting RAG Service...
📊 Database path: /path/to/rpd_9+LLM/chroma_db
⚠️  Using fallback local database at: /path/to/rpd_9+LLM/chroma_db
   (Primary RAG database not found at: /Users/chris/Desktop/rag_service/chroma_db)
```

### Test the Integration

1. **Start RAG Service:**
   ```bash
   cd rpd_9+LLM
   python3 rag_service.py
   ```
   Check the startup message to see which database is being used.

2. **In Swift App:**
   - Go to **Admin Tab → LLM Diagnostics**
   - Should show "RAG: Connected ✅"
   - Open a task to see content generation

3. **Check Logs:**
   - RAG service terminal will show document retrieval
   - Swift console will show fallback messages if RAG fails

## Troubleshooting

### RAG Database Not Found

If you see the fallback message, ensure:
- The directory exists: `/Users/chris/Desktop/rag_service/chroma_db/`
- The directory is readable
- ChromaDB can access it

### RAG Service Not Using Primary Database

1. Check the startup message when running `rag_service.py`
2. Verify the path exists: `ls -la /Users/chris/Desktop/rag_service/chroma_db/`
3. Check file permissions

### Fallback to Direct Ollama

This is **normal and expected** if:
- RAG service is not running
- RAG service fails to generate content
- Knowledge base is empty

The app will still work perfectly with direct Ollama generation.

## Configuration

### Change Database Path

To use a different database path, edit `rag_service.py`:

```python
RAG_DB_PATH = "/your/custom/path/chroma_db"
```

### Disable RAG Fallback

If you want to force RAG-only (no fallback), modify `OllamaService.swift`:

```swift
// In generateTrackContent, change:
useRAG: true  // Will fail if RAG unavailable

// To:
useRAG: false  // Always use direct Ollama
```

## Benefits

✅ **Primary RAG Database**: Uses your centralized knowledge base  
✅ **Automatic Fallback**: Always works, even if RAG is down  
✅ **Seamless Experience**: User doesn't see errors, just gets content  
✅ **Flexible**: Can work with or without RAG service  

## Files Modified

1. **`rag_service.py`**: Updated to check primary database path first
2. **`OllamaService.swift`**: Enhanced fallback logic in `generateTrackContent()`
3. **`rpd_9_LLMApp.swift`**: Simplified to always try RAG first

---

**Status**: ✅ Configured to use `/Users/chris/Desktop/rag_service/chroma_db/` first, with automatic fallback to direct Ollama.

