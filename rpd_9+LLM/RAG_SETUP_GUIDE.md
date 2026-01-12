# RAG Setup Guide for Ollama Service

This guide walks you through setting up a Retrieval-Augmented Generation (RAG) system for your workforce development app.

## What is RAG?

RAG enhances AI-generated content by:
1. **Retrieving** relevant information from a knowledge base
2. **Augmenting** the AI prompt with that context
3. **Generating** more accurate, grounded responses

This prevents hallucinations and ensures your app provides factual, domain-specific information.

---

## Architecture Overview

```
┌─────────────────┐
│   Swift App     │
│ (OllamaService) │
└────────┬────────┘
         │
         ├──────────────────┐
         │                  │
         ▼                  ▼
┌─────────────────┐  ┌──────────────┐
│  Ollama Server  │  │  RAG Service │
│  (localhost:    │  │  (FastAPI)   │
│   11434)        │  │  Port 8000   │
└─────────────────┘  └──────┬───────┘
                            │
                            ▼
                     ┌──────────────┐
                     │  ChromaDB    │
                     │  (Vector DB) │
                     └──────────────┘
```

---

## Step-by-Step Setup

### Prerequisites

- Python 3.9 or later
- Ollama installed and running (`ollama serve`)
- Your Swift app project

### Step 1: Create RAG Service Directory

```bash
cd /path/to/your/project
mkdir rag_service
cd rag_service
```

### Step 2: Create Python Virtual Environment

```bash
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

### Step 3: Install Dependencies

Create `requirements.txt`:
```txt
fastapi==0.104.1
uvicorn==0.24.0
chromadb==0.4.18
sentence-transformers==2.2.2
ollama==0.1.6
pydantic==2.5.0
```

Install:
```bash
pip install -r requirements.txt
```

### Step 4: Create RAG Service

Copy the `rag_service.py` file (provided above) into your `rag_service/` directory.

### Step 5: Create Knowledge Base Seeder

Copy the `seed_knowledge_base.py` file (provided above) into your `rag_service/` directory.

### Step 6: Start Services

#### Terminal 1 - Ollama
```bash
ollama serve
```

#### Terminal 2 - RAG Service
```bash
cd rag_service
source venv/bin/activate
python rag_service.py
```

You should see:
```
INFO:     Started server process
INFO:     Uvicorn running on http://0.0.0.0:8000
```

#### Terminal 3 - Seed Knowledge Base
```bash
cd rag_service
source venv/bin/activate
python seed_knowledge_base.py
```

---

## Testing the Setup

### 1. Check RAG Service Health

```bash
curl http://localhost:8000/health
```

Expected response:
```json
{
  "status": "healthy",
  "collections": {
    "hvac": 2,
    "nursing": 1,
    "mental_health": 1,
    "spiritual": 0
  }
}
```

### 2. Test RAG Generation

```bash
curl -X POST http://localhost:8000/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3",
    "prompt": "Explain the HVAC refrigeration cycle",
    "track": "hvac",
    "stream": false
  }'
```

### 3. Test from Swift

In your SwiftUI view:

```swift
import SwiftUI

struct RAGTestView: View {
    @StateObject private var ollama = OllamaService.shared
    @State private var content = ""
    @State private var isLoading = false
    @State private var ragStats: [String: Int] = [:]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("RAG System Test")
                .font(.title)
            
            // Health Check
            Button("Check RAG Connection") {
                Task {
                    let isHealthy = await ollama.checkRAGConnection()
                    print("RAG Health: \(isHealthy ? "✅" : "❌")")
                    
                    if isHealthy {
                        do {
                            ragStats = try await ollama.getRAGStats()
                        } catch {
                            print("Error getting stats: \(error)")
                        }
                    }
                }
            }
            
            // Display Stats
            if !ragStats.isEmpty {
                VStack(alignment: .leading) {
                    Text("Knowledge Base Stats:")
                        .font(.headline)
                    
                    ForEach(ragStats.sorted(by: { $0.key < $1.key }), id: \.key) { track, count in
                        Text("\(track): \(count) documents")
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Test Generation
            Button(isLoading ? "Generating..." : "Test RAG Generation") {
                testRAGGeneration()
            }
            .disabled(isLoading)
            
            // Display Generated Content
            if !content.isEmpty {
                ScrollView {
                    Text(content)
                        .padding()
                }
                .frame(maxHeight: 300)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding()
    }
    
    func testRAGGeneration() {
        isLoading = true
        Task {
            do {
                content = try await ollama.generateTrackContent(
                    trackType: "hvac",
                    title: "HVAC Refrigeration Basics",
                    description: "Understanding the refrigeration cycle",
                    difficulty: "beginner",
                    useRAG: true
                )
            } catch {
                content = "Error: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
}
```

---

## Adding Your Own Knowledge

### Option 1: Via Python Script

Edit `seed_knowledge_base.py` and add more documents:

```python
hvac_documents.append({
    "track": "hvac",
    "content": """
    Your detailed HVAC knowledge here...
    """,
    "metadata": {
        "title": "Document Title",
        "difficulty": "intermediate",
        "category": "installation"
    }
})
```

Then run:
```bash
python seed_knowledge_base.py
```

### Option 2: Via Swift API

```swift
Task {
    try await OllamaService.shared.addDocumentToRAG(
        track: "hvac",
        content: """
        Ductwork Sizing Guidelines:
        - Measure cubic feet per minute (CFM) requirements
        - Use Manual D calculations for residential
        - Ensure proper air velocity (600-900 FPM in ducts)
        - Account for static pressure losses
        """,
        metadata: [
            "title": "Ductwork Sizing",
            "difficulty": "intermediate",
            "category": "design"
        ]
    )
    
    print("Document added successfully!")
}
```

### Option 3: Bulk Import from Files

Create `import_documents.py`:

```python
import requests
import json
import os

RAG_URL = "http://localhost:8000/add_document"

def import_text_files(directory: str, track: str):
    """Import all .txt files from a directory into RAG"""
    for filename in os.listdir(directory):
        if filename.endswith('.txt'):
            filepath = os.path.join(directory, filename)
            
            with open(filepath, 'r') as f:
                content = f.read()
            
            doc = {
                "track": track,
                "content": content,
                "metadata": {
                    "title": filename.replace('.txt', ''),
                    "source": filepath
                }
            }
            
            try:
                response = requests.post(RAG_URL, json=doc)
                if response.status_code == 200:
                    print(f"✅ Imported: {filename}")
                else:
                    print(f"❌ Failed: {filename}")
            except Exception as e:
                print(f"❌ Error: {e}")

if __name__ == "__main__":
    # Example: Import all HVAC documents
    import_text_files("./knowledge/hvac/", "hvac")
    import_text_files("./knowledge/nursing/", "nursing")
```

---

## Monitoring & Maintenance

### View Collection Statistics

```bash
curl http://localhost:8000/stats
```

### Monitor RAG Service Logs

The FastAPI service logs all requests. Watch for:
- Query embeddings being generated
- Vector database searches
- Document retrievals

### Performance Tuning

Edit `rag_service.py`:

```python
# Adjust number of retrieved documents
results = collection.query(
    query_embeddings=[query_embedding],
    n_results=5  # Increase for more context (default: 3)
)
```

```python
# Use a different embedding model
embedding_model = SentenceTransformer('all-mpnet-base-v2')  # More accurate but slower
```

---

## Alternative: Using Existing RAG Solutions

### Option A: LangChain Integration

```bash
pip install langchain langchain-community
```

```python
from langchain.vectorstores import Chroma
from langchain.embeddings import OllamaEmbeddings
from langchain.llms import Ollama
from langchain.chains import RetrievalQA

# Initialize
embeddings = OllamaEmbeddings(model="llama3")
vectorstore = Chroma(persist_directory="./chroma_db", embedding_function=embeddings)
llm = Ollama(model="llama3")

# Create RAG chain
qa_chain = RetrievalQA.from_chain_type(
    llm=llm,
    retriever=vectorstore.as_retriever(search_kwargs={"k": 3}),
    return_source_documents=True
)
```

### Option B: Ollama with Built-in RAG

Some Ollama models support RAG natively. Check:
```bash
ollama list
```

---

## Troubleshooting

### RAG Service Won't Start

```bash
# Check if port 8000 is already in use
lsof -i :8000

# Kill existing process
kill -9 <PID>

# Or use a different port
uvicorn rag_service:app --host 0.0.0.0 --port 8001
```

Then update Swift:
```swift
private let ragURL = URL(string: "http://localhost:8001/generate")!
```

### ChromaDB Errors

```bash
# Clear and reinitialize
rm -rf ./chroma_db
python seed_knowledge_base.py
```

### Ollama Connection Issues

```bash
# Check Ollama is running
curl http://localhost:11434/api/tags

# Restart Ollama
pkill ollama
ollama serve
```

### Swift App Can't Connect

1. Check firewall settings
2. Ensure services are running on localhost
3. Try `127.0.0.1` instead of `localhost`
4. Check macOS privacy settings for network access

---

## Production Considerations

### Security

1. **Add Authentication**
```python
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

security = HTTPBearer()

@app.post("/generate")
async def generate_with_rag(
    request: GenerateRequest,
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    # Verify token
    pass
```

2. **Rate Limiting**
```bash
pip install slowapi
```

```python
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)

@app.post("/generate")
@limiter.limit("5/minute")
async def generate_with_rag(request: Request, ...):
    pass
```

### Deployment

1. **Docker Container**
```dockerfile
FROM python:3.9
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["uvicorn", "rag_service:app", "--host", "0.0.0.0", "--port", "8000"]
```

2. **Process Manager**
```bash
pip install supervisor

# supervisord.conf
[program:rag_service]
command=/path/to/venv/bin/python rag_service.py
autostart=true
autorestart=true
```

### Scaling

- Use PostgreSQL + pgvector instead of ChromaDB
- Deploy to cloud (AWS, GCP, Azure)
- Use managed vector databases (Pinecone, Weaviate, Qdrant)

---

## Next Steps

1. ✅ Set up and test RAG service
2. 📚 Add domain-specific knowledge for each track
3. 🧪 Test with real learning modules
4. 📊 Monitor query quality and user feedback
5. 🔄 Iterate and improve knowledge base

---

## Resources

- [ChromaDB Documentation](https://docs.trychroma.com/)
- [Sentence Transformers](https://www.sbert.net/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Ollama Python Library](https://github.com/ollama/ollama-python)

---

## Support

If you encounter issues:
1. Check the troubleshooting section above
2. Review RAG service logs
3. Test each component independently
4. Verify all services are running

Happy building! 🚀
