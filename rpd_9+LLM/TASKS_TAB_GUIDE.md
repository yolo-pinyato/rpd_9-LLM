# Tasks Tab - AI Content Generation Guide

## What's New

The Tasks tab now generates personalized learning content and answers questions using Ollama AI!

## Features

### 1. Automatic Learning Content Generation

When you open a task, the app automatically:
- ✅ Checks Ollama connection
- ✅ Generates comprehensive learning material about the task
- ✅ Tries RAG (Retrieval Augmented Generation) first for knowledge-base content
- ✅ Falls back to direct Ollama generation if RAG unavailable
- ✅ Shows loading states and helpful error messages

### 2. Interactive Q&A

Ask questions about any task:
- 📝 Type your question in the text field
- 🧠 Get AI-powered answers in seconds
- 💬 Full conversation history maintained
- 🎯 Context-aware responses based on the task

## How to Use

### Step 1: Ensure Ollama is Running

**On your Mac:**
```bash
export OLLAMA_HOST=0.0.0.0:11434
ollama serve
```

**Keep this terminal window open!**

### Step 2: Verify Connection (Physical Device Only)

1. Go to **Profile** tab
2. Scroll to **Network Settings**
3. Ensure your Mac's IP is set (e.g., `10.0.0.71`)
4. Tap **"Test Connection"**
5. Should show ✅ **"Connected"**

### Step 3: Open a Task

1. Go to **Tasks** tab
2. Tap any task card
3. The task detail view opens

### Step 4: View Learning Content

**Automatic Generation:**
- Content starts loading immediately when you open a task
- Shows "Loading learning content from knowledge base..."
- Displays comprehensive learning material when ready

**Content Includes:**
1. Introduction to the topic
2. Key concepts and principles
3. Practical applications
4. Hands-on tips
5. Summary and next steps

**If Error Occurs:**
- Clear error message with troubleshooting steps
- **"Retry"** button to try again
- Different messages for simulator vs physical device

### Step 5: Ask Questions

**Using the Q&A Section:**

1. Scroll to the **"Ask Questions"** section
2. Type your question in the text field
3. Tap the **paper plane** button (or press Return)
4. Watch as AI thinks and generates an answer

**Question Examples:**
- "Can you explain this in simpler terms?"
- "What are the key takeaways?"
- "How does this apply to real-world scenarios?"
- "What should I focus on first?"
- "Can you give me an example?"

**Conversation Features:**
- Questions and answers are displayed in a conversation format
- Your questions show with a **person icon** 👤
- AI answers show with a **brain icon** 🧠
- Full conversation history maintained during the session
- Context-aware: AI knows which task you're asking about

## Error Messages

### Simulator

**Connection Failed:**
```
Ollama service is not running.

To start Ollama:
1. Open Terminal on your Mac
2. Run: ollama serve

Then return to the app and try again.
```

### Physical Device

**Connection Failed:**
```
Cannot connect to Ollama.

1. On your Mac, run in Terminal:
   export OLLAMA_HOST=0.0.0.0:11434
   ollama serve

2. Check Profile > Network Settings
   • Verify Mac IP is correct
   • Test Connection should be ✅

3. Try again
```

**Model Missing:**
```
Generation failed: model 'llama3' not found

Make sure the model 'llama3' is available:
Run: ollama pull llama3
```

## Troubleshooting

### Content Won't Load

**Problem:** "Cannot connect to Ollama"

**Solutions:**
1. **Check Ollama is running:**
   ```bash
   # On your Mac
   curl http://localhost:11434/api/tags
   ```
   Should return JSON with models.

2. **Physical Device - Check network access:**
   ```bash
   # On your Mac (replace with your IP)
   curl http://10.0.0.71:11434/api/tags
   ```
   Should return same JSON.

3. **Verify IP configuration:**
   - Profile > Network Settings
   - Test Connection = ✅

4. **Check OLLAMA_HOST:**
   ```bash
   echo $OLLAMA_HOST
   # Should show: 0.0.0.0:11434
   ```

### Q&A Not Working

**Problem:** Questions aren't getting answers

**Solutions:**
1. Same as above - check Ollama connection
2. Make sure you have the `llama3` model:
   ```bash
   ollama pull llama3
   ```

### Slow Generation

**Normal behavior:**
- First content generation: 30-60 seconds
- Questions: 10-30 seconds
- Depends on your Mac's hardware

**Speed it up:**
- Use a smaller model (but less capable):
  ```bash
  ollama pull llama3:8b
  ```
- Close other heavy applications
- Ensure Mac isn't in low-power mode

### Empty Content

**Problem:** Learning content is blank

**Solutions:**
1. Check if task has a track assigned
2. Select a learning track in Home tab first
3. Retry loading content

## Technical Details

### Content Generation Flow

1. **Check Connection** → Tests Ollama availability
2. **Try RAG First** → Searches knowledge base at `/Users/chris/Desktop/rag_service/chroma_db/`
3. **Fallback to Ollama** → Direct generation if RAG unavailable
4. **Display Content** → Shows formatted learning material

### Q&A Context

Each question includes:
- Task title
- Task description
- Task category
- User's question

This ensures AI understands what you're asking about.

### Models Used

- **Default:** `llama3` (defined in OllamaService.swift line 35)
- **Alternative:** Any model you have installed
- **Recommended:** `llama3` or `llama3:8b` for good balance

## Testing Checklist

### Before Testing
- [ ] Ollama running with `OLLAMA_HOST=0.0.0.0:11434`
- [ ] Model installed: `ollama list` shows `llama3`
- [ ] (Physical) IP configured in Profile > Network Settings
- [ ] (Physical) Test Connection = ✅

### Test Scenarios

**Scenario 1: Content Generation**
- [ ] Open any task
- [ ] Content starts loading automatically
- [ ] Progress indicator shows
- [ ] Content appears after generation
- [ ] Content is relevant to the task

**Scenario 2: Question Answering**
- [ ] Scroll to "Ask Questions" section
- [ ] Type a question
- [ ] Tap send button
- [ ] "Thinking..." appears
- [ ] Answer is relevant and helpful
- [ ] Can ask follow-up questions

**Scenario 3: Error Handling**
- [ ] Stop Ollama (`pkill ollama`)
- [ ] Try to load content
- [ ] Clear error message appears
- [ ] Retry button works after restarting Ollama

**Scenario 4: Multiple Tasks**
- [ ] Open task 1, view content
- [ ] Go back, open task 2
- [ ] Content loads for task 2
- [ ] Q&A context is for task 2, not task 1

## What's Integrated

### OllamaService Methods Used

1. **checkOllamaConnection()** - Verifies Ollama is accessible
2. **generateTrackContent()** - Creates learning material
3. **askQuestion()** - Answers user questions

### Error Handling

- Connection checks before every operation
- Clear, actionable error messages
- Different messages for simulator vs physical device
- Retry functionality built-in

### UI Features

- Loading states with spinners
- Error states with explanations
- Retry buttons where appropriate
- Conversation history display
- Context-aware suggestions

## Summary

The Tasks tab is now a full AI-powered learning assistant! Users can:
1. 📚 Get comprehensive learning content automatically
2. 💭 Ask questions and get instant answers
3. 🔄 Retry operations if errors occur
4. 📱 Use on both simulator and physical devices

Everything is powered by your local Ollama instance, with proper error handling and user feedback throughout.

Happy learning! 🚀
