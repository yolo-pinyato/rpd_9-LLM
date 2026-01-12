# Grant Platform MVP - Integration Guide

## Overview

This guide explains how to integrate your Swift UI app (rpd_9+LLM) with the Grant Platform MVP backend for A/B testing and data collection.

## Architecture

```
Swift App (rpd_9+LLM)                    Backend Services
─────────────────────                    ────────────────

User completes tasks  ──────────────►   FastAPI Server
User checks in                           (Port 8001)
User redeems rewards                           │
                                               │
Tracks A/B test data                           ▼
(control vs experimental)              SQLite Database
                                       (grant_platform.db)
                                               │
                                               ▼
                                       Analytics & Stats
```

## What's Working Now

### ✅ Backend Service (Port 8001)

The Grant Platform MVP is running at `http://localhost:8001` with the following features:

1. **Organization Research** (Screen 1)
   - Scrapes organization websites
   - Extracts structured data using Ollama
   - Stores in SQLite database

2. **Grant Matching** (Screen 2)
   - Matches organizations to grants using similarity scoring
   - Returns ranked list of grants

3. **A/B Test Data Collection** (For your Swift app)
   - Records user events (task completions, check-ins, rewards)
   - Tracks control vs experimental groups
   - Provides analytics

## Swift App Integration

### Step 1: Add A/B Test Configuration to Your App

Add this to your `OllamaService.swift` or create a new `GrantPlatformService.swift`:

```swift
import Foundation

class GrantPlatformService {
    static let shared = GrantPlatformService()

    // Base URL for Grant Platform API
    private let baseURL = "http://localhost:8001"  // Simulator
    // For physical device: "http://YOUR_MAC_IP:8001"

    // MARK: - A/B Test Event Model
    struct ABTestEvent: Codable {
        let user_id: String
        let session_id: Int
        let ab_group: String  // "control" or "experimental"
        let event_type: String
        let event_data: [String: Any]

        enum CodingKeys: String, CodingKey {
            case user_id, session_id, ab_group, event_type, event_data
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(user_id, forKey: .user_id)
            try container.encode(session_id, forKey: .session_id)
            try container.encode(ab_group, forKey: .ab_group)
            try container.encode(event_type, forKey: .event_type)

            // Convert [String: Any] to JSON string
            let jsonData = try JSONSerialization.data(withJSONObject: event_data)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                try container.encode(jsonString, forKey: .event_data)
            }
        }
    }

    // MARK: - Send Event to Backend
    func recordABTestEvent(
        userId: String,
        sessionId: Int,
        abGroup: String,
        eventType: String,
        eventData: [String: Any]
    ) async throws {

        guard let url = URL(string: "\(baseURL)/api/ab_test/event") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let payload: [String: Any] = [
            "user_id": userId,
            "session_id": sessionId,
            "ab_group": abGroup,
            "event_type": eventType,
            "event_data": eventData
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        print("✅ A/B test event recorded: \(eventType)")
    }
}
```

### Step 2: Assign Users to A/B Test Groups

Add this to your `DatabaseManager` or user initialization:

```swift
// In DatabaseManager.swift or rpd_9_LLMApp.swift

func assignABTestGroup() -> String {
    // Check if user already has a group assigned
    if let savedGroup = UserDefaults.standard.string(forKey: "ab_test_group") {
        return savedGroup
    }

    // Randomly assign to control or experimental (50/50)
    let group = Bool.random() ? "control" : "experimental"
    UserDefaults.standard.set(group, forKey: "ab_test_group")
    print("🔬 Assigned user to A/B test group: \(group)")
    return group
}

func getABTestGroup() -> String {
    return UserDefaults.standard.string(forKey: "ab_test_group") ?? "control"
}
```

### Step 3: Track Events in Your App

Modify your existing task completion, check-in, and reward redemption code:

```swift
// Example: When user completes a task
func completeTask(task: Task) {
    // ... existing task completion code ...

    // Record A/B test event
    Task {
        try? await GrantPlatformService.shared.recordABTestEvent(
            userId: DatabaseManager.shared.currentUserId,
            sessionId: DatabaseManager.shared.currentSessionId,
            abGroup: DatabaseManager.shared.getABTestGroup(),
            eventType: "task_complete",
            eventData: [
                "task_id": task.id,
                "task_title": task.title,
                "points_earned": task.points,
                "completion_time": ISO8601DateFormatter().string(from: Date())
            ]
        )
    }
}

// Example: When user checks in
func recordCheckIn() {
    Task {
        try? await GrantPlatformService.shared.recordABTestEvent(
            userId: DatabaseManager.shared.currentUserId,
            sessionId: DatabaseManager.shared.currentSessionId,
            abGroup: DatabaseManager.shared.getABTestGroup(),
            eventType: "checkin",
            eventData: [
                "timestamp": ISO8601DateFormatter().string(from: Date()),
                "current_streak": currentStreak
            ]
        )
    }
}

// Example: When user redeems reward
func redeemReward(reward: Reward) {
    Task {
        try? await GrantPlatformService.shared.recordABTestEvent(
            userId: DatabaseManager.shared.currentUserId,
            sessionId: DatabaseManager.shared.currentSessionId,
            abGroup: DatabaseManager.shared.getABTestGroup(),
            eventType: "reward_redeem",
            eventData: [
                "reward_title": reward.title,
                "points_cost": reward.pointsCost,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ]
        )
    }
}
```

### Step 4: Show/Hide Rewards Based on A/B Group

Modify your rewards view to respect the A/B test group:

```swift
struct RewardsView: View {
    @State private var abGroup = DatabaseManager.shared.getABTestGroup()

    var body: some View {
        VStack {
            if abGroup == "experimental" {
                // Show rewards
                RewardsListView()
            } else {
                // Control group - no rewards
                Text("Complete tasks to earn points!")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            print("User in A/B group: \(abGroup)")
        }
    }
}
```

## Testing the Integration

### 1. Start the Backend Service

```bash
cd ~/Desktop/grant_platform_services
source venv/bin/activate
python main.py
```

### 2. Test from Command Line

```bash
# Test organization research
curl -X POST http://localhost:8001/api/research/organization \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "test_user",
    "description": "The Community Works of Lake County provides workforce development services for underserved youth in Lake County, Illinois. We focus on connecting young adults ages 18-24 with HVAC training and job placement opportunities."
  }'

# Record a test event
curl -X POST http://localhost:8001/api/ab_test/event \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "test_user_123",
    "session_id": 1,
    "ab_group": "experimental",
    "event_type": "task_complete",
    "event_data": {
      "task_id": "hvac_basics_1",
      "points_earned": 50
    }
  }'

# Get A/B test statistics
curl http://localhost:8001/api/ab_test/stats
```

### 3. Run Your Swift App

1. Open Xcode
2. Build and run rpd_9+LLM
3. Complete some tasks
4. Check if rewards show (based on A/B group)
5. Events should be recorded in the backend

### 4. View Statistics

```bash
# Get stats
curl http://localhost:8001/api/ab_test/stats | python3 -m json.tool
```

Expected output:
```json
{
    "stats": [
        {
            "ab_group": "control",
            "user_count": 10,
            "total_events": 45,
            "tasks_completed": 30,
            "checkins": 10,
            "rewards_redeemed": 0
        },
        {
            "ab_group": "experimental",
            "user_count": 10,
            "total_events": 60,
            "tasks_completed": 35,
            "checkins": 15,
            "rewards_redeemed": 10
        }
    ],
    "timestamp": "2025-12-16T19:00:00"
}
```

## Database Schema

The backend uses SQLite with these tables:

### ab_test_events
```sql
CREATE TABLE ab_test_events (
    id INTEGER PRIMARY KEY,
    user_id TEXT NOT NULL,
    session_id INTEGER,
    ab_group TEXT,            -- "control" or "experimental"
    event_type TEXT,          -- "task_complete", "checkin", "reward_redeem"
    event_data TEXT,          -- JSON string with event details
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### organizations
```sql
CREATE TABLE organizations (
    id INTEGER PRIMARY KEY,
    user_id TEXT NOT NULL,
    name TEXT,
    mission TEXT,
    org_type TEXT,
    service_area TEXT,
    demographics TEXT,
    funders TEXT,
    theory_of_change TEXT,
    created_at TIMESTAMP
);
```

### grants
```sql
CREATE TABLE grants (
    id INTEGER PRIMARY KEY,
    title TEXT NOT NULL,
    funder TEXT,
    amount_min INTEGER,
    amount_max INTEGER,
    eligibility TEXT,
    deadline TEXT,
    description TEXT,
    created_at TIMESTAMP
);
```

## API Endpoints

### POST /api/research/organization
Research organization from URL or description.

**Request:**
```json
{
  "user_id": "string",
  "url": "https://organization.com" (optional),
  "description": "Organization description" (optional)
}
```

**Response:**
```json
{
  "org_id": 1,
  "data": {
    "name": "Organization Name",
    "mission": "Mission statement",
    "org_type": "workforce development, faith based",
    "service_area": "Lake County IL, Cook County IL",
    "demographics": "Young adults 18-24",
    "funders": "Gates Foundation, Local Government",
    "theory_of_change": "By providing training..."
  }
}
```

### GET /api/grants/match/{org_id}
Get matching grants for an organization.

**Response:**
```json
[
  {
    "grant_id": 1,
    "title": "Workforce Development Grant 2025",
    "funder": "Department of Labor",
    "alignment_score": 78.5
  }
]
```

### POST /api/ab_test/event
Record an A/B test event from the Swift app.

**Request:**
```json
{
  "user_id": "string",
  "session_id": 123,
  "ab_group": "experimental",
  "event_type": "task_complete",
  "event_data": {
    "task_id": "hvac_1",
    "points_earned": 50
  }
}
```

### GET /api/ab_test/stats
Get A/B test statistics comparing control vs experimental groups.

## Next Steps

1. **Add More Grants**: Use the `/api/grants/add` endpoint to populate the grants database
2. **Enhance Matching**: Implement proper vector embeddings for better grant matching
3. **Add Analytics Dashboard**: Create a web interface to visualize A/B test results
4. **Implement Screens 3-7**: Add the remaining platform features

## Troubleshooting

### Service won't start
- Check if port 8001 is available: `lsof -i :8001`
- Ensure Ollama is running: `ollama list`
- Check Python environment: `source venv/bin/activate`

### Events not recording
- Verify backend is running: `curl http://localhost:8001/health`
- Check Swift app network permissions
- For physical devices, use Mac IP address instead of localhost

### Ollama not connecting
- Start Ollama: `ollama serve`
- Verify models: `ollama list`
- Pull llama3 if needed: `ollama pull llama3`

## Files Created

```
~/Desktop/grant_platform_services/
├── main.py                    # FastAPI service
├── requirements.txt           # Python dependencies
├── databases/
│   └── grant_platform.db     # SQLite database
└── venv/                      # Python virtual environment
```

## Summary

You now have a functional MVP that:
- ✅ Researches organizations using AI
- ✅ Matches grants to organizations
- ✅ Collects A/B test data from your Swift app
- ✅ Provides analytics on engagement

The Swift app acts as the **data collection instrument** for measuring program effectiveness between control and experimental groups (with/without rewards).
