#!/bin/bash
# Quick RAG Integration Test
# Simple script to verify RAG is working

echo "🔍 Quick RAG Test"
echo "================="
echo ""

# Test 1: RAG Health
echo "1. Testing RAG service health..."
if curl -s http://localhost:8000/health > /dev/null 2>&1; then
    echo "   ✅ RAG service is running"
    
    # Get stats
    STATS=$(curl -s http://localhost:8000/stats)
    TOTAL_DOCS=$(echo $STATS | grep -o '"total_documents":[0-9]*' | grep -o '[0-9]*')
    
    if [ -n "$TOTAL_DOCS" ] && [ "$TOTAL_DOCS" -gt 0 ]; then
        echo "   ✅ Knowledge base has $TOTAL_DOCS documents"
    else
        echo "   ⚠️  Knowledge base is empty (run setup_rag.py)"
    fi
else
    echo "   ❌ RAG service is not running"
    echo "   Run: python3 rag_service.py"
    exit 1
fi

# Test 2: Ollama
echo ""
echo "2. Testing Ollama service..."
if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "   ✅ Ollama is running"
else
    echo "   ❌ Ollama is not running"
    echo "   Run: ollama serve"
    exit 1
fi

# Test 3: Generate test content
echo ""
echo "3. Testing content generation with RAG..."
RESPONSE=$(curl -s -X POST http://localhost:8000/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-oss:20b",
    "prompt": "What is HVAC?",
    "track": "hvac",
    "top_k": 3
  }')

if echo "$RESPONSE" | grep -q '"response"'; then
    echo "   ✅ Content generation successful"
    
    # Check for sources
    if echo "$RESPONSE" | grep -q '"sources"'; then
        SOURCES_COUNT=$(echo "$RESPONSE" | grep -o '"sources":\[.*\]' | grep -o '\[.*\]' | grep -o '{' | wc -l)
        if [ "$SOURCES_COUNT" -gt 0 ]; then
            echo "   ✅ RAG retrieved $SOURCES_COUNT source(s) - RAG is working!"
        else
            echo "   ⚠️  RAG generated content but no sources (knowledge base may be empty)"
        fi
    else
        echo "   ⚠️  No sources in response (RAG may not have found matches)"
    fi
else
    echo "   ❌ Content generation failed"
    echo "   Response: $RESPONSE"
    exit 1
fi

echo ""
echo "✅ All quick tests passed!"
echo ""
echo "Your Swift app should be able to use RAG. Test it:"
echo "  1. Run your Swift app"
echo "  2. Go to Admin → LLM Diagnostics"
echo "  3. Open a task to see RAG-enhanced content"

