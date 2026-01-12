# RPD Workforce Development App

An iOS workforce development application with AI-powered learning content generation, interactive quizzes, and career track progression tracking.

## Features

### Core Functionality
- **Learning Tracks**: Multiple career paths including HVAC, Building Operations, Electrical, Plumbing, and more
- **Task Management**: Comprehensive task system with progress tracking and point rewards
- **AI-Generated Content**: Dynamic learning material powered by local LLM (Ollama)
- **Interactive Quizzes**: Multiple-choice quizzes based on generated content
- **User Profiles**: Track progress, points, completed tasks, and achievements
- **Admin Dashboard**: Analytics, user management, and system diagnostics

### AI Integration
- **Local LLM Support**: Uses Ollama for privacy-focused, offline AI generation
- **RAG (Retrieval-Augmented Generation)**: Optional knowledge base integration for enhanced content
- **Q&A System**: Context-aware question answering for learning tasks
- **Multiple Model Support**: Compatible with llama3, mistral, gpt-oss, and more

### User Experience
- **Beautiful UI**: Custom themes with background images for each section
- **Account Switcher**: Easy switching between test accounts
- **Network Diagnostics**: Built-in tools for testing Ollama/RAG connections
- **Responsive Design**: Works on iPhone and iPad

## Screenshots

![App Overview](docs/screenshots/overview.png)

## Tech Stack

- **Platform**: iOS 15.0+, macOS 12.0+
- **Language**: Swift, SwiftUI
- **Database**: SQLite with custom DatabaseManager
- **AI Backend**: Ollama (local LLM)
- **RAG Service**: Python FastAPI with ChromaDB (optional)
- **Networking**: URLSession with async/await

## Getting Started

### Prerequisites

- Xcode 14.0+
- macOS 12.0+ (for running Ollama)
- iOS 15.0+ device or simulator
- 8GB RAM minimum (16GB recommended for AI features)
- 10GB free disk space per AI model

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yolo-pinyato/rpd_9-LLM.git
   cd rpd_9-LLM
   ```

2. **Open in Xcode**
   ```bash
   open rpd_9+LLM.xcodeproj
   ```

3. **Build and run**
   - Select your target device/simulator
   - Press `Cmd + R` to build and run

### Setting Up AI Features

The app works without AI, but for the full experience with content generation:

#### Quick Start (No RAG)

1. **Install Ollama**
   ```bash
   brew install ollama
   ```

2. **Start Ollama service**
   ```bash
   ollama serve
   ```

3. **Pull a model**
   ```bash
   ollama pull llama3
   # or
   ollama pull mistral
   ```

4. **Run the app!**

See [OLLAMA_SETUP_GUIDE.md](rpd_9+LLM/OLLAMA_SETUP_GUIDE.md) for detailed setup instructions.

#### Optional: RAG Setup

For enhanced content with custom knowledge base:

```bash
# Run the setup script
python3 rpd_9+LLM/setup_rag.py

# Start RAG service
cd rag_service
./start_rag.sh
```

See [RAG_QUICK_START.md](rpd_9+LLM/RAG_QUICK_START.md) for more details.

## Project Structure

```
rpd_9+LLM/
├── rpd_9+LLM/
│   ├── rpd_9_LLMApp.swift          # Main app with database manager
│   ├── WorkforceDevApp.swift       # Primary app views
│   ├── OllamaService.swift         # AI/LLM integration
│   ├── AppTheme.swift              # UI styling
│   ├── Enhanced/                   # Enhanced UI components
│   │   ├── AdminDashboard.swift
│   │   ├── EnhancedTasksView.swift
│   │   └── TrackSelectionView.swift
│   ├── Assets.xcassets/            # Images and resources
│   ├── rag_service.py              # RAG backend service
│   └── setup_rag.py                # RAG setup script
├── docs/                           # Documentation
│   ├── OLLAMA_SETUP_GUIDE.md
│   ├── RAG_QUICK_START.md
│   ├── TASKS_TAB_GUIDE.md
│   └── ...
└── README.md
```

## Key Documentation

- **[OLLAMA_SETUP_GUIDE.md](rpd_9+LLM/OLLAMA_SETUP_GUIDE.md)** - Complete Ollama installation and configuration
- **[RAG_QUICK_START.md](rpd_9+LLM/RAG_QUICK_START.md)** - Quick setup for RAG enhancement
- **[RAG_SETUP_GUIDE.md](rpd_9+LLM/RAG_SETUP_GUIDE.md)** - Detailed RAG configuration
- **[TASKS_TAB_GUIDE.md](rpd_9+LLM/TASKS_TAB_GUIDE.md)** - How to use AI-powered learning features
- **[QUIZ_FEATURE_SUMMARY.md](rpd_9+LLM/QUIZ_FEATURE_SUMMARY.md)** - Interactive quiz implementation details
- **[TEST_ACCOUNT_SWITCHER.md](rpd_9+LLM/TEST_ACCOUNT_SWITCHER.md)** - Testing with different user accounts
- **[PERFORMANCE_OPTIMIZATIONS.md](rpd_9+LLM/PERFORMANCE_OPTIMIZATIONS.md)** - App performance improvements

## Usage

### For End Users

1. **Select a Learning Track**
   - Open the app and go to Home tab
   - Choose from available career tracks (HVAC, Electrical, etc.)

2. **Complete Tasks**
   - Navigate to Tasks tab
   - Open a task to view AI-generated learning content
   - Read the content and take the quiz
   - Complete tasks to earn points

3. **Track Progress**
   - View your progress in Profile tab
   - See completed tasks, earned points, and achievements
   - Monitor your learning journey

### For Physical Devices

When running on a physical iOS device, configure network settings:

1. Go to **Profile** tab
2. Scroll to **Network Settings**
3. Enter your Mac's IP address (e.g., `192.168.1.100`)
4. Tap **"Test Connection"** to verify
5. Ensure Ollama is running with network access:
   ```bash
   export OLLAMA_HOST=0.0.0.0:11434
   ollama serve
   ```

See [OLLAMA_CONNECTION_GUIDE.md](rpd_9+LLM/OLLAMA_CONNECTION_GUIDE.md) for details.

## Database

The app uses SQLite for local data storage:

- **Location**: `~/Library/Application Support/workforce_dev.sqlite`
- **Tables**: users, learning_tracks, tasks, user_progress, quiz_results
- **Export**: Available from Admin dashboard

## Development

### Building from Source

```bash
# Clone the repository
git clone https://github.com/yolo-pinyato/rpd_9-LLM.git
cd rpd_9-LLM

# Open in Xcode
open rpd_9+LLM.xcodeproj

# Build
xcodebuild -scheme rpd_9+LLM -configuration Debug
```

### Running Tests

```bash
# Unit tests
xcodebuild test -scheme rpd_9+LLM -destination 'platform=iOS Simulator,name=iPhone 15'

# RAG integration tests
python3 rpd_9+LLM/test_rag_integration.py

# Service check
python3 rpd_9+LLM/check_services.py
```

See [README_TESTING.md](rpd_9+LLM/README_TESTING.md) for detailed testing instructions.

### Code Style

- Swift: Follow Swift API Design Guidelines
- SwiftUI: Declarative, modular views
- Async/Await: Modern concurrency patterns
- Error Handling: Comprehensive try/catch with user-friendly messages

## Architecture

### App Architecture

```
┌─────────────────────────────────────────┐
│          SwiftUI Views                  │
│  (Tasks, Profile, Admin, Resources)     │
└──────────────┬──────────────────────────┘
               │
┌──────────────┴──────────────────────────┐
│        DatabaseManager                  │
│  (SQLite CRUD operations)               │
└──────────────┬──────────────────────────┘
               │
               │
┌──────────────┴──────────────────────────┐
│       OllamaService                     │
│  (AI content generation)                │
└──────────────┬──────────────────────────┘
               │
        ┌──────┴──────┐
        │             │
        ▼             ▼
   ┌─────────┐  ┌──────────┐
   │ Ollama  │  │ RAG      │
   │ :11434  │  │ :8000    │
   └─────────┘  └──────────┘
    Required     Optional
```

### Data Flow

1. User interacts with SwiftUI views
2. Views call DatabaseManager for data operations
3. OllamaService generates AI content when needed
4. Results displayed in views with proper state management

## Configuration

### App Settings

Edit `WorkforceDevApp.swift` or `rpd_9_LLMApp.swift` to configure:

- Default models
- API endpoints
- Timeout values
- Feature flags

### AI Model Configuration

Change the default model in `OllamaService.swift`:

```swift
func generateContent(prompt: String, model: String = "llama3", ...)
// Change "llama3" to your preferred model
```

### Network Configuration

For physical devices, update the base URL in `OllamaService.swift`:

```swift
private var baseURL: String {
    if let savedIP = UserDefaults.standard.string(forKey: "ollamaServerIP"),
       !savedIP.isEmpty {
        return "http://\(savedIP):11434"
    }
    return "http://localhost:11434"
}
```

## Troubleshooting

### Common Issues

**"Cannot connect to Ollama"**
- Ensure Ollama is running: `ollama serve`
- Check if port 11434 is accessible: `curl http://localhost:11434/api/tags`
- For physical devices, verify network settings and IP address

**"Model not found"**
- Pull the required model: `ollama pull llama3`
- Check installed models: `ollama list`

**Slow content generation**
- Use a smaller model (llama3:8b instead of llama3:70b)
- Close memory-intensive applications
- Ensure sufficient RAM available

**Database not found**
- App creates database on first launch
- Check: `~/Library/Application Support/workforce_dev.sqlite`
- For sandboxed apps, check app container

See individual guide files for detailed troubleshooting.

## Performance

- App size: ~40MB
- Database: ~100KB (grows with user data)
- Memory usage: 50-100MB (app) + 4-8GB (Ollama with model)
- Content generation: 10-60 seconds depending on model and hardware

## Security

- All data stored locally (SQLite)
- No user data sent to external servers
- Ollama runs locally (privacy-focused)
- Optional RAG service also runs locally
- No API keys required (unless using external LLM)

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- **Ollama** - Local LLM runtime
- **ChromaDB** - Vector database for RAG
- **FastAPI** - RAG service backend
- **SwiftUI** - Modern UI framework

## Support

For issues, questions, or feedback:

- Open an issue on GitHub
- Check the documentation in the `docs/` folder
- Review the built-in diagnostics tool (Admin tab)

## Roadmap

- [ ] Additional learning tracks
- [ ] Advanced analytics dashboard
- [ ] Multi-user sync
- [ ] Offline mode improvements
- [ ] Additional quiz types
- [ ] Certificate generation
- [ ] Mobile-optimized UI enhancements

## Links

- **Repository**: https://github.com/yolo-pinyato/rpd_9-LLM
- **Ollama**: https://ollama.ai
- **ChromaDB**: https://www.trychroma.com
- **Swift**: https://swift.org

---

**Built with SwiftUI and local AI for privacy-focused workforce development.**
