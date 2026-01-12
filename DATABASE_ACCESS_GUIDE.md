# Database Access Guide
## Workforce Development App - External Database Access

This guide explains how to access and analyze the app's SQLite database from your Desktop.

## Quick Start

### Method 1: Export Script (Recommended)

```bash
cd "/Users/chris/Desktop/RPD Apple Tests/rpd_9+LLM"
./export_database.sh
```

This will:
- Find the most recent database from the iOS Simulator
- Copy it to your Desktop with a timestamp
- Show database statistics

### Method 2: From Within the App

Call the export function:
```swift
if let path = EnhancedDatabaseManager.shared.exportDatabaseToDesktop() {
    print("Database exported to: \(path)")
}
```

## Database Location

**Simulator Database:**
```
~/Library/Developer/CoreSimulator/Devices/[DEVICE_ID]/data/Containers/Data/Application/[APP_ID]/Documents/workforce_dev.sqlite
```

**Exported Database (Desktop):**
```
~/Desktop/workforce_dev_[TIMESTAMP].sqlite
```

## Database Schema

The database contains 9 tables:

### 1. users
Stores user profiles and progress
```sql
CREATE TABLE users (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    goals TEXT,
    points_balance INTEGER DEFAULT 0,
    current_streak INTEGER DEFAULT 0,
    total_tasks_completed INTEGER DEFAULT 0,
    selected_track TEXT,
    is_admin INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 2. tasks
Learning tasks and assignments
```sql
CREATE TABLE tasks (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    category TEXT,
    estimated_minutes INTEGER,
    point_value INTEGER,
    difficulty_level TEXT,
    track_type TEXT,
    is_completed INTEGER DEFAULT 0,
    completed_date TIMESTAMP
);
```

### 3. check_ins
QR code check-in events
```sql
CREATE TABLE check_ins (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    qr_code_data TEXT NOT NULL,
    location TEXT,
    points_awarded INTEGER,
    FOREIGN KEY (user_id) REFERENCES users(id)
);
```

### 4. pulse_surveys
Weekly pulse check surveys
```sql
CREATE TABLE pulse_surveys (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT,
    session_id INTEGER,
    week_rating INTEGER,
    week_feelings TEXT,
    program_rating INTEGER,
    program_feelings TEXT,
    submitted_at TEXT
);
```

### 5. events
User activity logging
```sql
CREATE TABLE events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT,
    session_id INTEGER,
    screen TEXT,
    action_type TEXT,
    action_detail TEXT,
    timestamp TEXT
);
```

### 6. reward_redemptions
Points spent on rewards
```sql
CREATE TABLE reward_redemptions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT,
    session_id INTEGER,
    reward_title TEXT,
    points_cost INTEGER,
    redeemed_at TEXT
);
```

### 7. admin_settings
Budget and point allocation settings
```sql
CREATE TABLE admin_settings (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    total_budget REAL,
    program_length_weeks INTEGER,
    expected_users_per_week INTEGER,
    max_budget_per_week REAL,
    auto_allocate_points INTEGER DEFAULT 1,
    points_per_check_in INTEGER DEFAULT 10,
    points_per_task_completion INTEGER DEFAULT 50,
    points_per_quiz_pass INTEGER DEFAULT 75
);
```

### 8. user_events
Additional user event tracking

### 9. sqlite_sequence
Auto-increment tracking (internal SQLite table)

## Accessing the Database

### Option 1: Command Line (sqlite3)

```bash
# Open the database
sqlite3 ~/Desktop/workforce_dev_[TIMESTAMP].sqlite

# List all tables
.tables

# View table schema
.schema users

# Query users
SELECT * FROM users;

# Query tasks by track
SELECT * FROM tasks WHERE track_type = 'hvac';

# Count completed tasks
SELECT COUNT(*) FROM tasks WHERE is_completed = 1;

# View recent check-ins
SELECT * FROM check_ins ORDER BY timestamp DESC LIMIT 10;

# Exit
.quit
```

### Option 2: DB Browser for SQLite (GUI)

1. **Download**: https://sqlitebrowser.org/
2. **Install** the application
3. **Open** the exported database file
4. **Browse Data**, run queries, and export results

### Option 3: Python Script

```python
import sqlite3
import pandas as pd

# Connect to database
conn = sqlite3.connect('/Users/chris/Desktop/workforce_dev_[TIMESTAMP].sqlite')

# Read data into DataFrame
users = pd.read_sql_query("SELECT * FROM users", conn)
tasks = pd.read_sql_query("SELECT * FROM tasks", conn)
check_ins = pd.read_sql_query("SELECT * FROM check_ins", conn)

# Analyze
print(f"Total Users: {len(users)}")
print(f"Total Tasks: {len(tasks)}")
print(f"Completed Tasks: {tasks['is_completed'].sum()}")
print(f"Total Check-ins: {len(check_ins)}")

# Close connection
conn.close()
```

## Common Queries

### User Statistics
```sql
SELECT
    name,
    points_balance,
    total_tasks_completed,
    current_streak,
    selected_track
FROM users
ORDER BY points_balance DESC;
```

### Task Completion Rate by Track
```sql
SELECT
    track_type,
    COUNT(*) as total_tasks,
    SUM(is_completed) as completed_tasks,
    ROUND(SUM(is_completed) * 100.0 / COUNT(*), 2) as completion_rate
FROM tasks
GROUP BY track_type;
```

### Recent Activity
```sql
SELECT
    events.screen,
    events.action_type,
    events.timestamp,
    users.name
FROM events
JOIN users ON events.user_id = users.id
ORDER BY events.timestamp DESC
LIMIT 20;
```

### Check-in Statistics
```sql
SELECT
    DATE(timestamp) as date,
    COUNT(*) as check_ins,
    SUM(points_awarded) as total_points
FROM check_ins
GROUP BY DATE(timestamp)
ORDER BY date DESC;
```

### Pulse Survey Trends
```sql
SELECT
    submitted_at,
    AVG(week_rating) as avg_weekly_feeling,
    AVG(program_rating) as avg_program_feeling
FROM pulse_surveys
GROUP BY DATE(submitted_at)
ORDER BY submitted_at DESC;
```

## Automated Export

### Schedule Regular Exports (macOS)

Create a cron job to export daily:

```bash
# Edit crontab
crontab -e

# Add this line (exports at 11 PM daily)
0 23 * * * cd "/Users/chris/Desktop/RPD Apple Tests/rpd_9+LLM" && ./export_database.sh
```

### Or use a LaunchAgent

Create `~/Library/LaunchAgents/com.workforcedev.dbexport.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.workforcedev.dbexport</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/chris/Desktop/RPD Apple Tests/rpd_9+LLM/export_database.sh</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>23</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
</dict>
</plist>
```

Load it:
```bash
launchctl load ~/Library/LaunchAgents/com.workforcedev.dbexport.plist
```

## Data Analysis Tools

### Recommended Tools
- **DB Browser for SQLite**: Visual database browser (Free)
- **TablePlus**: Modern database GUI (Free tier available)
- **DBeaver**: Universal database tool (Free)
- **Python + pandas**: For data analysis and visualization
- **R + RSQLite**: For statistical analysis

## Security Notes

- Database contains user information - handle securely
- Exported files are not encrypted
- Consider encrypting sensitive exports
- Don't commit database files to git repositories

## Troubleshooting

### Database not found
- Make sure the app has been run at least once
- Check that you're looking in the correct simulator device

### Export script fails
- Ensure the script has execute permissions: `chmod +x export_database.sh`
- Check that the path to the database is correct

### Can't open database
- Verify the file is not corrupted: `sqlite3 database.sqlite "PRAGMA integrity_check;"`
- Make sure you have read permissions

## Integration with Analytics

### Export to CSV
```bash
sqlite3 -header -csv workforce_dev.sqlite "SELECT * FROM users;" > users.csv
```

### Export to JSON
```bash
sqlite3 workforce_dev.sqlite "SELECT json_group_array(json_object(
    'name', name,
    'points', points_balance,
    'tasks', total_tasks_completed
)) FROM users;" > users.json
```

## Support

For questions about database structure or access, check:
- This guide
- The app's source code in `rpd_9_LLMApp.swift`
- SQLite documentation: https://www.sqlite.org/docs.html

---

**Last Updated**: January 12, 2026
**Database Version**: 3.0
