//
//  DatabaseManagerEnhanced.swift
//  rpd_9+LLM
//
//  Created by Chris on 11/19/25.
//


import Foundation
import SQLite3

// MARK: - Enhanced Database Manager with Track Management
class DatabaseManagerEnhanced {
    static let shared = DatabaseManagerEnhanced()
    private var db: OpaquePointer?
    private(set) var currentUserId: String = ""
    private(set) var currentSessionId: Int = 0
    
    private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    
    private init() {
        setupDatabase()
        loadOrCreateUserId()
        incrementSessionId()
        logEvent(screen: "App Launch", action: "app_started")
    }
    
    private func setupDatabase() {
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("workforce_dev.sqlite")
        
        print("📁 Database location: \(fileURL.path)")
        
        // Check version and reset if needed
        let versionFile = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("db_version.txt")
        
        let currentVersion = "3.0" // Updated version for new schema
        var needsReset = false
        
        if FileManager.default.fileExists(atPath: versionFile.path) {
            if let savedVersion = try? String(contentsOf: versionFile, encoding: .utf8) {
                if savedVersion != currentVersion {
                    needsReset = true
                    print("🔄 Database version mismatch. Old: \(savedVersion), New: \(currentVersion)")
                }
            }
        } else if FileManager.default.fileExists(atPath: fileURL.path) {
            needsReset = true
            print("🔄 Old database detected without version file")
        }
        
        if needsReset {
            print("🗑️  Deleting old database...")
            try? FileManager.default.removeItem(at: fileURL)
            print("✅ Old database deleted")
        }
        
        if sqlite3_open(fileURL.path, &db) != SQLITE_OK {
            print("Error opening database")
            return
        }
        
        createTables()
        insertDefaultData()
        
        try? currentVersion.write(to: versionFile, atomically: true, encoding: .utf8)
        print("✅ Database version: \(currentVersion)")
    }
    
    private func createTables() {
        // Existing tables
        let createUsersTable = """
        CREATE TABLE IF NOT EXISTS users (
            user_id TEXT PRIMARY KEY,
            race TEXT,
            income_level TEXT,
            housing_situation TEXT,
            goals TEXT,
            points_balance INTEGER,
            current_streak INTEGER,
            has_completed_onboarding INTEGER,
            created_at TEXT,
            last_session_id INTEGER DEFAULT 0,
            selected_track TEXT DEFAULT NULL,
            track_selected_at TEXT DEFAULT NULL
        );
        """
        
        let createTasksTable = """
        CREATE TABLE IF NOT EXISTS tasks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT,
            session_id INTEGER,
            task_id TEXT,
            task_title TEXT,
            task_type TEXT,
            track_type TEXT,
            points_earned INTEGER,
            completed_at TEXT,
            qr_code_data TEXT DEFAULT NULL
        );
        """
        
        let createPulseSurveysTable = """
        CREATE TABLE IF NOT EXISTS pulse_surveys (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT,
            session_id INTEGER,
            week_rating INTEGER,
            week_feelings TEXT,
            program_rating INTEGER,
            program_feelings TEXT,
            submitted_at TEXT
        );
        """
        
        let createRewardRedemptionsTable = """
        CREATE TABLE IF NOT EXISTS reward_redemptions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT,
            session_id INTEGER,
            reward_title TEXT,
            points_cost INTEGER,
            redeemed_at TEXT
        );
        """
        
        let createEventsTable = """
        CREATE TABLE IF NOT EXISTS events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT,
            session_id INTEGER,
            screen TEXT,
            action_type TEXT,
            action_detail TEXT,
            timestamp TEXT
        );
        """
        
        // NEW: Track content table for RAG content
        let createTrackContentTable = """
        CREATE TABLE IF NOT EXISTS track_content (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            track_type TEXT NOT NULL,
            content_type TEXT NOT NULL,
            title TEXT NOT NULL,
            description TEXT,
            content_text TEXT,
            difficulty_level TEXT,
            estimated_time_minutes INTEGER,
            points_value INTEGER,
            sequence_order INTEGER,
            created_at TEXT
        );
        """
        
        // NEW: Admin settings table
        let createAdminSettingsTable = """
        CREATE TABLE IF NOT EXISTS admin_settings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            setting_key TEXT UNIQUE NOT NULL,
            setting_value TEXT NOT NULL,
            updated_at TEXT
        );
        """
        
        // NEW: Point allocations table (for tracking automated point assignments)
        let createPointAllocationsTable = """
        CREATE TABLE IF NOT EXISTS point_allocations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT,
            task_id TEXT,
            allocated_points INTEGER,
            allocation_method TEXT,
            allocation_date TEXT,
            week_number INTEGER,
            budget_remaining REAL
        );
        """
        
        // NEW: User tracks table (history of track selections)
        let createUserTracksTable = """
        CREATE TABLE IF NOT EXISTS user_tracks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT,
            track_type TEXT,
            selected_at TEXT,
            is_active INTEGER DEFAULT 1
        );
        """
        
        // NEW: Check-ins table
        let createCheckInsTable = """
        CREATE TABLE IF NOT EXISTS check_ins (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT,
            session_id INTEGER,
            check_in_type TEXT,
            qr_code_data TEXT,
            location TEXT,
            checked_in_at TEXT,
            points_earned INTEGER
        );
        """

        executeSQL(createUsersTable)
        executeSQL(createTasksTable)
        executeSQL(createPulseSurveysTable)
        executeSQL(createRewardRedemptionsTable)
        executeSQL(createEventsTable)
        executeSQL(createTrackContentTable)
        executeSQL(createAdminSettingsTable)
        executeSQL(createPointAllocationsTable)
        executeSQL(createUserTracksTable)
        executeSQL(createCheckInsTable)
    }
    
    private func insertDefaultData() {
        // Insert default admin settings
        let defaultSettings = [
            ("total_budget", "10000.0"),
            ("program_length_weeks", "12"),
            ("expected_users_per_week", "50"),
            ("max_budget_per_week", "1000.0"),
            ("points_per_dollar", "100"),
            ("auto_allocate_points", "true"),
            ("check_in_points", "50"),
            ("quiz_pass_points", "100")
        ]
        
        for (key, value) in defaultSettings {
            let sql = """
            INSERT OR IGNORE INTO admin_settings (setting_key, setting_value, updated_at)
            VALUES (?, ?, ?);
            """
            var statement: OpaquePointer?
            let timestamp = ISO8601DateFormatter().string(from: Date())
            
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, key, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(statement, 2, value, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(statement, 3, timestamp, -1, SQLITE_TRANSIENT)
                sqlite3_step(statement)
            }
            sqlite3_finalize(statement)
        }
        
        // Insert sample track content
        insertSampleTrackContent()
    }
    
    private func insertSampleTrackContent() {
        let hvacContent = [
            ("HVAC Basics", "Introduction to HVAC systems", "beginner", 30, 250),
            ("Residential HVAC", "Learn residential HVAC installation", "intermediate", 45, 300),
            ("Commercial HVAC", "Master commercial systems", "advanced", 60, 400),
            ("HVAC Safety", "Safety protocols and procedures", "beginner", 20, 200)
        ]
        
        let nursingContent = [
            ("Nursing Fundamentals", "Core nursing principles", "beginner", 40, 250),
            ("Patient Care", "Essential patient care skills", "intermediate", 50, 300),
            ("Medical Terminology", "Learn medical language", "beginner", 30, 200),
            ("Clinical Procedures", "Advanced clinical skills", "advanced", 60, 400)
        ]
        
        let spiritualContent = [
            ("Bible Study Basics", "Introduction to Bible study", "beginner", 30, 200),
            ("Old Testament Overview", "Understanding the Old Testament", "intermediate", 45, 250),
            ("New Testament Overview", "Understanding the New Testament", "intermediate", 45, 250),
            ("Spiritual Practices", "Daily spiritual exercises", "beginner", 20, 150)
        ]
        
        let mentalHealthContent = [
            ("Mindfulness Basics", "Introduction to mindfulness", "beginner", 20, 150),
            ("Meditation Techniques", "Various meditation practices", "intermediate", 30, 200),
            ("Stress Management", "Managing stress effectively", "intermediate", 40, 250),
            ("Emotional Wellness", "Building emotional resilience", "advanced", 45, 300)
        ]
        
        insertContentForTrack("hvac", hvacContent)
        insertContentForTrack("nursing", nursingContent)
        insertContentForTrack("spiritual", spiritualContent)
        insertContentForTrack("mental_health", mentalHealthContent)
    }
    
    private func insertContentForTrack(_ trackType: String, _ content: [(String, String, String, Int, Int)]) {
        for (index, item) in content.enumerated() {
            let sql = """
            INSERT OR IGNORE INTO track_content 
            (track_type, content_type, title, description, difficulty_level, estimated_time_minutes, points_value, sequence_order, created_at)
            VALUES (?, 'learning_module', ?, ?, ?, ?, ?, ?, ?);
            """
            var statement: OpaquePointer?
            let timestamp = ISO8601DateFormatter().string(from: Date())
            
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, trackType, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(statement, 2, item.0, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(statement, 3, item.1, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(statement, 4, item.2, -1, SQLITE_TRANSIENT)
                sqlite3_bind_int(statement, 5, Int32(item.3))
                sqlite3_bind_int(statement, 6, Int32(item.4))
                sqlite3_bind_int(statement, 7, Int32(index))
                sqlite3_bind_text(statement, 8, timestamp, -1, SQLITE_TRANSIENT)
                sqlite3_step(statement)
            }
            sqlite3_finalize(statement)
        }
    }
    
    // MARK: - Track Management
    
    func saveUserTrack(trackType: String) {
        // Deactivate old tracks
        let deactivateSql = "UPDATE user_tracks SET is_active = 0 WHERE user_id = ?;"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, deactivateSql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, currentUserId, -1, SQLITE_TRANSIENT)
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
        
        // Insert new track
        let sql = """
        INSERT INTO user_tracks (user_id, track_type, selected_at, is_active)
        VALUES (?, ?, ?, 1);
        """
        
        statement = nil
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, currentUserId, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 2, trackType, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 3, timestamp, -1, SQLITE_TRANSIENT)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("✅ Track saved: \(trackType)")
                
                // Update user's selected track
                updateUserSelectedTrack(trackType: trackType)
                logEvent(screen: "Track Selection", action: "track_selected", detail: trackType)
            }
        }
        sqlite3_finalize(statement)
    }
    
    private func updateUserSelectedTrack(trackType: String) {
        let sql = """
        UPDATE users SET selected_track = ?, track_selected_at = ? WHERE user_id = ?;
        """
        var statement: OpaquePointer?
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, trackType, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 2, timestamp, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 3, currentUserId, -1, SQLITE_TRANSIENT)
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
    }
    
    func getUserSelectedTrack() -> String? {
        let sql = "SELECT selected_track FROM users WHERE user_id = ?;"
        var statement: OpaquePointer?
        var trackType: String?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, currentUserId, -1, SQLITE_TRANSIENT)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                if let trackPtr = sqlite3_column_text(statement, 0) {
                    trackType = String(cString: trackPtr)
                }
            }
        }
        sqlite3_finalize(statement)
        return trackType
    }
    
    func loadTrackContent(trackType: String) -> [TrackContentItem] {
        let sql = """
        SELECT id, title, description, difficulty_level, estimated_time_minutes, points_value, sequence_order
        FROM track_content
        WHERE track_type = ?
        ORDER BY sequence_order;
        """
        var statement: OpaquePointer?
        var items: [TrackContentItem] = []
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, trackType, -1, SQLITE_TRANSIENT)
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                let title = String(cString: sqlite3_column_text(statement, 1))
                let description = String(cString: sqlite3_column_text(statement, 2))
                let difficulty = String(cString: sqlite3_column_text(statement, 3))
                let timeMinutes = Int(sqlite3_column_int(statement, 4))
                let points = Int(sqlite3_column_int(statement, 5))
                let order = Int(sqlite3_column_int(statement, 6))
                
                items.append(TrackContentItem(
                    id: id,
                    title: title,
                    description: description,
                    difficultyLevel: difficulty,
                    estimatedTimeMinutes: timeMinutes,
                    pointsValue: points,
                    sequenceOrder: order
                ))
            }
        }
        sqlite3_finalize(statement)
        return items
    }
    
    // MARK: - Check-In Management

    func saveCheckIn(qrCodeData: String, location: String = "", pointsEarned: Int) {
        let sql = """
        INSERT INTO check_ins (user_id, session_id, check_in_type, qr_code_data, location, checked_in_at, points_earned)
        VALUES (?, ?, 'qr_code', ?, ?, ?, ?);
        """
        var statement: OpaquePointer?
        let timestamp = ISO8601DateFormatter().string(from: Date())

        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, currentUserId, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(statement, 2, Int32(currentSessionId))
            sqlite3_bind_text(statement, 3, qrCodeData, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 4, location, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 5, timestamp, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(statement, 6, Int32(pointsEarned))

            if sqlite3_step(statement) == SQLITE_DONE {
                print("✅ Check-in saved: \(qrCodeData)")
                logEvent(screen: "Check-In", action: "qr_code_scanned", detail: qrCodeData)
            }
        }
        sqlite3_finalize(statement)
    }
    
    // MARK: - Admin Settings
    
    func getAdminSetting(key: String) -> String? {
        let sql = "SELECT setting_value FROM admin_settings WHERE setting_key = ?;"
        var statement: OpaquePointer?
        var value: String?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, key, -1, SQLITE_TRANSIENT)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                value = String(cString: sqlite3_column_text(statement, 0))
            }
        }
        sqlite3_finalize(statement)
        return value
    }
    
    func updateAdminSetting(key: String, value: String) {
        let sql = """
        INSERT OR REPLACE INTO admin_settings (setting_key, setting_value, updated_at)
        VALUES (?, ?, ?);
        """
        var statement: OpaquePointer?
        let timestamp = ISO8601DateFormatter().string(from: Date())

        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, key, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 2, value, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 3, timestamp, -1, SQLITE_TRANSIENT)

            if sqlite3_step(statement) == SQLITE_DONE {
                print("✅ Admin setting updated: \(key) = \(value)")
            }
        }
        sqlite3_finalize(statement)
    }

    // MARK: - Content Caching for Performance

    /// Get cached generated content for a task
    func getCachedContent(taskId: String, trackType: String) async -> String? {
        let sql = """
        SELECT content_text FROM track_content
        WHERE track_type = ? AND title = (SELECT task_title FROM tasks WHERE task_id = ? LIMIT 1)
        LIMIT 1;
        """
        var statement: OpaquePointer?
        var cachedContent: String?

        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, trackType, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 2, taskId, -1, SQLITE_TRANSIENT)

            if sqlite3_step(statement) == SQLITE_ROW {
                if let textPtr = sqlite3_column_text(statement, 0) {
                    cachedContent = String(cString: textPtr)
                    print("✅ Cache hit for task: \(taskId)")
                }
            }
        }
        sqlite3_finalize(statement)
        return cachedContent
    }

    /// Cache generated content for future use
    func cacheContent(taskId: String, trackType: String, content: String) async {
        // First, get task title
        let getTaskSQL = "SELECT task_title FROM tasks WHERE task_id = ? LIMIT 1;"
        var taskStatement: OpaquePointer?
        var taskTitle = ""

        if sqlite3_prepare_v2(db, getTaskSQL, -1, &taskStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(taskStatement, 1, taskId, -1, SQLITE_TRANSIENT)
            if sqlite3_step(taskStatement) == SQLITE_ROW {
                taskTitle = String(cString: sqlite3_column_text(taskStatement, 0))
            }
        }
        sqlite3_finalize(taskStatement)

        guard !taskTitle.isEmpty else { return }

        // Check if content already exists
        let checkSQL = "SELECT id FROM track_content WHERE track_type = ? AND title = ?;"
        var checkStatement: OpaquePointer?
        var exists = false

        if sqlite3_prepare_v2(db, checkSQL, -1, &checkStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(checkStatement, 1, trackType, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(checkStatement, 2, taskTitle, -1, SQLITE_TRANSIENT)
            exists = sqlite3_step(checkStatement) == SQLITE_ROW
        }
        sqlite3_finalize(checkStatement)

        if exists {
            // Update existing content
            let updateSQL = """
            UPDATE track_content
            SET content_text = ?, created_at = ?
            WHERE track_type = ? AND title = ?;
            """
            var updateStatement: OpaquePointer?
            let timestamp = ISO8601DateFormatter().string(from: Date())

            if sqlite3_prepare_v2(db, updateSQL, -1, &updateStatement, nil) == SQLITE_OK {
                sqlite3_bind_text(updateStatement, 1, content, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(updateStatement, 2, timestamp, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(updateStatement, 3, trackType, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(updateStatement, 4, taskTitle, -1, SQLITE_TRANSIENT)

                if sqlite3_step(updateStatement) == SQLITE_DONE {
                    print("✅ Content cache updated for: \(taskTitle)")
                }
            }
            sqlite3_finalize(updateStatement)
        } else {
            // Insert new cached content
            let insertSQL = """
            INSERT INTO track_content (track_type, content_type, title, content_text, created_at)
            VALUES (?, 'learning_module', ?, ?, ?);
            """
            var insertStatement: OpaquePointer?
            let timestamp = ISO8601DateFormatter().string(from: Date())

            if sqlite3_prepare_v2(db, insertSQL, -1, &insertStatement, nil) == SQLITE_OK {
                sqlite3_bind_text(insertStatement, 1, trackType, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(insertStatement, 2, taskTitle, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(insertStatement, 3, content, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(insertStatement, 4, timestamp, -1, SQLITE_TRANSIENT)

                if sqlite3_step(insertStatement) == SQLITE_DONE {
                    print("✅ Content cached for task: \(taskTitle)")
                }
            }
            sqlite3_finalize(insertStatement)
        }
    }
    
    func getAllAdminSettings() -> [String: String] {
        let sql = "SELECT setting_key, setting_value FROM admin_settings;"
        var statement: OpaquePointer?
        var settings: [String: String] = [:]
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let key = String(cString: sqlite3_column_text(statement, 0))
                let value = String(cString: sqlite3_column_text(statement, 1))
                settings[key] = value
            }
        }
        sqlite3_finalize(statement)
        return settings
    }
    
    // MARK: - Point Allocation Algorithm
    
    func calculateAutomatedPoints(taskType: String, difficulty: String = "intermediate") -> Int {
        guard let autoAllocate = getAdminSetting(key: "auto_allocate_points"),
              autoAllocate.lowercased() == "true" else {
            // Manual mode - return base points
            return getBasePoints(taskType: taskType, difficulty: difficulty)
        }
        
        // Get admin parameters
        guard let totalBudgetStr = getAdminSetting(key: "total_budget"),
              let totalBudget = Double(totalBudgetStr),
              let programLengthStr = getAdminSetting(key: "program_length_weeks"),
              let programLength = Int(programLengthStr),
              let expectedUsersStr = getAdminSetting(key: "expected_users_per_week"),
              let expectedUsers = Int(expectedUsersStr),
              let maxWeeklyBudgetStr = getAdminSetting(key: "max_budget_per_week"),
              let maxWeeklyBudget = Double(maxWeeklyBudgetStr),
              let pointsPerDollarStr = getAdminSetting(key: "points_per_dollar"),
              let pointsPerDollar = Int(pointsPerDollarStr) else {
            return getBasePoints(taskType: taskType, difficulty: difficulty)
        }
        
        // Calculate current week
        let currentWeek = getCurrentProgramWeek()
        
        // Get budget used this week
        let weeklyBudgetUsed = getWeeklyBudgetUsed(week: currentWeek)
        let weeklyBudgetRemaining = maxWeeklyBudget - weeklyBudgetUsed
        
        // Calculate available points for this week
        let availablePointsThisWeek = Int(weeklyBudgetRemaining * Double(pointsPerDollar))
        
        // Get base points for task
        var basePoints = getBasePoints(taskType: taskType, difficulty: difficulty)
        
        // Calculate task count this week
        let tasksCompletedThisWeek = getTasksCompletedThisWeek(week: currentWeek)
        let estimatedTasksRemaining = (expectedUsers * 5) - tasksCompletedThisWeek // Assume 5 tasks per user
        
        // Adjust points based on budget availability
        if estimatedTasksRemaining > 0 {
            let averagePointsPerTask = availablePointsThisWeek / max(estimatedTasksRemaining, 1)
            
            // Cap points to ensure budget doesn't run out too quickly
            basePoints = min(basePoints, averagePointsPerTask)
        }
        
        // Ensure minimum points
        basePoints = max(basePoints, 50)
        
        // Apply difficulty multiplier
        let difficultyMultiplier: Double = {
            switch difficulty.lowercased() {
            case "beginner": return 0.8
            case "intermediate": return 1.0
            case "advanced": return 1.3
            default: return 1.0
            }
        }()
        
        let finalPoints = Int(Double(basePoints) * difficultyMultiplier)
        
        // Log allocation
        savePointAllocation(
            taskType: taskType,
            points: finalPoints,
            method: "automated",
            week: currentWeek,
            budgetRemaining: weeklyBudgetRemaining
        )
        
        print("💰 Automated Points Calculation:")
        print("   Task: \(taskType) (\(difficulty))")
        print("   Week: \(currentWeek)")
        print("   Weekly Budget Used: $\(String(format: "%.2f", weeklyBudgetUsed)) / $\(String(format: "%.2f", maxWeeklyBudget))")
        print("   Points Allocated: \(finalPoints)")
        
        return finalPoints
    }
    
    private func getBasePoints(taskType: String, difficulty: String) -> Int {
        switch taskType.lowercased() {
        case "check_in":
            return Int(getAdminSetting(key: "check_in_points") ?? "50") ?? 50
        case "quiz":
            return Int(getAdminSetting(key: "quiz_pass_points") ?? "100") ?? 100
        case "learning_module":
            switch difficulty.lowercased() {
            case "beginner": return 200
            case "intermediate": return 300
            case "advanced": return 400
            default: return 250
            }
        case "pulse_survey":
            return 500
        default:
            return 100
        }
    }
    
    private func getCurrentProgramWeek() -> Int {
        // Calculate based on first user's creation date
        let sql = "SELECT MIN(created_at) FROM users;"
        var statement: OpaquePointer?
        var week = 1
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                if let dateStr = sqlite3_column_text(statement, 0) {
                    let dateString = String(cString: dateStr)
                    if let startDate = ISO8601DateFormatter().date(from: dateString) {
                        let daysSinceStart = Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
                        week = (daysSinceStart / 7) + 1
                    }
                }
            }
        }
        sqlite3_finalize(statement)
        return week
    }
    
    private func getWeeklyBudgetUsed(week: Int) -> Double {
        let sql = """
        SELECT SUM(allocated_points) FROM point_allocations 
        WHERE week_number = ?;
        """
        var statement: OpaquePointer?
        var totalPoints = 0.0
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(week))
            
            if sqlite3_step(statement) == SQLITE_ROW {
                totalPoints = sqlite3_column_double(statement, 0)
            }
        }
        sqlite3_finalize(statement)
        
        // Convert points to dollars
        let pointsPerDollar = Double(getAdminSetting(key: "points_per_dollar") ?? "100") ?? 100.0
        return totalPoints / pointsPerDollar
    }
    
    private func getTasksCompletedThisWeek(week: Int) -> Int {
        let sql = "SELECT COUNT(*) FROM point_allocations WHERE week_number = ?;"
        var statement: OpaquePointer?
        var count = 0
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(week))
            
            if sqlite3_step(statement) == SQLITE_ROW {
                count = Int(sqlite3_column_int(statement, 0))
            }
        }
        sqlite3_finalize(statement)
        return count
    }
    
    private func savePointAllocation(taskType: String, points: Int, method: String, week: Int, budgetRemaining: Double) {
        let sql = """
        INSERT INTO point_allocations (user_id, task_id, allocated_points, allocation_method, allocation_date, week_number, budget_remaining)
        VALUES (?, ?, ?, ?, ?, ?, ?);
        """
        var statement: OpaquePointer?
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, currentUserId, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 2, taskType, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(statement, 3, Int32(points))
            sqlite3_bind_text(statement, 4, method, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 5, timestamp, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(statement, 6, Int32(week))
            sqlite3_bind_double(statement, 7, budgetRemaining)
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
    }
    
    // MARK: - Helper Methods (from original DatabaseManager)
    
    private func loadOrCreateUserId() {
        let sql = "SELECT user_id FROM users LIMIT 1;"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                if let userIdPtr = sqlite3_column_text(statement, 0) {
                    let loadedUserId = String(cString: userIdPtr)
                    if !loadedUserId.isEmpty {
                        currentUserId = loadedUserId
                        print("✅ Loaded existing user ID: \(currentUserId)")
                    } else {
                        currentUserId = UUID().uuidString
                        print("🆕 Empty user ID found, created new: \(currentUserId)")
                    }
                } else {
                    currentUserId = UUID().uuidString
                    print("🆕 Created new user ID: \(currentUserId)")
                }
            } else {
                currentUserId = UUID().uuidString
                print("🆕 Created new user ID: \(currentUserId)")
            }
        } else {
            currentUserId = UUID().uuidString
            print("🆕 Created new user ID: \(currentUserId)")
        }
        
        sqlite3_finalize(statement)
    }
    
    private func incrementSessionId() {
        let sql = "SELECT last_session_id FROM users WHERE user_id = ?;"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, currentUserId, -1, SQLITE_TRANSIENT)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                let columnType = sqlite3_column_type(statement, 0)
                if columnType == SQLITE_NULL {
                    currentSessionId = 1
                } else {
                    currentSessionId = Int(sqlite3_column_int(statement, 0)) + 1
                }
            } else {
                currentSessionId = 1
            }
        } else {
            currentSessionId = 1
        }
        
        sqlite3_finalize(statement)
        
        let updateSql = "UPDATE users SET last_session_id = ? WHERE user_id = ?;"
        var updateStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, updateSql, -1, &updateStatement, nil) == SQLITE_OK {
            sqlite3_bind_int(updateStatement, 1, Int32(currentSessionId))
            sqlite3_bind_text(updateStatement, 2, currentUserId, -1, SQLITE_TRANSIENT)
            
            if sqlite3_step(updateStatement) == SQLITE_DONE {
                print("📊 Session ID: \(currentSessionId)")
            }
        }
        
        sqlite3_finalize(updateStatement)
    }
    
    func logEvent(screen: String, action: String, detail: String = "") {
        let sql = """
        INSERT INTO events (user_id, session_id, screen, action_type, action_detail, timestamp)
        VALUES (?, ?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, currentUserId, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(statement, 2, Int32(currentSessionId))
            sqlite3_bind_text(statement, 3, screen, -1, nil)
            sqlite3_bind_text(statement, 4, action, -1, nil)
            sqlite3_bind_text(statement, 5, detail, -1, nil)
            sqlite3_bind_text(statement, 6, timestamp, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("📝 Event logged: [\(screen)] \(action) - \(detail)")
            }
        }
        
        sqlite3_finalize(statement)
    }
    
    private func executeSQL(_ sql: String) {
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_DONE {
                print("SQL executed successfully")
            }
        }
        
        sqlite3_finalize(statement)
    }
    
    deinit {
        sqlite3_close(db)
    }
    
    // MARK: - User Management Methods
    
    func getUser(id: String) -> User? {
        let sql = """
        SELECT user_id, race, income_level, housing_situation, goals, points_balance, 
               current_streak, has_completed_onboarding, selected_track
        FROM users WHERE user_id = ?;
        """
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, id, -1, SQLITE_TRANSIENT)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                let userId = String(cString: sqlite3_column_text(statement, 0))
                let race = String(cString: sqlite3_column_text(statement, 1))
                let incomeLevel = String(cString: sqlite3_column_text(statement, 2))
                let housingSituation = String(cString: sqlite3_column_text(statement, 3))
                let goalsString = String(cString: sqlite3_column_text(statement, 4))
                let pointsBalance = Int(sqlite3_column_int(statement, 5))
                let currentStreak = Int(sqlite3_column_int(statement, 6))
                let hasCompletedOnboarding = sqlite3_column_int(statement, 7) == 1
                
                var selectedTrack: TrackType? = nil
                if let trackPtr = sqlite3_column_text(statement, 8) {
                    let trackString = String(cString: trackPtr)
                    selectedTrack = TrackType(rawValue: trackString)
                }
                
                let goals = goalsString.isEmpty ? [] : goalsString.split(separator: ",").map(String.init)
                
                // Check if user is admin (simple check - test_user_001 or user_001)
                let isAdmin = userId == "test_user_001" || userId == "user_001"
                
                // Get total tasks completed
                let tasksCompleted = getTasksCompletedCount(userId: userId)
                
                sqlite3_finalize(statement)
                
                // Create name and email from race/income if they exist
                let name = race.isEmpty ? "User" : race
                let email = "\(userId)@test.com"
                
                return User(
                    id: userId,
                    name: name,
                    email: email,
                    goals: goals,
                    pointsBalance: pointsBalance,
                    currentStreak: currentStreak,
                    totalTasksCompleted: tasksCompleted,
                    selectedTrack: selectedTrack,
                    isAdmin: isAdmin
                )
            }
        }
        
        sqlite3_finalize(statement)
        return nil
    }
    
    func saveUser(_ user: User) {
        let goalsString = user.goals.joined(separator: ",")
        let dateString = ISO8601DateFormatter().string(from: Date())
        let trackString = user.selectedTrack?.rawValue ?? ""
        
        let sql = """
        INSERT OR REPLACE INTO users 
        (user_id, race, income_level, housing_situation, goals, points_balance, 
         current_streak, has_completed_onboarding, created_at, last_session_id, selected_track)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?);
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, user.id, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 2, user.name, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 3, "", -1, SQLITE_TRANSIENT) // income_level
            sqlite3_bind_text(statement, 4, "", -1, SQLITE_TRANSIENT) // housing_situation
            sqlite3_bind_text(statement, 5, goalsString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(statement, 6, Int32(user.pointsBalance))
            sqlite3_bind_int(statement, 7, Int32(user.currentStreak))
            sqlite3_bind_int(statement, 8, 1) // has_completed_onboarding
            sqlite3_bind_text(statement, 9, dateString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 10, trackString, -1, SQLITE_TRANSIENT)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("✅ User saved: \(user.name) (\(user.id))")
            }
        }
        
        sqlite3_finalize(statement)
    }
    
    func updateUser(_ user: User) {
        let goalsString = user.goals.joined(separator: ",")
        let trackString = user.selectedTrack?.rawValue ?? ""
        
        let sql = """
        UPDATE users SET 
        race = ?, goals = ?, points_balance = ?, current_streak = ?, selected_track = ?
        WHERE user_id = ?;
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, user.name, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 2, goalsString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(statement, 3, Int32(user.pointsBalance))
            sqlite3_bind_int(statement, 4, Int32(user.currentStreak))
            sqlite3_bind_text(statement, 5, trackString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 6, user.id, -1, SQLITE_TRANSIENT)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("✅ User updated: \(user.name)")
            }
        }
        
        sqlite3_finalize(statement)
    }
    
    func getTasks(forTrack track: TrackType? = nil) -> [LearningTask] {
        var sql = """
        SELECT task_id, task_title, task_type, track_type, points_earned, completed_at
        FROM tasks WHERE user_id = ?
        """
        
        if let track = track {
            sql += " AND track_type = '\(track.rawValue)'"
        }
        
        sql += " ORDER BY completed_at DESC;"
        
        var statement: OpaquePointer?
        var tasks: [LearningTask] = []
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, currentUserId, -1, SQLITE_TRANSIENT)
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let taskId = String(cString: sqlite3_column_text(statement, 0))
                let title = String(cString: sqlite3_column_text(statement, 1))
                let taskType = String(cString: sqlite3_column_text(statement, 2))
                let points = Int(sqlite3_column_int(statement, 4))
                
                var trackType: TrackType? = nil
                if let trackPtr = sqlite3_column_text(statement, 3) {
                    let trackString = String(cString: trackPtr)
                    trackType = TrackType(rawValue: trackString)
                }
                
                var completedDate: Date? = nil
                if let datePtr = sqlite3_column_text(statement, 5) {
                    let dateString = String(cString: datePtr)
                    completedDate = ISO8601DateFormatter().date(from: dateString)
                }
                
                let task = LearningTask(
                    id: taskId,
                    title: title,
                    description: "Task description",
                    category: taskType,
                    estimatedMinutes: 30,
                    pointValue: points,
                    difficultyLevel: "intermediate",
                    trackType: trackType,
                    isCompleted: completedDate != nil,
                    completedDate: completedDate
                )
                
                tasks.append(task)
            }
        }
        
        sqlite3_finalize(statement)
        return tasks
    }
    
    func getCheckIns(forUser userId: String) -> [CheckInEvent] {
        let sql = """
        SELECT id, qr_code_data, location, checked_in_at, points_earned
        FROM check_ins WHERE user_id = ?
        ORDER BY checked_in_at DESC;
        """
        
        var statement: OpaquePointer?
        var checkIns: [CheckInEvent] = []
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, userId, -1, SQLITE_TRANSIENT)
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(statement, 0))
                let qrCode = String(cString: sqlite3_column_text(statement, 1))
                
                var location: String? = nil
                if let locPtr = sqlite3_column_text(statement, 2) {
                    location = String(cString: locPtr)
                }
                
                let dateString = String(cString: sqlite3_column_text(statement, 3))
                let timestamp = ISO8601DateFormatter().date(from: dateString) ?? Date()
                let points = Int(sqlite3_column_int(statement, 4))
                
                let checkIn = CheckInEvent(
                    id: id,
                    userId: userId,
                    timestamp: timestamp,
                    qrCodeData: qrCode,
                    location: location,
                    pointsAwarded: points
                )
                
                checkIns.append(checkIn)
            }
        }
        
        sqlite3_finalize(statement)
        return checkIns
    }
    
    func saveCheckIn(_ checkIn: CheckInEvent) {
        let sql = """
        INSERT INTO check_ins (user_id, session_id, check_in_type, qr_code_data, location, checked_in_at, points_earned)
        VALUES (?, ?, 'qr_code', ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        let timestamp = ISO8601DateFormatter().string(from: checkIn.timestamp)
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, checkIn.userId, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(statement, 2, Int32(currentSessionId))
            sqlite3_bind_text(statement, 3, checkIn.qrCodeData, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 4, checkIn.location ?? "", -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 5, timestamp, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(statement, 6, Int32(checkIn.pointsAwarded))
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("✅ Check-in saved for user: \(checkIn.userId)")
            }
        }
        
        sqlite3_finalize(statement)
    }
    
    // MARK: - Pulse Survey Methods
    
    /// Save a pulse survey response to the database
    func savePulseSurvey(_ survey: PulseSurvey) {
        let sql = """
        INSERT INTO pulse_surveys (user_id, session_id, week_rating, week_feelings, program_rating, program_feelings, submitted_at)
        VALUES (?, ?, ?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        let timestamp = ISO8601DateFormatter().string(from: survey.timestamp)
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, survey.userId, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(statement, 2, Int32(currentSessionId))
            sqlite3_bind_int(statement, 3, Int32(survey.weeklyFeeling))
            sqlite3_bind_text(statement, 4, survey.weeklyFeelingReason ?? "", -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(statement, 5, Int32(survey.programFeeling))
            sqlite3_bind_text(statement, 6, survey.programFeelingReason ?? "", -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 7, timestamp, -1, SQLITE_TRANSIENT)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("✅ Pulse survey saved for user: \(survey.userId)")
            } else {
                print("❌ Error saving pulse survey: \(String(cString: sqlite3_errmsg(db)))")
            }
        } else {
            print("❌ Error preparing pulse survey statement: \(String(cString: sqlite3_errmsg(db)))")
        }
        
        sqlite3_finalize(statement)
    }
    
    /// Get all pulse surveys for the current user
    func getPulseSurveys(limit: Int = 10) -> [PulseSurvey] {
        let sql = """
        SELECT id, user_id, week_rating, week_feelings, program_rating, program_feelings, submitted_at
        FROM pulse_surveys
        WHERE user_id = ?
        ORDER BY submitted_at DESC
        LIMIT ?;
        """
        
        var statement: OpaquePointer?
        var surveys: [PulseSurvey] = []
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, currentUserId, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(statement, 2, Int32(limit))
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(statement, 0))
                let userId = String(cString: sqlite3_column_text(statement, 1))
                let weekRating = Int(sqlite3_column_int(statement, 2))
                let weekFeelingsPtr = sqlite3_column_text(statement, 3)
                let weekFeelings = weekFeelingsPtr != nil ? String(cString: weekFeelingsPtr!) : nil
                let programRating = Int(sqlite3_column_int(statement, 4))
                let programFeelingsPtr = sqlite3_column_text(statement, 5)
                let programFeelings = programFeelingsPtr != nil ? String(cString: programFeelingsPtr!) : nil
                let timestampString = String(cString: sqlite3_column_text(statement, 6))
                let timestamp = ISO8601DateFormatter().date(from: timestampString) ?? Date()
                
                let survey = PulseSurvey(
                    id: id,
                    userId: userId,
                    timestamp: timestamp,
                    weeklyFeeling: weekRating,
                    weeklyFeelingReason: weekFeelings,
                    programFeeling: programRating,
                    programFeelingReason: programFeelings
                )
                
                surveys.append(survey)
            }
        }
        
        sqlite3_finalize(statement)
        return surveys
    }
    
    // MARK: - Point Allocation Methods
    
    /// Public method to save point allocations with reason
    func savePointAllocation(taskId: String, taskType: String, pointsAwarded: Int, reason: String) {
        let sql = """
        INSERT INTO point_allocations (user_id, task_id, allocated_points, allocation_method, allocation_date, week_number, budget_remaining)
        VALUES (?, ?, ?, ?, ?, ?, ?);
        """
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let weekNumber = getCurrentWeekNumber()
            let budgetRemaining = getBudgetRemaining()
            
            sqlite3_bind_text(statement, 1, currentUserId, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 2, taskId, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(statement, 3, Int32(pointsAwarded))
            sqlite3_bind_text(statement, 4, reason, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 5, timestamp, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(statement, 6, Int32(weekNumber))
            sqlite3_bind_double(statement, 7, budgetRemaining)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("✅ Point allocation saved: \(pointsAwarded) points for \(taskType)")
            }
        }
        
        sqlite3_finalize(statement)
    }
    
    private func getCurrentWeekNumber() -> Int {
        // Calculate week number from app start or program start date
        // For now, return a simple week calculation
        let calendar = Calendar.current
        let weekOfYear = calendar.component(.weekOfYear, from: Date())
        return weekOfYear
    }
    
    private func getBudgetRemaining() -> Double {
        // Get remaining budget from admin settings
        let settings = getAdminSettings()
        return settings.maxBudgetPerWeek // Simplified for now
    }
    
    func getAdminSettings() -> AdminSettings {
        let settings = getAllAdminSettings()
        
        return AdminSettings(
            totalBudget: Double(settings["total_budget"] ?? "10000") ?? 10000,
            programLengthWeeks: Int(settings["program_length_weeks"] ?? "12") ?? 12,
            expectedUsersPerWeek: Int(settings["expected_users_per_week"] ?? "50") ?? 50,
            maxBudgetPerWeek: Double(settings["max_budget_per_week"] ?? "833") ?? 833,
            autoAllocatePoints: (settings["auto_allocate_points"] ?? "true").lowercased() == "true",
            pointsPerCheckIn: Int(settings["check_in_points"] ?? "10") ?? 10,
            pointsPerTaskCompletion: Int(settings["task_completion_points"] ?? "50") ?? 50,
            pointsPerQuizPass: Int(settings["quiz_pass_points"] ?? "100") ?? 100,
            useClaudeAPIFallback: (settings["use_claude_api_fallback"] ?? "false").lowercased() == "true",
            claudeAPIKey: settings["claude_api_key"]
        )
    }
    
    private func getTasksCompletedCount(userId: String) -> Int {
        let sql = "SELECT COUNT(*) FROM tasks WHERE user_id = ? AND completed_at IS NOT NULL;"
        var statement: OpaquePointer?
        var count = 0
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, userId, -1, SQLITE_TRANSIENT)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                count = Int(sqlite3_column_int(statement, 0))
            }
        }
        
        sqlite3_finalize(statement)
        return count
    }
}

// MARK: - Supporting Models

struct TrackContentItem {
    let id: Int
    let title: String
    let description: String
    let difficultyLevel: String
    let estimatedTimeMinutes: Int
    let pointsValue: Int
    let sequenceOrder: Int
}

// TrackType is defined in rpd_9_LLMApp.swift