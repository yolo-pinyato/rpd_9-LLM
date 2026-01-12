# Data Collection Summary
## Comprehensive App Data Tracking

This document outlines all data being collected and stored in the `workforce_dev.sqlite` database.

## Overview

The app now collects comprehensive data from all user interactions and stores it in a SQLite database accessible from the Desktop.

## Data Tables

### 1. users
**What's Collected:**
- User ID, name, email
- Goals (array of user-selected goals)
- Points balance and current streak
- Total tasks completed
- Selected learning track
- Admin status
- Account creation timestamp

**When Data is Saved:**
- On user registration/onboarding
- After completing tasks (points update)
- After check-ins (points update)
- When track is selected
- Manual state save

### 2. tasks
**What's Collected:**
- Task ID, title, description
- Category (Learning, Quiz, Practice)
- Estimated time and point value
- Difficulty level
- Track type (HVAC, Nursing, etc.)
- Completion status and date

**When Data is Saved:**
- When user selects a track (tasks generated)
- When task is completed
- Manual task creation by admin

### 3. check_ins
**What's Collected:**
- Check-in ID and user ID
- Timestamp (GMT timezone)
- QR code data
- Location
- Points awarded

**When Data is Saved:**
- When user scans QR code for check-in
- Once per day limit enforced

### 4. pulse_surveys
**What's Collected:**
- User ID and session ID
- Weekly feeling rating (1-5)
- Weekly feeling reason (optional text)
- Program feeling rating (1-5)
- Program feeling reason (optional text)
- Submission timestamp

**When Data is Saved:**
- When user completes weekly pulse survey
- Award 500 points per survey

### 5. events
**What's Collected:**
- User ID and session ID
- Screen name (which tab/view)
- Action type (see list below)
- Action detail (additional context)
- Timestamp

**When Data is Saved:**
Real-time logging for:
- `app_launched` - App initialization
- `tab_changed` - Navigation between tabs (Home, Tasks, Resources, Rewards, Profile, Admin)
- `task_viewed` - When user opens task detail
- `task_completed` - When task is marked complete
- `content_generated` - AI content generation (success/failure)
- `check_in` - QR code scan
- `reward_redeemed` - Points spent (if implemented)
- `track_selected` - Learning track chosen
- `admin_settings_updated` - Settings modified
- `app_state_saved` - Manual state persistence
- `resource_accessed` - Resource view/download (when implemented)

### 6. reward_redemptions
**What's Collected:**
- User ID and session ID
- Reward title
- Points cost
- Redemption timestamp

**When Data is Saved:**
- When user redeems points for rewards

### 7. admin_settings
**What's Collected:**
- Total budget and program length
- Expected users per week
- Max budget per week
- Auto-allocate points flag
- Points per check-in/task/quiz
- Claude API fallback settings
- API key (if configured)

**When Data is Saved:**
- On first app launch (defaults)
- When admin updates settings
- Manual state save

### 8. user_events
**What's Collected:**
- User ID
- Event type
- Event data (JSON or string)
- Timestamp

**When Data is Saved:**
- Additional event tracking beyond events table
- Custom events can be logged here

## Logging Functions

### Available Logging Methods

```swift
// In CompleteAppViewModel

// Log tab navigation
func logTabChange(to tab: Int)
// Usage: Automatically called when user switches tabs

// Log task views
func logTaskView(task: LearningTask)
// Usage: Called when TaskDetailView appears

// Log resource access
func logResourceAccess(resource: String)
// Usage: Call when user opens/downloads resources

// Log content generation
func logContentGeneration(task: LearningTask, success: Bool)
// Usage: Called after AI content generation attempt

// Save current state
func saveAppState()
// Usage: Manual persist of user and admin settings
```

### Database Manager Methods

```swift
// In EnhancedDatabaseManager

// General event logging
func logEvent(userId: String, eventType: String, eventData: String? = nil)

// User operations
func createUser(_ user: User)
func updateUser(_ user: User)
func getUser(id: String) -> User?

// Task operations
func createTask(_ task: LearningTask)
func getTasks(forTrack track: TrackType?) -> [LearningTask]

// Check-in tracking
func recordCheckIn(_ checkIn: CheckInEvent)
func getCheckIns(forUser userId: String) -> [CheckInEvent]

// Settings
func updateAdminSettings(_ settings: AdminSettings)
func getAdminSettings() -> AdminSettings

// Export
func exportDatabaseToDesktop() -> String?
func getDatabasePath() -> String
```

## Current Data Collection Status

### ✅ Fully Implemented
- User profiles and authentication
- Task creation and completion
- Check-in tracking
- Event logging (navigation, views, actions)
- Admin settings persistence
- Database export functionality

### ⚠️ Partially Implemented
- Pulse surveys (table exists, UI needs integration)
- Reward redemptions (structure exists, needs implementation)
- Resource tracking (function exists, needs UI integration)

### 📊 Data Analytics Available

With current data collection, you can analyze:

**User Engagement:**
- Daily active users
- Session duration (via events timestamps)
- Most used features (tab_changed events)
- Drop-off points

**Learning Progress:**
- Task completion rates by track
- Average time to complete tracks
- Points earned over time
- Streak maintenance

**Content Performance:**
- Most viewed tasks
- Content generation success rate
- Time spent on each task
- Which content leads to task completion

**Check-in Behavior:**
- Check-in frequency
- Check-in times/patterns
- Location preferences
- Check-in streaks

## Exporting Data

### Method 1: Export Script
```bash
cd "/Users/chris/Desktop/RPD Apple Tests/rpd_9+LLM"
./export_database.sh
```

### Method 2: From App (add to admin panel)
```swift
if let path = EnhancedDatabaseManager.shared.exportDatabaseToDesktop() {
    print("Exported to: \(path)")
}
```

### Method 3: Direct Access
```bash
# Find most recent database
find ~/Library/Developer/CoreSimulator/Devices/*/data/Containers/Data/Application/*/Documents/workforce_dev.sqlite -exec ls -lt {} + | head -1

# Open with sqlite3
sqlite3 [path-to-database]
```

## Sample Queries

### User Activity Report
```sql
SELECT
    u.name,
    COUNT(DISTINCT e.screen) as screens_visited,
    COUNT(e.id) as total_actions,
    MAX(e.timestamp) as last_active
FROM users u
LEFT JOIN events e ON u.id = e.user_id
GROUP BY u.id
ORDER BY total_actions DESC;
```

### Task Completion Analysis
```sql
SELECT
    track_type,
    COUNT(*) as total_tasks,
    SUM(CASE WHEN is_completed = 1 THEN 1 ELSE 0 END) as completed,
    ROUND(AVG(CASE WHEN is_completed = 1 THEN point_value ELSE 0 END), 2) as avg_points
FROM tasks
GROUP BY track_type;
```

### Engagement Timeline
```sql
SELECT
    DATE(timestamp) as date,
    COUNT(DISTINCT user_id) as active_users,
    COUNT(*) as total_events
FROM events
GROUP BY DATE(timestamp)
ORDER BY date DESC
LIMIT 30;
```

### Content Generation Performance
```sql
SELECT
    action_detail as task_name,
    COUNT(*) as generation_attempts,
    SUM(CASE WHEN action_detail LIKE '%success%' THEN 1 ELSE 0 END) as successful,
    SUM(CASE WHEN action_detail LIKE '%failed%' THEN 1 ELSE 0 END) as failed
FROM events
WHERE action_type = 'content_generated'
GROUP BY action_detail;
```

## Privacy & Security

### What's NOT Collected
- Passwords (not stored in this database)
- Payment information
- Device identifiers beyond app scope
- Location beyond check-in locations
- Browsing history outside app

### Data Security
- Database stored locally in app sandbox
- Exported files not encrypted by default
- Consider encrypting exports for sensitive data
- No automatic cloud sync

### GDPR Compliance Considerations
- User data is identifiable (names, emails)
- Consider adding:
  - Data export for users
  - Data deletion capability
  - Privacy policy acceptance
  - Data retention policies

## Adding Custom Events

To add new event tracking:

```swift
// In your view or view model
EnhancedDatabaseManager.shared.logEvent(
    userId: viewModel.user.id,
    eventType: "custom_event_name",
    eventData: "optional details"
)

// Or use viewModel helper (if in CompleteAppViewModel context)
viewModel.db.logEvent(
    userId: user.id,
    eventType: "button_clicked",
    eventData: "button_name"
)
```

## Next Steps

### Recommended Additions

1. **Pulse Survey Integration**
   - Add UI button in Profile tab
   - Weekly reminder notification
   - Track sentiment over time

2. **Resource Tracking**
   - Call `logResourceAccess()` when resources viewed
   - Track which resources are most helpful
   - Correlate with task completion

3. **Automated Exports**
   - Daily database backups
   - Scheduled reports
   - Cloud backup option

4. **Analytics Dashboard**
   - Add in-app analytics view for admins
   - Real-time metrics
   - Exportable reports

5. **Data Visualization**
   - User progress charts
   - Engagement heatmaps
   - Track performance comparisons

## Support

For questions about:
- **Data structure**: See `rpd_9_LLMApp.swift` and `DatabaseManagerEnhanced.swift`
- **Exporting data**: See `DATABASE_ACCESS_GUIDE.md`
- **SQL queries**: See SQLite documentation

---

**Last Updated**: January 12, 2026
**Database Version**: 3.0
**Logging System**: Comprehensive event tracking
