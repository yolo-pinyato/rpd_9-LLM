"""
RAG Service for Workforce Development App
Provides retrieval-augmented generation using ChromaDB and Ollama
"""

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional
import chromadb
from chromadb.utils import embedding_functions
import ollama
import uvicorn
import os

app = FastAPI(title="Workforce Dev RAG Service", version="1.0.0")

# Initialize ChromaDB (vector database)
# Using absolute path to ensure connection to the correct database
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
    print(f"⚠️  RAG database not found at {RAG_DB_PATH}, using local fallback")

chroma_client = chromadb.PersistentClient(path=db_path)

# Use ChromaDB's built-in ONNX embedding function (same model as sentence-transformers but more stable)
# This uses the same 'all-MiniLM-L6-v2' model but via ONNX runtime
# This ensures compatibility with existing collections that use 384-dimensional embeddings
embedding_function = embedding_functions.ONNXMiniLM_L6_V2()

# Create or get collection for each track
COLLECTIONS = {
    "hvac": None,
    "nursing": None,
    "spiritual": None,
    "mental_health": None
}

def init_collections():
    """Initialize vector database collections for each track"""
    for track_name in COLLECTIONS.keys():
        try:
            # Try to get existing collection first
            try:
                COLLECTIONS[track_name] = chroma_client.get_collection(name=track_name)
                print(f"✅ Connected to existing collection: {track_name} ({COLLECTIONS[track_name].count()} documents)")
            except:
                # Collection doesn't exist, create it with the embedding function
                COLLECTIONS[track_name] = chroma_client.create_collection(
                    name=track_name,
                    embedding_function=embedding_function,
                    metadata={"description": f"Knowledge base for {track_name} track"}
                )
                print(f"✅ Created new collection: {track_name}")
        except Exception as e:
            print(f"❌ Error initializing {track_name} collection: {e}")

init_collections()

# Request/Response Models
class GenerateRequest(BaseModel):
    model: str = "gpt-oss:20b"
    prompt: str
    stream: bool = False
    track: Optional[str] = None  # For track-specific RAG
    top_k: int = 3  # Number of relevant documents to retrieve

class GenerateResponse(BaseModel):
    response: str
    model: str
    done: bool
    context: Optional[List[int]] = None
    sources: Optional[List[dict]] = None  # Retrieved document sources

class DocumentRequest(BaseModel):
    track: str
    content: str
    metadata: dict = {}

# RAG Endpoints
@app.post("/generate", response_model=GenerateResponse)
async def generate_with_rag(request: GenerateRequest):
    """
    Generate content with RAG enhancement
    
    Process:
    1. Embed the user's prompt
    2. Query vector database for relevant documents
    3. Augment prompt with retrieved context
    4. Generate response with Ollama
    """
    try:
        # 1. Retrieve relevant context from vector database
        relevant_docs = []
        sources = []
        
        if request.track and request.track in COLLECTIONS:
            collection = COLLECTIONS[request.track]
            
            if collection.count() > 0:
                # Query vector database (ChromaDB handles embedding automatically with embedding_function)
                results = collection.query(
                    query_texts=[request.prompt],
                    n_results=min(request.top_k, collection.count())
                )
                
                if results['documents'] and results['documents'][0]:
                    relevant_docs = results['documents'][0]
                    sources = [
                        {
                            "content": doc[:200] + "...",  # Preview only
                            "metadata": meta
                        }
                        for doc, meta in zip(
                            results['documents'][0],
                            results['metadatas'][0]
                        )
                    ]
                    print(f"📚 Retrieved {len(relevant_docs)} documents for track '{request.track}'")
            else:
                print(f"⚠️  No documents in {request.track} collection")
        
        # 2. Augment prompt with retrieved context
        augmented_prompt = request.prompt
        if relevant_docs:
            context_text = "\n\n".join([
                f"Reference {i+1}: {doc}"
                for i, doc in enumerate(relevant_docs)
            ])
            augmented_prompt = f"""Using the following reference information from verified sources:

{context_text}

Now, please answer this request:

{request.prompt}

Provide a comprehensive answer based on the references above and your knowledge. If the references don't fully answer the question, supplement with your general knowledge but indicate which parts came from references."""

        # 3. Generate response with Ollama
        print(f"🤖 Generating with model: {request.model}")
        response = ollama.generate(
            model=request.model,
            prompt=augmented_prompt,
            stream=request.stream
        )
        
        if request.stream:
            # Streaming not implemented in this version
            # You would use StreamingResponse here
            raise HTTPException(status_code=501, detail="Streaming not yet implemented")
        else:
            return GenerateResponse(
                response=response['response'],
                model=request.model,
                done=True,
                context=response.get('context'),
                sources=sources if sources else None
            )
            
    except Exception as e:
        print(f"❌ Generation error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/add_document")
async def add_document(doc_request: DocumentRequest):
    """
    Add a document to the knowledge base for a specific track
    
    The document will be:
    1. Embedded automatically using ChromaDB's ONNX embedding function
    2. Stored in the vector database
    3. Made available for future RAG queries
    """
    try:
        if doc_request.track not in COLLECTIONS:
            raise HTTPException(
                status_code=400,
                detail=f"Unknown track: {doc_request.track}. Valid tracks: {list(COLLECTIONS.keys())}"
            )
        
        collection = COLLECTIONS[doc_request.track]
        
        # Generate unique ID
        doc_id = f"{doc_request.track}_{collection.count() + 1}"
        
        # Add to vector database (ChromaDB handles embedding automatically with embedding_function)
        collection.add(
            documents=[doc_request.content],
            metadatas=[doc_request.metadata],
            ids=[doc_id]
        )
        
        print(f"✅ Added document to {doc_request.track}: {doc_request.metadata.get('title', 'Untitled')}")
        
        return {
            "status": "success",
            "message": f"Document added to {doc_request.track} knowledge base",
            "document_id": doc_id
        }
        
    except Exception as e:
        print(f"❌ Error adding document: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
async def health_check():
    """Check if RAG service is running and healthy"""
    collections_status = {}
    for track, collection in COLLECTIONS.items():
        try:
            collections_status[track] = collection.count() if collection else 0
        except:
            collections_status[track] = -1  # Error state
    
    return {
        "status": "healthy",
        "collections": collections_status,
        "embedding_function": "ONNXMiniLM_L6_V2",
        "embedding_dimension": 384,
        "database_path": db_path
    }

@app.get("/stats")
async def get_stats():
    """Get detailed statistics about the knowledge base"""
    stats = {}
    total_docs = 0
    
    for track_name, collection in COLLECTIONS.items():
        if collection:
            try:
                count = collection.count()
                stats[track_name] = {
                    "document_count": count,
                    "status": "active"
                }
                total_docs += count
            except Exception as e:
                stats[track_name] = {
                    "document_count": 0,
                    "status": "error",
                    "error": str(e)
                }
    
    return {
        "tracks": stats,
        "total_documents": total_docs,
        "embedding_function": "ONNXMiniLM_L6_V2",
        "embedding_dimension": 384,
        "database_path": db_path
    }

@app.delete("/collection/{track}")
async def clear_collection(track: str):
    """Clear all documents from a track's collection (use with caution!)"""
    if track not in COLLECTIONS:
        raise HTTPException(status_code=404, detail=f"Track '{track}' not found")
    
    try:
        # Delete and recreate collection
        chroma_client.delete_collection(name=track)
        COLLECTIONS[track] = chroma_client.create_collection(
            name=track,
            embedding_function=embedding_function,
            metadata={"description": f"Knowledge base for {track} track"}
        )
        return {
            "status": "success",
            "message": f"Collection '{track}' cleared"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/")
async def root():
    """API information"""
    return {
        "service": "Workforce Development RAG Service",
        "version": "1.0.0",
        "endpoints": {
            "POST /generate": "Generate content with RAG",
            "POST /add_document": "Add document to knowledge base",
            "GET /health": "Health check",
            "GET /stats": "Get statistics",
            "DELETE /collection/{track}": "Clear collection"
        },
        "tracks": list(COLLECTIONS.keys())
    }

if __name__ == "__main__":
    print("🚀 Starting RAG Service...")
    print(f"📊 Database path: {os.path.abspath(db_path)}")
    if db_path == RAG_DB_PATH:
        print(f"✅ Using primary RAG database at: {RAG_DB_PATH}")
    else:
        print(f"⚠️  Using fallback local database at: {LOCAL_DB_PATH}")
        print(f"   (Primary RAG database not found at: {RAG_DB_PATH})")
    print(f"📊 Embedding function: ONNXMiniLM_L6_V2 (384 dimensions)")
    print(f"📚 Available tracks: {list(COLLECTIONS.keys())}")
    print(f"📚 Collections status:")
    for track_name, collection in COLLECTIONS.items():
        if collection:
            count = collection.count()
            print(f"   - {track_name}: {count} documents")
    
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8000,
        log_level="info"
    )

