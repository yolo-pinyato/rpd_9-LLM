import SwiftUI
import SwiftUI
import Combine
import SQLite3
import AVFoundation

/*
 WORKFORCE DEVELOPMENT APP - COMPLETE INTEGRATED VERSION
 =======================================================
 
 Features Included:
 ✅ Track-based learning (HVAC, Nursing, Spiritual, Mental Health)
 ✅ QR code check-ins with camera (integrated into Home tab)
 ✅ Admin dashboard with point allocation
 ✅ Automated budget-based point assignment
 ✅ Dynamic task generation from Ollama
 ✅ User event tracking and analytics
 ✅ Local RAG integration
 ✅ Rewards redemption system
 ✅ Resources directory (track-specific and general)
 
 TAB STRUCTURE:
 1. Home - Welcome, quick check-in, track info, stats, recent activity
 2. Tasks - Learning tasks and quizzes for selected track
 3. Rewards - Points-based reward redemption system
 4. Resources - Track-specific and community resources
 5. Profile - User information and statistics
 6. Admin - Budget and point allocation management (admin only)
 
 SETUP INSTRUCTIONS:
 1. Add to Info.plist:
    <key>NSCameraUsageDescription</key>
    <string>We need camera access to scan QR codes for check-ins</string>
 
 2. Ensure OllamaService.swift is in your project
 
 3. Update @main App struct to use: CompleteAppView()
*/

// MARK: - Track Types
enum TrackType: String, CaseIterable, Codable {
    case hvac = "HVAC Track"
    case nursing = "Registered Nurse"
    case spiritual = "Spiritual Health"
    case mentalHealth = "Mental Health"
    
    var icon: String {
        switch self {
        case .hvac: return "wrench.and.screwdriver.fill"
        case .nursing: return "cross.case.fill"
        case .spiritual: return "book.fill"
        case .mentalHealth: return "brain.head.profile"
        }
    }
    
    var color: Color {
        switch self {
        case .hvac: return AppTheme.hvacColor
        case .nursing: return AppTheme.nursingColor
        case .spiritual: return AppTheme.spiritualColor
        case .mentalHealth: return AppTheme.mentalHealthColor
        }
    }
    
    var themeColor: Color {
        return self.color
    }
    
    var description: String {
        switch self {
        case .hvac:
            return "Learn residential and commercial heating, ventilation, and air conditioning systems"
        case .nursing:
            return "Develop skills in patient care, clinical procedures, and healthcare delivery"
        case .spiritual:
            return "Grow spiritually through Bible study, reflection, and faith practices"
        case .mentalHealth:
            return "Practice mindfulness, meditation, and emotional wellness techniques"
        }
    }
    
    /// Convert TrackType to RAG database track string format
    var ragTrackString: String {
        switch self {
        case .hvac: return "hvac"
        case .nursing: return "nursing"
        case .spiritual: return "spiritual"
        case .mentalHealth: return "mental_health"
        }
    }
}

// MARK: - Models
struct User: Codable {
    var id: String
    var name: String
    var email: String
    var goals: [String]
    var pointsBalance: Int
    var currentStreak: Int
    var totalTasksCompleted: Int
    var selectedTrack: TrackType?
    var isAdmin: Bool

    // User level system: 1 level per 500 points, max level 20
    var level: Int {
        let calculatedLevel = min((pointsBalance / 500) + 1, 20)
        return calculatedLevel
    }

    // Points needed for next level
    var pointsToNextLevel: Int {
        if level >= 20 { return 0 }
        let nextLevelPoints = level * 500
        return nextLevelPoints - pointsBalance
    }

    // Progress to next level (0.0 to 1.0)
    var levelProgress: Double {
        if level >= 20 { return 1.0 }
        let currentLevelBase = (level - 1) * 500
        let pointsInCurrentLevel = pointsBalance - currentLevelBase
        return Double(pointsInCurrentLevel) / 500.0
    }
}

struct LearningTask: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let category: String
    let estimatedMinutes: Int
    var pointValue: Int
    let difficultyLevel: String?
    let trackType: TrackType?
    var isCompleted: Bool
    var completedDate: Date?
    
    init(id: String = UUID().uuidString,
         title: String,
         description: String,
         category: String,
         estimatedMinutes: Int,
         pointValue: Int,
         difficultyLevel: String? = nil,
         trackType: TrackType? = nil,
         isCompleted: Bool = false,
         completedDate: Date? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.estimatedMinutes = estimatedMinutes
        self.pointValue = pointValue
        self.difficultyLevel = difficultyLevel
        self.trackType = trackType
        self.isCompleted = isCompleted
        self.completedDate = completedDate
    }
}

struct CheckInEvent: Identifiable, Codable {
    let id: String
    let userId: String
    let timestamp: Date
    let qrCodeData: String
    let location: String?
    let pointsAwarded: Int
}

struct AdminSettings: Codable {
    var totalBudget: Double
    var programLengthWeeks: Int
    var expectedUsersPerWeek: Int
    var maxBudgetPerWeek: Double
    var autoAllocatePoints: Bool
    var pointsPerCheckIn: Int
    var pointsPerTaskCompletion: Int
    var pointsPerQuizPass: Int
    var useClaudeAPIFallback: Bool
    var claudeAPIKey: String?

    // Default initializer for backwards compatibility
    init(totalBudget: Double = 10000,
         programLengthWeeks: Int = 12,
         expectedUsersPerWeek: Int = 50,
         maxBudgetPerWeek: Double = 833,
         autoAllocatePoints: Bool = true,
         pointsPerCheckIn: Int = 10,
         pointsPerTaskCompletion: Int = 50,
         pointsPerQuizPass: Int = 100,
         useClaudeAPIFallback: Bool = false,
         claudeAPIKey: String? = nil) {
        self.totalBudget = totalBudget
        self.programLengthWeeks = programLengthWeeks
        self.expectedUsersPerWeek = expectedUsersPerWeek
        self.maxBudgetPerWeek = maxBudgetPerWeek
        self.autoAllocatePoints = autoAllocatePoints
        self.pointsPerCheckIn = pointsPerCheckIn
        self.pointsPerTaskCompletion = pointsPerTaskCompletion
        self.pointsPerQuizPass = pointsPerQuizPass
        self.useClaudeAPIFallback = useClaudeAPIFallback
        self.claudeAPIKey = claudeAPIKey
    }
}

// MARK: - Enhanced Database Manager
class EnhancedDatabaseManager {
    static let shared = EnhancedDatabaseManager()
    private var db: OpaquePointer?
    private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    
    private init() {
        setupDatabase()
    }
    
    private func setupDatabase() {
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("workforce_dev.sqlite")

        print("📁 Database location: \(fileURL.path)")

        guard sqlite3_open(fileURL.path, &db) == SQLITE_OK else {
            print("Error opening database")
            return
        }
        
        createTables()
    }
    
    private func createTables() {
        // Users table
        let createUsersTable = """
        CREATE TABLE IF NOT EXISTS users (
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
        """
        
        // Tasks table
        let createTasksTable = """
        CREATE TABLE IF NOT EXISTS tasks (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            description TEXT,
            category TEXT,
            estimated_minutes INTEGER,
            point_value INTEGER,
            difficulty_level TEXT,
            track_type TEXT,
            is_completed INTEGER DEFAULT 0,
            completed_date TIMESTAMP,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
        """
        
        // Check-ins table
        let createCheckInsTable = """
        CREATE TABLE IF NOT EXISTS check_ins (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            qr_code_data TEXT NOT NULL,
            location TEXT,
            points_awarded INTEGER,
            FOREIGN KEY (user_id) REFERENCES users(id)
        );
        """
        
        // Admin settings table
        let createAdminSettingsTable = """
        CREATE TABLE IF NOT EXISTS admin_settings (
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
        """
        
        // User events table (for analytics)
        let createEventsTable = """
        CREATE TABLE IF NOT EXISTS user_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            event_type TEXT NOT NULL,
            event_data TEXT,
            timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id)
        );
        """
        
        executeSQL(createUsersTable)
        executeSQL(createTasksTable)
        executeSQL(createCheckInsTable)
        executeSQL(createAdminSettingsTable)
        executeSQL(createEventsTable)
        
        // Insert default admin settings if not exists
        let insertDefaultSettings = """
        INSERT OR IGNORE INTO admin_settings (id, total_budget, program_length_weeks, expected_users_per_week, max_budget_per_week)
        VALUES (1, 10000.0, 12, 20, 833.33);
        """
        executeSQL(insertDefaultSettings)
    }
    
    private func executeSQL(_ sql: String) {
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) != SQLITE_DONE {
                print("Error executing SQL: \(String(cString: sqlite3_errmsg(db)))")
            }
        }
        sqlite3_finalize(statement)
    }
    
    // MARK: - User Operations
    
    func createUser(_ user: User) {
        let sql = """
        INSERT OR REPLACE INTO users (id, name, email, goals, points_balance, current_streak, total_tasks_completed, selected_track, is_admin)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }
        
        let goalsJSON = (try? JSONEncoder().encode(user.goals)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        
        sqlite3_bind_text(statement, 1, user.id, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, user.name, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 3, user.email, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 4, goalsJSON, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(statement, 5, Int32(user.pointsBalance))
        sqlite3_bind_int(statement, 6, Int32(user.currentStreak))
        sqlite3_bind_int(statement, 7, Int32(user.totalTasksCompleted))
        sqlite3_bind_text(statement, 8, user.selectedTrack?.rawValue ?? "", -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(statement, 9, user.isAdmin ? 1 : 0)
        
        sqlite3_step(statement)
        sqlite3_finalize(statement)
    }
    
    func getUser(id: String) -> User? {
        let sql = "SELECT * FROM users WHERE id = ?;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
        
        sqlite3_bind_text(statement, 1, id, -1, SQLITE_TRANSIENT)
        
        var user: User?
        if sqlite3_step(statement) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(statement, 0))
            let name = String(cString: sqlite3_column_text(statement, 1))
            let email = String(cString: sqlite3_column_text(statement, 2))
            let goalsJSON = String(cString: sqlite3_column_text(statement, 3))
            let goals = (try? JSONDecoder().decode([String].self, from: goalsJSON.data(using: .utf8)!)) ?? []
            let pointsBalance = Int(sqlite3_column_int(statement, 4))
            let currentStreak = Int(sqlite3_column_int(statement, 5))
            let totalTasksCompleted = Int(sqlite3_column_int(statement, 6))
            let selectedTrackRaw = String(cString: sqlite3_column_text(statement, 7))
            let selectedTrack = TrackType(rawValue: selectedTrackRaw)
            let isAdmin = sqlite3_column_int(statement, 8) == 1
            
            user = User(id: id, name: name, email: email, goals: goals,
                       pointsBalance: pointsBalance, currentStreak: currentStreak,
                       totalTasksCompleted: totalTasksCompleted, selectedTrack: selectedTrack,
                       isAdmin: isAdmin)
        }
        
        sqlite3_finalize(statement)
        return user
    }
    
    func updateUser(_ user: User) {
        createUser(user) // Using INSERT OR REPLACE
    }
    
    // MARK: - Task Operations
    
    func createTask(_ task: LearningTask) {
        let sql = """
        INSERT OR REPLACE INTO tasks (id, title, description, category, estimated_minutes, point_value, difficulty_level, track_type, is_completed, completed_date)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }
        
        sqlite3_bind_text(statement, 1, task.id, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, task.title, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 3, task.description, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 4, task.category, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(statement, 5, Int32(task.estimatedMinutes))
        sqlite3_bind_int(statement, 6, Int32(task.pointValue))
        sqlite3_bind_text(statement, 7, task.difficultyLevel ?? "", -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 8, task.trackType?.rawValue ?? "", -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(statement, 9, task.isCompleted ? 1 : 0)
        
        if let completedDate = task.completedDate {
            sqlite3_bind_double(statement, 10, completedDate.timeIntervalSince1970)
        } else {
            sqlite3_bind_null(statement, 10)
        }
        
        sqlite3_step(statement)
        sqlite3_finalize(statement)
    }
    
    func getTasks(forTrack track: TrackType? = nil) -> [LearningTask] {
        var sql = "SELECT * FROM tasks"
        if let track = track {
            sql += " WHERE track_type = '\(track.rawValue)'"
        }
        sql += ";"
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return [] }
        
        var tasks: [LearningTask] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(statement, 0))
            let title = String(cString: sqlite3_column_text(statement, 1))
            let description = String(cString: sqlite3_column_text(statement, 2))
            let category = String(cString: sqlite3_column_text(statement, 3))
            let estimatedMinutes = Int(sqlite3_column_int(statement, 4))
            let pointValue = Int(sqlite3_column_int(statement, 5))
            let difficultyLevel = String(cString: sqlite3_column_text(statement, 6))
            let trackTypeRaw = String(cString: sqlite3_column_text(statement, 7))
            let trackType = TrackType(rawValue: trackTypeRaw)
            let isCompleted = sqlite3_column_int(statement, 8) == 1
            
            var completedDate: Date?
            if sqlite3_column_type(statement, 9) != SQLITE_NULL {
                completedDate = Date(timeIntervalSince1970: sqlite3_column_double(statement, 9))
            }
            
            let task = LearningTask(id: id, title: title, description: description, category: category,
                          estimatedMinutes: estimatedMinutes, pointValue: pointValue,
                          difficultyLevel: difficultyLevel, trackType: trackType,
                          isCompleted: isCompleted, completedDate: completedDate)
            tasks.append(task)
        }
        
        sqlite3_finalize(statement)
        return tasks
    }
    
    // MARK: - Check-In Operations
    
    func recordCheckIn(_ checkIn: CheckInEvent) {
        let sql = """
        INSERT INTO check_ins (id, user_id, timestamp, qr_code_data, location, points_awarded)
        VALUES (?, ?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }
        
        sqlite3_bind_text(statement, 1, checkIn.id, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, checkIn.userId, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(statement, 3, checkIn.timestamp.timeIntervalSince1970)
        sqlite3_bind_text(statement, 4, checkIn.qrCodeData, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 5, checkIn.location ?? "", -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(statement, 6, Int32(checkIn.pointsAwarded))
        
        sqlite3_step(statement)
        sqlite3_finalize(statement)
    }
    
    func getCheckIns(forUser userId: String) -> [CheckInEvent] {
        let sql = "SELECT * FROM check_ins WHERE user_id = ? ORDER BY timestamp DESC;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return [] }
        
        sqlite3_bind_text(statement, 1, userId, -1, SQLITE_TRANSIENT)
        
        var checkIns: [CheckInEvent] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(statement, 0))
            let userId = String(cString: sqlite3_column_text(statement, 1))
            let timestamp = Date(timeIntervalSince1970: sqlite3_column_double(statement, 2))
            let qrCodeData = String(cString: sqlite3_column_text(statement, 3))
            let location = String(cString: sqlite3_column_text(statement, 4))
            let pointsAwarded = Int(sqlite3_column_int(statement, 5))
            
            let checkIn = CheckInEvent(id: id, userId: userId, timestamp: timestamp,
                                      qrCodeData: qrCodeData, location: location,
                                      pointsAwarded: pointsAwarded)
            checkIns.append(checkIn)
        }
        
        sqlite3_finalize(statement)
        return checkIns
    }
    
    // MARK: - Admin Settings Operations
    
    func getAdminSettings() -> AdminSettings {
        let sql = "SELECT * FROM admin_settings WHERE id = 1;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return AdminSettings(totalBudget: 10000, programLengthWeeks: 12,
                               expectedUsersPerWeek: 20, maxBudgetPerWeek: 833.33,
                               autoAllocatePoints: true, pointsPerCheckIn: 10,
                               pointsPerTaskCompletion: 50, pointsPerQuizPass: 75)
        }
        
        var settings = AdminSettings(totalBudget: 10000, programLengthWeeks: 12,
                                    expectedUsersPerWeek: 20, maxBudgetPerWeek: 833.33,
                                    autoAllocatePoints: true, pointsPerCheckIn: 10,
                                    pointsPerTaskCompletion: 50, pointsPerQuizPass: 75)
        
        if sqlite3_step(statement) == SQLITE_ROW {
            settings.totalBudget = sqlite3_column_double(statement, 1)
            settings.programLengthWeeks = Int(sqlite3_column_int(statement, 2))
            settings.expectedUsersPerWeek = Int(sqlite3_column_int(statement, 3))
            settings.maxBudgetPerWeek = sqlite3_column_double(statement, 4)
            settings.autoAllocatePoints = sqlite3_column_int(statement, 5) == 1
            settings.pointsPerCheckIn = Int(sqlite3_column_int(statement, 6))
            settings.pointsPerTaskCompletion = Int(sqlite3_column_int(statement, 7))
            settings.pointsPerQuizPass = Int(sqlite3_column_int(statement, 8))
        }
        
        sqlite3_finalize(statement)
        return settings
    }
    
    func updateAdminSettings(_ settings: AdminSettings) {
        let sql = """
        UPDATE admin_settings SET
        total_budget = ?,
        program_length_weeks = ?,
        expected_users_per_week = ?,
        max_budget_per_week = ?,
        auto_allocate_points = ?,
        points_per_check_in = ?,
        points_per_task_completion = ?,
        points_per_quiz_pass = ?
        WHERE id = 1;
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }
        
        sqlite3_bind_double(statement, 1, settings.totalBudget)
        sqlite3_bind_int(statement, 2, Int32(settings.programLengthWeeks))
        sqlite3_bind_int(statement, 3, Int32(settings.expectedUsersPerWeek))
        sqlite3_bind_double(statement, 4, settings.maxBudgetPerWeek)
        sqlite3_bind_int(statement, 5, settings.autoAllocatePoints ? 1 : 0)
        sqlite3_bind_int(statement, 6, Int32(settings.pointsPerCheckIn))
        sqlite3_bind_int(statement, 7, Int32(settings.pointsPerTaskCompletion))
        sqlite3_bind_int(statement, 8, Int32(settings.pointsPerQuizPass))
        
        sqlite3_step(statement)
        sqlite3_finalize(statement)
    }
    
    // MARK: - Event Logging
    
    func logEvent(userId: String, eventType: String, eventData: String? = nil) {
        let sql = """
        INSERT INTO user_events (user_id, event_type, event_data)
        VALUES (?, ?, ?);
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }

        sqlite3_bind_text(statement, 1, userId, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, eventType, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 3, eventData ?? "", -1, SQLITE_TRANSIENT)

        sqlite3_step(statement)
        sqlite3_finalize(statement)
    }

    // MARK: - User Management

    func saveUser(_ user: User) {
        let goalsString = user.goals.joined(separator: ",")
        let trackString = user.selectedTrack?.rawValue ?? ""

        let sql = """
        INSERT OR REPLACE INTO users
        (id, name, email, goals, points_balance, current_streak, total_tasks_completed, selected_track, is_admin)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }

        sqlite3_bind_text(statement, 1, user.id, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, user.name, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 3, user.email, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 4, goalsString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(statement, 5, Int32(user.pointsBalance))
        sqlite3_bind_int(statement, 6, Int32(user.currentStreak))
        sqlite3_bind_int(statement, 7, Int32(user.totalTasksCompleted))
        sqlite3_bind_text(statement, 8, trackString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(statement, 9, user.isAdmin ? 1 : 0)

        sqlite3_step(statement)
        sqlite3_finalize(statement)

        print("✅ User saved: \(user.name) (\(user.id))")
    }

    func saveCheckIn(_ checkIn: CheckInEvent) {
        let sql = """
        INSERT INTO check_ins (id, user_id, timestamp, qr_code_data, location, points_awarded)
        VALUES (?, ?, ?, ?, ?, ?);
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }

        let dateFormatter = ISO8601DateFormatter()
        let timestampString = dateFormatter.string(from: checkIn.timestamp)

        sqlite3_bind_text(statement, 1, checkIn.id, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, checkIn.userId, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 3, timestampString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 4, checkIn.qrCodeData, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 5, checkIn.location ?? "", -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(statement, 6, Int32(checkIn.pointsAwarded))

        sqlite3_step(statement)
        sqlite3_finalize(statement)

        print("✅ Check-in saved for user: \(checkIn.userId)")
    }

    // MARK: - Database Export

    /// Export database to Desktop for external access
    func exportDatabaseToDesktop() -> String? {
        guard let sourceURL = getDatabaseURL() else {
            print("❌ Could not find database URL")
            return nil
        }

        let fileManager = FileManager.default
        guard let desktopURL = fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first else {
            print("❌ Could not find Desktop directory")
            return nil
        }

        // Create timestamped filename
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let destinationURL = desktopURL.appendingPathComponent("workforce_dev_\(timestamp).sqlite")

        do {
            // Copy database file
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            print("✅ Database exported to: \(destinationURL.path)")
            return destinationURL.path
        } catch {
            print("❌ Error exporting database: \(error.localizedDescription)")
            return nil
        }
    }

    /// Get the database file URL
    func getDatabaseURL() -> URL? {
        let fileURL = try? FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("workforce_dev.sqlite")
        return fileURL
    }

    /// Get database path for logging
    func getDatabasePath() -> String {
        return getDatabaseURL()?.path ?? "Unknown"
    }
}

// MARK: - Point Allocation Algorithm
class PointAllocationEngine {
    static let shared = PointAllocationEngine()
    private let db = EnhancedDatabaseManager.shared
    
    func calculatePointsForTask(settings: AdminSettings, task: LearningTask) -> Int {
        if !settings.autoAllocatePoints {
            return task.pointValue
        }
        
        // Calculate weekly point budget per user
        let weeklyBudgetPerUser = settings.maxBudgetPerWeek / Double(settings.expectedUsersPerWeek)
        
        // Convert to points (assuming $1 = 100 points)
        let weeklyPointsPerUser = Int(weeklyBudgetPerUser * 100)
        
        // Base points on difficulty and time
        var basePoints = task.estimatedMinutes * 2
        
        // Difficulty multiplier
        let difficultyMultiplier: Double = {
            switch task.difficultyLevel?.lowercased() {
            case "beginner": return 0.8
            case "intermediate": return 1.0
            case "advanced": return 1.3
            default: return 1.0
            }
        }()
        
        basePoints = Int(Double(basePoints) * difficultyMultiplier)
        
        // Ensure points don't exceed weekly budget per user
        let maxPointsPerTask = weeklyPointsPerUser / 5 // Assume 5 tasks per week
        return min(basePoints, maxPointsPerTask)
    }
    
    func calculatePointsForCheckIn(settings: AdminSettings) -> Int {
        if !settings.autoAllocatePoints {
            return settings.pointsPerCheckIn
        }
        
        return settings.pointsPerCheckIn
    }
    
    func calculatePointsForQuiz(settings: AdminSettings, score: Double) -> Int {
        if !settings.autoAllocatePoints {
            return settings.pointsPerQuizPass
        }
        
        // Scale points based on quiz performance
        let basePoints = settings.pointsPerQuizPass
        return Int(Double(basePoints) * score)
    }
}

// MARK: - QR Code Scanner
struct QRCodeScannerView: UIViewControllerRepresentable {
    @Binding var scannedCode: String?
    @Binding var isPresented: Bool
    
    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var parent: QRCodeScannerView
        
        init(parent: QRCodeScannerView) {
            self.parent = parent
        }
        
        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            if let metadataObject = metadataObjects.first {
                guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
                guard let stringValue = readableObject.stringValue else { return }
                
                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
                parent.scannedCode = stringValue
                parent.isPresented = false
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        let captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return viewController }
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return viewController
        }
        
        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else {
            return viewController
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if (captureSession.canAddOutput(metadataOutput)) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(context.coordinator, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            return viewController
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = viewController.view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        viewController.view.layer.addSublayer(previewLayer)
        
        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.startRunning()
        }
        
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

// MARK: - Main View Model
@MainActor
class CompleteAppViewModel: ObservableObject {
    @Published var user: User
    @Published var tasks: [LearningTask] = []
    @Published var checkIns: [CheckInEvent] = []
    @Published var adminSettings: AdminSettings
    @Published var showOnboarding = false
    @Published var selectedTab = 0
    
    let db = EnhancedDatabaseManager.shared
    private let pointsEngine = PointAllocationEngine.shared
    
    init() {
        // Check if user exists, otherwise show onboarding
        if let existingUser = db.getUser(id: "user_001") {
            self.user = existingUser
        } else {
            self.user = User(id: "user_001", name: "", email: "", goals: [],
                           pointsBalance: 0, currentStreak: 0, totalTasksCompleted: 0,
                           selectedTrack: nil, isAdmin: false)
            self.showOnboarding = true
        }
        
        self.adminSettings = db.getAdminSettings()
        loadData()
    }
    
    func loadData() {
        if let track = user.selectedTrack {
            tasks = db.getTasks(forTrack: track)
        } else {
            tasks = db.getTasks()
        }
        checkIns = db.getCheckIns(forUser: user.id)
    }

    // Calculate points earned in the last 7 days
    func pointsLastSevenDays() -> Int {
        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()

        var totalPoints = 0

        // Points from completed tasks in last 7 days
        let recentTasks = tasks.filter { task in
            if let completedDate = task.completedDate {
                return completedDate >= sevenDaysAgo && task.isCompleted
            }
            return false
        }
        totalPoints += recentTasks.reduce(0) { $0 + $1.pointValue }

        // Points from check-ins in last 7 days
        let recentCheckIns = checkIns.filter { $0.timestamp >= sevenDaysAgo }
        totalPoints += recentCheckIns.reduce(0) { $0 + $1.pointsAwarded }

        return totalPoints
    }
    
    func selectTrack(_ track: TrackType) {
        user.selectedTrack = track
        db.updateUser(user)
        db.logEvent(userId: user.id, eventType: "track_selected", eventData: track.rawValue)
        generateTasksForTrack(track)
        loadData()
    }
    
    func generateTasksForTrack(_ track: TrackType) {
        let trackTasks: [LearningTask]
        
        switch track {
        case .hvac:
            trackTasks = [
                LearningTask(title: "HVAC Basics", description: "Learn fundamentals of heating and cooling systems",
                     category: "Learning", estimatedMinutes: 30, pointValue: 50,
                     difficultyLevel: "beginner", trackType: .hvac),
                LearningTask(title: "Residential Systems", description: "Study residential HVAC installations",
                     category: "Learning", estimatedMinutes: 45, pointValue: 75,
                     difficultyLevel: "intermediate", trackType: .hvac),
                LearningTask(title: "Troubleshooting Quiz", description: "Test your diagnostic skills",
                     category: "Quiz", estimatedMinutes: 20, pointValue: 100,
                     difficultyLevel: "intermediate", trackType: .hvac)
            ]
            
        case .nursing:
            trackTasks = [
                LearningTask(title: "Patient Care Fundamentals", description: "Learn basic patient care procedures",
                     category: "Learning", estimatedMinutes: 40, pointValue: 60,
                     difficultyLevel: "beginner", trackType: .nursing),
                LearningTask(title: "Clinical Procedures", description: "Study common clinical procedures",
                     category: "Learning", estimatedMinutes: 50, pointValue: 85,
                     difficultyLevel: "intermediate", trackType: .nursing),
                LearningTask(title: "Medical Terminology Quiz", description: "Test your medical vocabulary",
                     category: "Quiz", estimatedMinutes: 15, pointValue: 90,
                     difficultyLevel: "beginner", trackType: .nursing)
            ]
            
        case .spiritual:
            trackTasks = [
                LearningTask(title: "Biblical Foundations", description: "Study core biblical principles",
                     category: "Learning", estimatedMinutes: 35, pointValue: 55,
                     difficultyLevel: "beginner", trackType: .spiritual),
                LearningTask(title: "Spiritual Disciplines", description: "Learn about prayer and meditation",
                     category: "Learning", estimatedMinutes: 30, pointValue: 50,
                     difficultyLevel: "intermediate", trackType: .spiritual),
                LearningTask(title: "Scripture Knowledge Quiz", description: "Test your biblical knowledge",
                     category: "Quiz", estimatedMinutes: 20, pointValue: 85,
                     difficultyLevel: "intermediate", trackType: .spiritual)
            ]
            
        case .mentalHealth:
            trackTasks = [
                LearningTask(title: "Mindfulness Basics", description: "Learn fundamental mindfulness techniques",
                     category: "Learning", estimatedMinutes: 25, pointValue: 45,
                     difficultyLevel: "beginner", trackType: .mentalHealth),
                LearningTask(title: "Meditation Practice", description: "Guided meditation exercises",
                     category: "Practice", estimatedMinutes: 30, pointValue: 60,
                     difficultyLevel: "beginner", trackType: .mentalHealth),
                LearningTask(title: "Emotional Wellness Quiz", description: "Assess your understanding of emotional health",
                     category: "Quiz", estimatedMinutes: 15, pointValue: 80,
                     difficultyLevel: "intermediate", trackType: .mentalHealth)
            ]
        }
        
        // Calculate points based on admin settings
        for var task in trackTasks {
            task.pointValue = pointsEngine.calculatePointsForTask(settings: adminSettings, task: task)
            db.createTask(task)
        }
    }
    
    func completeTask(_ task: LearningTask) {
        var updatedTask = task
        updatedTask.isCompleted = true
        updatedTask.completedDate = Date()
        
        let points = pointsEngine.calculatePointsForTask(settings: adminSettings, task: task)
        user.pointsBalance += points
        user.totalTasksCompleted += 1
        
        db.createTask(updatedTask)
        db.updateUser(user)
        db.logEvent(userId: user.id, eventType: "task_completed", eventData: task.title)
        
        loadData()
    }
    
    func processCheckIn(qrCode: String) -> (success: Bool, message: String) {
        // Check if user already checked in today (GMT)
        let calendar = Calendar(identifier: .gregorian)
        var gmtCalendar = calendar
        gmtCalendar.timeZone = TimeZone(identifier: "GMT")!
        
        let now = Date()
        let todayComponents = gmtCalendar.dateComponents([.year, .month, .day], from: now)
        
        // Check existing check-ins for today
        for checkIn in checkIns {
            let checkInComponents = gmtCalendar.dateComponents([.year, .month, .day], from: checkIn.timestamp)
            if checkInComponents == todayComponents {
                return (false, "You've already checked in today. Come back tomorrow!")
            }
        }
        
        // Create new check-in
        let checkIn = CheckInEvent(
            id: UUID().uuidString,
            userId: user.id,
            timestamp: now,
            qrCodeData: qrCode,
            location: "Main Facility",
            pointsAwarded: pointsEngine.calculatePointsForCheckIn(settings: adminSettings)
        )
        
        user.pointsBalance += checkIn.pointsAwarded
        db.recordCheckIn(checkIn)
        db.updateUser(user)
        db.logEvent(userId: user.id, eventType: "check_in", eventData: qrCode)
        
        loadData()
        return (true, "Check-in successful!")
    }
    
    func getLastCheckInDate() -> Date? {
        return checkIns.first?.timestamp
    }
    
    func canCheckInToday() -> Bool {
        guard let lastCheckIn = getLastCheckInDate() else {
            return true // No previous check-ins
        }
        
        let calendar = Calendar(identifier: .gregorian)
        var gmtCalendar = calendar
        gmtCalendar.timeZone = TimeZone(identifier: "GMT")!
        
        let now = Date()
        let todayComponents = gmtCalendar.dateComponents([.year, .month, .day], from: now)
        let lastCheckInComponents = gmtCalendar.dateComponents([.year, .month, .day], from: lastCheckIn)
        
        return todayComponents != lastCheckInComponents
    }
    
    func updateAdminSettings(_ settings: AdminSettings) {
        self.adminSettings = settings
        db.updateAdminSettings(settings)
    }
}

// MARK: - Main App View
struct CompleteAppView: View {
    @StateObject private var viewModel = CompleteAppViewModel()

    var body: some View {
        if viewModel.showOnboarding {
            OnboardingView(viewModel: viewModel)
        } else {
            MainTabView(viewModel: viewModel)
        }
    }
}

// MARK: - Ollama Test View
struct OllamaTestView: View {
    @StateObject private var ollamaService = OllamaService.shared
    @State private var answer: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var connectionStatus: String = "Not checked"
    @State private var isCheckingConnection: Bool = false

    let testQuestion = "What is the difference between the heimlich and CPR?"

    var body: some View {
        ZStack {
            AppTheme.mainGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    Text("Ollama Direct Test")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.top, 40)

                    // Connection Status
                    VStack(spacing: 10) {
                        HStack {
                            Text("Connection Status:")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                            Text(connectionStatus)
                                .font(.body)
                                .foregroundColor(connectionStatus == "Connected ✓" ? .green : .orange)
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)

                        Button(action: {
                            Task {
                                await checkConnection()
                            }
                        }) {
                            HStack {
                                if isCheckingConnection {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .padding(.trailing, 5)
                                }
                                Text(isCheckingConnection ? "Checking..." : "Check Connection")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isCheckingConnection)
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Question:")
                            .font(.headline)
                            .foregroundColor(.white)

                        Text(testQuestion)
                            .font(.body)
                            .foregroundColor(.white.opacity(0.9))
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)

                    Button(action: {
                        Task {
                            await askQuestion()
                        }
                    }) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .padding(.trailing, 5)
                            }
                            Text(isLoading ? "Asking Ollama..." : "Ask Ollama")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isLoading)
                    .padding(.horizontal)

                    if let error = errorMessage {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Error:")
                                .font(.headline)
                                .foregroundColor(.red)

                            Text(error)
                                .font(.body)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.red.opacity(0.2))
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    }

                    if !answer.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Answer:")
                                .font(.headline)
                                .foregroundColor(.white)

                            Text(answer)
                                .font(.body)
                                .foregroundColor(.white.opacity(0.9))
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    }

                    Spacer()
                }
            }
        }
    }

    func checkConnection() async {
        isCheckingConnection = true
        connectionStatus = "Checking..."
        
        let isConnected = await OllamaService.shared.checkOllamaConnection()
        
        await MainActor.run {
            isCheckingConnection = false
            connectionStatus = isConnected ? "Connected ✓" : "Not Connected"
        }
    }
    
    func askQuestion() async {
        isLoading = true
        errorMessage = nil
        answer = ""

        do {
            let response = try await ollamaService.askQuestion(question: testQuestion)
            await MainActor.run {
                answer = response
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Error: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}

// MARK: - Onboarding View
struct OnboardingView: View {
    @ObservedObject var viewModel: CompleteAppViewModel
    @State private var name = ""
    @State private var email = ""
    @State private var selectedGoals: Set<String> = []
    
    let availableGoals = [
        "Career Development",
        "Personal Growth",
        "Financial Stability",
        "Health & Wellness"
    ]
    
    var body: some View {
        ZStack {
            AppTheme.mainGradient
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("Welcome to Workforce Development")
                    .font(AppTheme.Typography.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 20) {
                    TextField("Name", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                    
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding(.horizontal)
                    
                    Text("Select Your Goals")
                        .font(AppTheme.Typography.headline)
                        .foregroundColor(AppTheme.textPrimary)
                    
                    ForEach(availableGoals, id: \.self) { goal in
                        Button(action: {
                            if selectedGoals.contains(goal) {
                                selectedGoals.remove(goal)
                            } else {
                                selectedGoals.insert(goal)
                            }
                        }) {
                            HStack {
                                Image(systemName: selectedGoals.contains(goal) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedGoals.contains(goal) ? AppTheme.darkest : AppTheme.textTertiary)
                                Text(goal)
                                    .foregroundColor(AppTheme.textPrimary)
                                Spacer()
                            }
                            .padding()
                            .background(selectedGoals.contains(goal) ? AppTheme.dark.opacity(0.3) : AppTheme.cardBackground)
                            .cornerRadius(AppTheme.CornerRadius.md)
                        }
                        .padding(.horizontal)
                    }
                }
                
                Button(action: {
                    viewModel.user.name = name
                    viewModel.user.email = email
                    viewModel.user.goals = Array(selectedGoals)
                    EnhancedDatabaseManager.shared.createUser(viewModel.user)
                    viewModel.showOnboarding = false
                }) {
                    Text("Get Started")
                        .themedButtonPrimary()
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
                .disabled(name.isEmpty || email.isEmpty)
            }
            .padding()
        }
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @ObservedObject var viewModel: CompleteAppViewModel
    
    var body: some View {
        TabView(selection: $viewModel.selectedTab) {
            HomeView(viewModel: viewModel)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            TasksView(viewModel: viewModel)
                .tabItem {
                    Label("Tasks", systemImage: "list.bullet")
                }
                .tag(1)
            
            RewardsView(viewModel: viewModel)
                .tabItem {
                    Label("Rewards", systemImage: "gift.fill")
                }
                .tag(2)
            
            ResourcesView(viewModel: viewModel)
                .tabItem {
                    Label("Resources", systemImage: "books.vertical.fill")
                }
                .tag(3)
            
            ProfileView(viewModel: viewModel)
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(4)
            
            if viewModel.user.isAdmin {
                AdminDashboardView(viewModel: viewModel)
                    .tabItem {
                        Label("Admin", systemImage: "gear")
                    }
                    .tag(5)
            }
        }
    }
}

// MARK: - User Level & Points Chart Component
struct UserLevelChart: View {
    @ObservedObject var viewModel: CompleteAppViewModel
    let showDetailedStats: Bool

    var body: some View {
        VStack(spacing: 15) {
            // User Level Badge
            VStack(spacing: 8) {
                Text("Level \(viewModel.user.level)")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AppTheme.darkest)

                if viewModel.user.level < 20 {
                    Text("\(viewModel.user.pointsToNextLevel) pts to next level")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }

            // Circular Progress Chart
            ZStack {
                // Background circle
                Circle()
                    .stroke(AppTheme.medium.opacity(0.3), lineWidth: 20)
                    .frame(width: 180, height: 180)

                // Progress circle for level
                Circle()
                    .trim(from: 0, to: CGFloat(viewModel.user.levelProgress))
                    .stroke(
                        LinearGradient(
                            colors: [AppTheme.accent, AppTheme.dark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: viewModel.user.levelProgress)

                // Center content
                VStack(spacing: 8) {
                    Text("\(viewModel.user.pointsBalance)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(AppTheme.darkest)

                    Text("Total Points")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)

                    if showDetailedStats {
                        Divider()
                            .frame(width: 60)
                            .padding(.vertical, 4)

                        VStack(spacing: 2) {
                            Text("\(viewModel.pointsLastSevenDays())")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(AppTheme.success)

                            Text("Last 7 Days")
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                }
            }

            // Level progress bar (optional additional indicator)
            if viewModel.user.level < 20 {
                VStack(spacing: 5) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(AppTheme.medium.opacity(0.3))
                                .frame(height: 8)
                                .cornerRadius(4)

                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [AppTheme.accent, AppTheme.dark],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * CGFloat(viewModel.user.levelProgress), height: 8)
                                .cornerRadius(4)
                                .animation(.easeInOut(duration: 0.8), value: viewModel.user.levelProgress)
                        }
                    }
                    .frame(height: 8)

                    HStack {
                        Text("Level \(viewModel.user.level)")
                            .font(.caption2)
                            .foregroundColor(AppTheme.textSecondary)

                        Spacer()

                        Text("Level \(viewModel.user.level + 1)")
                            .font(.caption2)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
            } else {
                Text("🎉 MAX LEVEL REACHED!")
                    .font(.headline)
                    .foregroundColor(AppTheme.success)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(AppTheme.cardBackground)
                .shadow(color: AppTheme.darkest.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
}

// MARK: - Home View
struct HomeView: View {
    @ObservedObject var viewModel: CompleteAppViewModel
    
    var body: some View {
        ZStack {
            // Background image
            GeometryReader { geometry in
                Image("HomeBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .opacity(0.3)
            }
            .ignoresSafeArea()

            AppTheme.mainGradient
                .opacity(0.7)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Welcome Header
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Welcome back,")
                                .foregroundColor(AppTheme.textSecondary)
                                .font(AppTheme.Typography.subheadline)
                            Text(viewModel.user.name)
                                .font(AppTheme.Typography.title1)
                                .fontWeight(.bold)
                                .foregroundColor(AppTheme.textPrimary)
                        }
                        Spacer()
                        
                        VStack(spacing: 4) {
                            Text("\(viewModel.user.pointsBalance)")
                                .font(AppTheme.Typography.title2)
                                .fontWeight(.bold)
                                .foregroundColor(AppTheme.darkest)
                            Text("Points")
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .padding()
                        .background(AppTheme.dark.opacity(0.3))
                        .cornerRadius(AppTheme.CornerRadius.lg)
                    }
                    .padding()

                    // User Level and Points Chart
                    UserLevelChart(viewModel: viewModel, showDetailedStats: true)
                        .padding(.horizontal)

                    // Quick Check-In Card
                    QuickCheckInCard(viewModel: viewModel)

                    // Track Selection
                    if viewModel.user.selectedTrack == nil {
                        TrackSelectionCard(viewModel: viewModel)
                    } else {
                        CurrentTrackCard(viewModel: viewModel)
                    }
                    
                    // Quick Stats
                    QuickStatsView(viewModel: viewModel)
                    
                    // Recent Activity
                    RecentActivityView(viewModel: viewModel)
                }
                .padding()
            }
        }
    }
}

// MARK: - Quick Check-In Card
struct QuickCheckInCard: View {
    @ObservedObject var viewModel: CompleteAppViewModel
    @State private var showingScanner = false
    @State private var scannedCode: String?
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    var canCheckIn: Bool {
        viewModel.canCheckInToday()
    }
    
    var lastCheckInDate: Date? {
        viewModel.getLastCheckInDate()
    }
    
    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Image(systemName: "qrcode.viewfinder")
                    .font(.title)
                    .foregroundColor(canCheckIn ? AppTheme.darkest : AppTheme.textTertiary)
                
                VStack(alignment: .leading) {
                    Text("Daily Check-In")
                        .font(AppTheme.Typography.headline)
                        .foregroundColor(AppTheme.textPrimary)
                    Text(canCheckIn ? "Scan QR code to earn points" : "Already checked in today")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(canCheckIn ? AppTheme.textSecondary : AppTheme.warning)
                }
                
                Spacer()
                
                Button(action: {
                    if canCheckIn {
                        showingScanner = true
                    }
                }) {
                    Text(canCheckIn ? "Scan" : "Done")
                        .themedButtonPrimary()
                        .opacity(canCheckIn ? 1.0 : 0.5)
                }
                .disabled(!canCheckIn)
            }
            
            if let lastDate = lastCheckInDate {
                Divider()
                    .background(AppTheme.divider)
                
                HStack {
                    Text("Last check-in:")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.textTertiary)
                    
                    // Format as date only (no time)
                    Text(lastDate, format: .dateTime.month().day().year())
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.textSecondary)
                    
                    Spacer()
                    
                    if let lastCheckIn = viewModel.checkIns.first {
                        Text("+\(lastCheckIn.pointsAwarded)")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.success)
                            .fontWeight(.bold)
                    }
                }
            }
        }
        .themedCard()
        .sheet(isPresented: $showingScanner) {
            QRCodeScannerView(scannedCode: $scannedCode, isPresented: $showingScanner)
        }
        .onChange(of: scannedCode) { newValue in
            if let code = newValue {
                let result = viewModel.processCheckIn(qrCode: code)
                if result.success {
                    alertTitle = "Check-In Successful!"
                    alertMessage = "You earned \(viewModel.adminSettings.pointsPerCheckIn) points!"
                } else {
                    alertTitle = "Already Checked In"
                    alertMessage = result.message
                }
                showingAlert = true
                scannedCode = nil
            }
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK", role: .cancel, action: {})
        } message: {
            Text(alertMessage)
        }
    }
}

struct TrackSelectionCard: View {
    @ObservedObject var viewModel: CompleteAppViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Choose Your Learning Track")
                .font(AppTheme.Typography.headline)
                .foregroundColor(AppTheme.textPrimary)
            
            ForEach(TrackType.allCases, id: \.self) { track in
                Button(action: {
                    viewModel.selectTrack(track)
                }) {
                    HStack {
                        Image(systemName: track.icon)
                            .font(.title2)
                            .foregroundColor(track.themeColor)
                            .frame(width: 40)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(track.rawValue)
                                .font(AppTheme.Typography.headline)
                                .foregroundColor(AppTheme.textPrimary)
                            Text(track.description)
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(AppTheme.textSecondary)
                                .lineLimit(2)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(AppTheme.textTertiary)
                    }
                    .padding()
                    .background(AppTheme.cardBackground)
                    .cornerRadius(AppTheme.CornerRadius.md)
                }
            }
        }
        .padding()
        .background(AppTheme.backgroundTertiary.opacity(0.3))
        .cornerRadius(AppTheme.CornerRadius.lg)
    }
}

struct CurrentTrackCard: View {
    @ObservedObject var viewModel: CompleteAppViewModel
    
    var body: some View {
        if let track = viewModel.user.selectedTrack {
            let totalTaskGoal = 10
            let completedTasks = viewModel.user.totalTasksCompleted
            let progressValue = min(Double(completedTasks), Double(totalTaskGoal))
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: track.icon)
                        .font(.title)
                        .foregroundColor(track.color)
                    
                    VStack(alignment: .leading) {
                        Text("Current Track")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                        Text(track.rawValue)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        viewModel.user.selectedTrack = nil
                        viewModel.db.updateUser(viewModel.user)
                    }) {
                        Text("Change")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppTheme.medium)
                            .cornerRadius(8)
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }
                
                ProgressView(value: progressValue, total: Double(totalTaskGoal))
                    .tint(track.color)
                
                Text("\(completedTasks) of \(totalTaskGoal) tasks completed")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }
            .padding()
            .background(AppTheme.cardBackground)
            .cornerRadius(15)
        }
    }
}

struct QuickStatsView: View {
    @ObservedObject var viewModel: CompleteAppViewModel
    
    var body: some View {
        HStack(spacing: 15) {
            StatCard(title: "Streak", value: "\(viewModel.user.currentStreak)", icon: "flame.fill", color: AppTheme.warning)
            StatCard(title: "Tasks", value: "\(viewModel.user.totalTasksCompleted)", icon: "checkmark.circle.fill", color: AppTheme.success)
            StatCard(title: "Check-ins", value: "\(viewModel.checkIns.count)", icon: "mappin.circle.fill", color: AppTheme.mentalHealthColor)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppTheme.textPrimary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
    }
}

struct RecentActivityView: View {
    @ObservedObject var viewModel: CompleteAppViewModel

    var recentActivities: [(id: String, type: String, title: String, timestamp: Date, points: Int)] {
        var activities: [(id: String, type: String, title: String, timestamp: Date, points: Int)] = []

        // Add check-ins
        for checkIn in viewModel.checkIns {
            activities.append((
                id: checkIn.id,
                type: "checkin",
                title: "Check-in completed",
                timestamp: checkIn.timestamp,
                points: checkIn.pointsAwarded
            ))
        }

        // Add completed tasks
        for task in viewModel.tasks.filter({ $0.isCompleted }) {
            activities.append((
                id: task.id,
                type: "task",
                title: task.title,
                timestamp: task.completedDate ?? Date(),
                points: task.pointValue
            ))
        }

        // Sort by timestamp (most recent first) and take first 5
        return activities.sorted { $0.timestamp > $1.timestamp }.prefix(5).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Activity")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)

            if recentActivities.isEmpty {
                Text("No recent activity")
                    .foregroundColor(AppTheme.textSecondary)
                    .padding()
            } else {
                ForEach(recentActivities, id: \.id) { activity in
                    HStack {
                        Image(systemName: activity.type == "checkin" ? "qrcode" : "checkmark.circle.fill")
                            .foregroundColor(AppTheme.success)

                        VStack(alignment: .leading) {
                            Text(activity.title)
                                .foregroundColor(AppTheme.textPrimary)
                                .lineLimit(1)
                            Text(activity.timestamp, style: .relative)
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                        }

                        Spacer()

                        Text("+\(activity.points)")
                            .foregroundColor(AppTheme.success)
                            .fontWeight(.bold)
                    }
                    .padding()
                    .background(AppTheme.cardBackground)
                    .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(AppTheme.backgroundTertiary.opacity(0.2))
        .cornerRadius(15)
    }
}

// MARK: - Tasks View
struct TasksView: View {
    @ObservedObject var viewModel: CompleteAppViewModel

    var body: some View {
        NavigationView {
            ZStack {
                // Background image
                GeometryReader { geometry in
                    Image("TasksBackground")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .opacity(0.3)
                }
                .ignoresSafeArea()

                AppTheme.mainGradient
                    .opacity(0.7)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 15) {
                        if viewModel.tasks.isEmpty {
                            VStack(spacing: 20) {
                                Image(systemName: "list.bullet.clipboard")
                                    .font(.system(size: 60))
                                    .foregroundColor(AppTheme.textTertiary)
                                
                                Text("No tasks available")
                                    .font(.headline)
                                    .foregroundColor(AppTheme.textPrimary)
                                
                                Text("Select a learning track to get started")
                                    .font(.subheadline)
                                    .foregroundColor(AppTheme.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                        } else {
                            ForEach(viewModel.tasks) { task in
                                TaskCard(task: task, viewModel: viewModel)
                            }
                        }
                    }
                    .padding()
                }
                .navigationTitle("Your Tasks")
                .navigationBarTitleDisplayMode(.large)
            }
        }
    }
}

struct TaskCard: View {
    let task: LearningTask
    @ObservedObject var viewModel: CompleteAppViewModel
    @State private var showDetail = false
    
    var body: some View {
        Button(action: { showDetail = true }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    if task.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppTheme.success)
                    } else {
                        Image(systemName: "circle")
                            .foregroundColor(AppTheme.textTertiary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.title)
                            .font(.headline)
                            .foregroundColor(AppTheme.textPrimary)
                        
                        Text(task.description)
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textSecondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("\(task.pointValue)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.darkest)
                        Text("points")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
                
                HStack {
                    Label("\(task.estimatedMinutes) min", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                    
                    if let difficulty = task.difficultyLevel {
                        Spacer()
                        Text(difficulty.capitalized)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.medium)
                            .cornerRadius(6)
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }
            }
            .padding()
            .background(task.isCompleted ? AppTheme.success.opacity(0.2) : AppTheme.cardBackground)
            .cornerRadius(12)
        }
        .sheet(isPresented: $showDetail) {
            TaskDetailView(task: task, viewModel: viewModel)
        }
    }
}

struct TaskDetailView: View {
    let task: LearningTask
    @ObservedObject var viewModel: CompleteAppViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showingCompletion = false
    @State private var learningContent: String = ""
    @State private var isLoadingContent = false
    @State private var contentError: String?
    @State private var hasLoadedContent = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        VStack(alignment: .leading, spacing: 10) {
                            Text(task.title)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(AppTheme.textPrimary)
                            
                            Text(task.description)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .padding()
                        
                        // Details
                        VStack(spacing: 15) {
                            DetailRow(icon: "clock", label: "Duration", value: "\(task.estimatedMinutes) minutes")
                            DetailRow(icon: "star.fill", label: "Points", value: "\(task.pointValue)")
                            if let difficulty = task.difficultyLevel {
                                DetailRow(icon: "chart.bar", label: "Difficulty", value: difficulty.capitalized)
                            }
                            DetailRow(icon: "folder", label: "Category", value: task.category)
                        }
                        .padding()
                        .background(AppTheme.cardBackground)
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        // Learning Content from RAG
                        if !task.isCompleted {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Learning Material")
                                        .font(.headline)
                                        .foregroundColor(AppTheme.textPrimary)
                                    
                                    Spacer()
                                    
                                    if isLoadingContent {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    }
                                }
                                .padding(.horizontal)
                                
                                if isLoadingContent {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                        Spacer()
                                    }
                                    .padding()
                                    .background(AppTheme.cardBackground)
                                    .cornerRadius(12)
                                    .padding(.horizontal)
                                } else if let error = contentError {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundColor(AppTheme.warning)
                                            Text("Unable to load content")
                                                .font(.subheadline)
                                                .foregroundColor(AppTheme.textPrimary)
                                        }
                                        
                                        Text(error)
                                            .font(.caption)
                                            .foregroundColor(AppTheme.textSecondary)
                                        
                                        Button(action: {
                                            loadLearningContent()
                                        }) {
                                            Text("Retry")
                                                .font(.caption)
                                                .foregroundColor(AppTheme.darkest)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(AppTheme.medium)
                                                .cornerRadius(6)
                                        }
                                    }
                                    .padding()
                                    .background(AppTheme.cardBackground)
                                    .cornerRadius(12)
                                    .padding(.horizontal)
                                } else if !learningContent.isEmpty {
                                    Text(learningContent)
                                        .foregroundColor(AppTheme.textPrimary)
                                        .padding()
                                        .background(AppTheme.cardBackground)
                                        .cornerRadius(12)
                                        .padding(.horizontal)
                                } else {
                                    Text("Loading learning content from knowledge base...")
                                        .foregroundColor(AppTheme.textSecondary)
                                        .padding()
                                        .background(AppTheme.cardBackground)
                                        .cornerRadius(12)
                                        .padding(.horizontal)
                                }
                            }
                        }

                        // Q&A Section
                        if !task.isCompleted {
                            TaskQuestionSection(task: task, viewModel: viewModel)
                        }

                        // Complete Button
                        if !task.isCompleted {
                            Button(action: {
                                viewModel.completeTask(task)
                                showingCompletion = true
                            }) {
                                Text("Complete Task")
                                    .font(.headline)
                                    .foregroundColor(AppTheme.lightest)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(AppTheme.darkest)
                                    .cornerRadius(12)
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.textPrimary)
                }
            }
        }
        .onAppear {
            if !hasLoadedContent && !task.isCompleted {
                loadLearningContent()
            }
        }
        .alert("Task Completed!", isPresented: $showingCompletion) {
            Button("OK", action: {
                dismiss()
            })
        } message: {
            Text("You earned \(task.pointValue) points!")
        }
    }
    
    private func loadLearningContent() {
        guard !isLoadingContent else { return }
        
        // Get track string for RAG
        let trackString: String?
        if let track = task.trackType {
            trackString = track.ragTrackString
        } else if let userTrack = viewModel.user.selectedTrack {
            trackString = userTrack.ragTrackString
        } else {
            trackString = nil
        }
        
        // If no track available, show message
        guard let track = trackString else {
            contentError = "Please select a learning track to view content."
            return
        }
        
        isLoadingContent = true
        contentError = nil
        hasLoadedContent = true
        
        _Concurrency.Task.detached { @MainActor in
            do {
                // Check if Ollama is running
                let isConnected = await OllamaService.shared.checkOllamaConnection()

                // If Ollama is not connected, try Claude API fallback if enabled
                if !isConnected {
                    if viewModel.adminSettings.useClaudeAPIFallback,
                       let apiKey = viewModel.adminSettings.claudeAPIKey,
                       !apiKey.isEmpty {
                        // Use Claude API as fallback
                        do {
                            let prompt = """
                            Generate comprehensive learning content for a \(track) course.

                            Topic: \(task.title)
                            Description: \(task.description)
                            Difficulty Level: \(task.difficultyLevel ?? "intermediate")
                            User Goals: \(viewModel.user.goals.joined(separator: ", "))

                            Please provide detailed educational content including:
                            1. Key concepts and definitions
                            2. Step-by-step explanations
                            3. Practical examples
                            4. Best practices and tips
                            5. Common mistakes to avoid

                            Format the content in a clear, educational manner suitable for learning.
                            """

                            let content = try await OllamaService.shared.generateWithClaudeAPI(
                                prompt: prompt,
                                apiKey: apiKey
                            )

                            self.learningContent = content
                            self.isLoadingContent = false
                            return
                        } catch {
                            // Claude API failed, show error
                            self.isLoadingContent = false
                            self.contentError = "Claude API Error: \(error.localizedDescription)\n\nPlease check your API key in Admin Settings."
                            return
                        }
                    } else {
                        // Neither Ollama nor Claude API available
                        self.isLoadingContent = false
                        #if targetEnvironment(simulator)
                        self.contentError = "Ollama service is not running.\n\nOptions:\n1. Start Ollama: Run 'ollama serve' in Terminal\n2. Enable Claude API fallback in Admin Settings"
                        #else
                        self.contentError = "Cannot connect to Ollama.\n\nOptions:\n1. Configure Ollama (see Profile > Network Settings)\n2. Enable Claude API fallback in Admin Settings"
                        #endif
                        return
                    }
                }

                // Generate content - tries RAG first, falls back to direct Ollama
                // RAG uses database at /Users/chris/Desktop/rag_service/chroma_db/
                let content = try await OllamaService.shared.generateTrackContent(
                    trackType: track,
                    title: task.title,
                    description: task.description,
                    difficulty: task.difficultyLevel ?? "intermediate",
                    userGoals: viewModel.user.goals,
                    useRAG: true
                )

                self.learningContent = content
                self.isLoadingContent = false
            } catch let error as OllamaService.OllamaError {
                self.isLoadingContent = false

                // Try Claude API fallback if enabled
                if viewModel.adminSettings.useClaudeAPIFallback,
                   let apiKey = viewModel.adminSettings.claudeAPIKey,
                   !apiKey.isEmpty {
                    do {
                        let prompt = """
                        Generate comprehensive learning content for a \(track) course.

                        Topic: \(task.title)
                        Description: \(task.description)
                        Difficulty Level: \(task.difficultyLevel ?? "intermediate")
                        User Goals: \(viewModel.user.goals.joined(separator: ", "))

                        Please provide detailed educational content including:
                        1. Key concepts and definitions
                        2. Step-by-step explanations
                        3. Practical examples
                        4. Best practices and tips
                        5. Common mistakes to avoid

                        Format the content in a clear, educational manner suitable for learning.
                        """

                        let content = try await OllamaService.shared.generateWithClaudeAPI(
                            prompt: prompt,
                            apiKey: apiKey
                        )

                        self.learningContent = content
                        return
                    } catch {
                        // Show both errors
                        self.contentError = "Both services failed:\n\nOllama: \(error.localizedDescription)\nClaude API: Failed to generate content"
                        return
                    }
                }

                // No fallback available, show Ollama error
                switch error {
                case .connectionFailed:
                    self.contentError = "Cannot connect to Ollama.\n\nOptions:\n1. Start Ollama with 'ollama serve'\n2. Enable Claude API in Admin Settings"
                case .httpError(let code):
                    self.contentError = "Server error (code \(code)). Please try again in a moment."
                case .generationFailed(let msg):
                    self.contentError = "Generation failed: \(msg)\n\nTry enabling Claude API fallback in Admin Settings."
                default:
                    self.contentError = error.localizedDescription
                }
            } catch {
                self.isLoadingContent = false
                self.contentError = "Error: \(error.localizedDescription)\n\nConsider enabling Claude API fallback in Admin Settings."
            }
        }
    }
}

// MARK: - Task Q&A Section
struct TaskQuestionSection: View {
    let task: LearningTask
    @ObservedObject var viewModel: CompleteAppViewModel
    @State private var question: String = ""
    @State private var answer: String = ""
    @State private var isLoadingAnswer = false
    @State private var answerError: String?
    @State private var conversationHistory: [(question: String, answer: String)] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Ask Questions")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
                .padding(.horizontal)

            // Conversation History
            if !conversationHistory.isEmpty {
                VStack(spacing: 12) {
                    ForEach(Array(conversationHistory.enumerated()), id: \.offset) { index, qa in
                        VStack(alignment: .leading, spacing: 8) {
                            // Question
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(AppTheme.darkest)
                                Text(qa.question)
                                    .font(.subheadline)
                                    .foregroundColor(AppTheme.textPrimary)
                                Spacer()
                            }

                            // Answer
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "brain.head.profile")
                                    .foregroundColor(.purple)
                                Text(qa.answer)
                                    .font(.subheadline)
                                    .foregroundColor(AppTheme.textSecondary)
                                Spacer()
                            }
                        }
                        .padding()
                        .background(AppTheme.cardBackground)
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
            }

            // Current Answer (if loading or new)
            if isLoadingAnswer {
                HStack {
                    ProgressView()
                    Text("Thinking...")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                }
                .padding()
                .background(AppTheme.cardBackground)
                .cornerRadius(10)
                .padding(.horizontal)
            } else if let error = answerError {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(AppTheme.warning)
                        Text("Error")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    Text(error)
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
                .padding()
                .background(AppTheme.cardBackground)
                .cornerRadius(10)
                .padding(.horizontal)
            } else if !answer.isEmpty && conversationHistory.isEmpty {
                // Show first answer before it's added to history
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.purple)
                        Text(answer)
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textSecondary)
                        Spacer()
                    }
                }
                .padding()
                .background(AppTheme.cardBackground)
                .cornerRadius(10)
                .padding(.horizontal)
            }

            // Question Input
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    TextField("Ask a question about this task...", text: $question)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.sentences)

                    Button(action: {
                        askQuestion()
                    }) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.white)
                            .padding(10)
                            .background(question.isEmpty || isLoadingAnswer ? AppTheme.textTertiary : AppTheme.darkest)
                            .cornerRadius(8)
                    }
                    .disabled(question.isEmpty || isLoadingAnswer)
                }

                if conversationHistory.isEmpty && answer.isEmpty && !isLoadingAnswer {
                    Text("Try asking: \"Can you explain this in simpler terms?\" or \"What are the key takeaways?\"")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            .padding()
            .background(AppTheme.cardBackground.opacity(0.5))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }

    private func askQuestion() {
        guard !question.isEmpty, !isLoadingAnswer else { return }

        let currentQuestion = question
        question = ""
        answerError = nil
        isLoadingAnswer = true

        _Concurrency.Task.detached { @MainActor in
            do {
                // Check connection
                let isConnected = await OllamaService.shared.checkOllamaConnection()
                guard isConnected else {
                    #if targetEnvironment(simulator)
                    self.answerError = "Ollama is not running. Start it with: ollama serve"
                    #else
                    self.answerError = "Cannot connect. Check Profile > Network Settings"
                    #endif
                    self.isLoadingAnswer = false
                    return
                }

                // Build context-aware prompt
                let contextPrompt = """
                Task: \(task.title)
                Description: \(task.description)
                Category: \(task.category)

                User Question: \(currentQuestion)

                Please provide a clear, helpful answer related to this learning task.
                """

                // Ask question
                let response = try await OllamaService.shared.askQuestion(
                    question: contextPrompt,
                    model: nil // Uses default model
                )

                // Add to conversation history
                self.conversationHistory.append((question: currentQuestion, answer: response))
                self.answer = response
                self.isLoadingAnswer = false
            } catch {
                self.answerError = "Error: \(error.localizedDescription)"
                self.isLoadingAnswer = false
            }
        }
    }
}

struct DetailRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(AppTheme.darkest)
                .frame(width: 30)
            
            Text(label)
                .foregroundColor(AppTheme.textSecondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.textPrimary)
        }
    }
}

// MARK: - Rewards View
struct RewardsView: View {
    @ObservedObject var viewModel: CompleteAppViewModel
    
    let rewards = [
        Reward(title: "Coffee Card", description: "Local coffee shop gift card", points: 500, icon: "cup.and.saucer.fill", color: AppTheme.hvacColor),
        Reward(title: "Bus Pass", description: "Monthly transit pass", points: 750, icon: "bus.fill", color: AppTheme.mentalHealthColor),
        Reward(title: "Grocery Voucher", description: "$25 grocery store credit", points: 1000, icon: "cart.fill", color: AppTheme.nursingColor),
        Reward(title: "Tool Kit", description: "Basic professional tool kit", points: 2000, icon: "wrench.and.screwdriver.fill", color: AppTheme.warning),
        Reward(title: "Work Boots", description: "Professional work boots", points: 2500, icon: "figure.walk", color: AppTheme.dark),
        Reward(title: "Course Certificate", description: "Professional certification course", points: 5000, icon: "graduationcap.fill", color: AppTheme.spiritualColor)
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background image
                GeometryReader { geometry in
                    Image("RewardsBackground")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .opacity(0.3)
                }
                .ignoresSafeArea()

                AppTheme.mainGradient
                    .opacity(0.7)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Points Balance Card
                        VStack(spacing: 10) {
                            Text("Your Points")
                                .font(.headline)
                                .foregroundColor(AppTheme.textSecondary)
                            
                            Text("\(viewModel.user.pointsBalance)")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(AppTheme.darkest)
                            
                            Text("Available to redeem")
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.cardBackground)
                        .cornerRadius(20)
                        
                        // Rewards Grid
                        VStack(spacing: 15) {
                            ForEach(rewards) { reward in
                                RewardCard(reward: reward, userPoints: viewModel.user.pointsBalance)
                            }
                        }
                    }
                    .padding()
                }
                .navigationTitle("Rewards")
            }
        }
    }
}

struct Reward: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let points: Int
    let icon: String
    let color: Color
}

struct RewardCard: View {
    let reward: Reward
    let userPoints: Int
    @State private var showingRedeemAlert = false
    
    var canAfford: Bool {
        userPoints >= reward.points
    }
    
    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                Circle()
                    .fill(reward.color.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: reward.icon)
                    .font(.title2)
                    .foregroundColor(reward.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(reward.title)
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
                
                Text(reward.description)
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(2)
                
                HStack {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(AppTheme.darkest)
                    Text("\(reward.points) points")
                        .font(.caption)
                        .foregroundColor(AppTheme.darkest)
                }
            }
            
            Spacer()
            
            Button(action: {
                if canAfford {
                    showingRedeemAlert = true
                }
            }) {
                Text(canAfford ? "Redeem" : "Locked")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.lightest)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(canAfford ? AppTheme.darkest : AppTheme.textTertiary)
                    .cornerRadius(8)
            }
            .disabled(!canAfford)
        }
        .padding()
        .background(canAfford ? AppTheme.cardBackground : AppTheme.backgroundSecondary.opacity(0.5))
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(canAfford ? reward.color.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .alert("Redeem Reward", isPresented: $showingRedeemAlert) {
            Button("Cancel", role: .cancel, action: {})
            Button("Confirm", action: {
                // Redeem logic would go here
            })
        } message: {
            Text("Are you sure you want to redeem '\(reward.title)' for \(reward.points) points?")
        }
    }
}

// MARK: - Resources View
struct ResourcesView: View {
    @ObservedObject var viewModel: CompleteAppViewModel

    var body: some View {
        NavigationView {
            ZStack {
                // Background image
                GeometryReader { geometry in
                    Image("ResourcesBackground")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .opacity(0.3)
                }
                .ignoresSafeArea()

                AppTheme.mainGradient
                    .opacity(0.7)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Track-Specific Resources
                        if let track = viewModel.user.selectedTrack {
                            TrackResourcesSection(track: track)
                        }
                        
                        // General Resources
                        GeneralResourcesSection()
                        
                        // Community Resources
                        CommunityResourcesSection()
                        
                        // Support Services
                        SupportServicesSection()
                    }
                    .padding()
                }
                .navigationTitle("Resources")
            }
        }
    }
}

struct TrackResourcesSection: View {
    let track: TrackType
    
    var trackResources: [(String, String, String)] {
        switch track {
        case .hvac:
            return [
                ("HVAC Excellence", "Certification resources", "link"),
                ("EPA 608 Certification", "Environmental certification guide", "doc.text"),
                ("Trade Tools Guide", "Essential tools and equipment", "wrench.and.screwdriver")
            ]
        case .nursing:
            return [
                ("NCLEX Prep", "Nursing exam preparation", "book.fill"),
                ("Clinical Skills", "Hands-on procedure guides", "cross.case"),
                ("Patient Care Guide", "Best practices manual", "heart.text.square")
            ]
        case .spiritual:
            return [
                ("Daily Devotionals", "Spiritual growth resources", "book.closed"),
                ("Prayer Guide", "Prayer and meditation practices", "hands.sparkles"),
                ("Scripture Study", "Bible study materials", "text.book.closed")
            ]
        case .mentalHealth:
            return [
                ("Mindfulness App", "Guided meditation exercises", "brain.head.profile"),
                ("Wellness Journal", "Mental health tracking", "square.and.pencil"),
                ("Support Groups", "Community connections", "person.3")
            ]
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: track.icon)
                    .foregroundColor(track.color)
                Text("\(track.rawValue) Resources")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
            }
            
            ForEach(trackResources, id: \.0) { resource in
                ResourceRow(title: resource.0, description: resource.1, icon: resource.2)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(15)
    }
}

struct GeneralResourcesSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("General Resources")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
            
            ResourceRow(title: "Job Search", description: "Employment opportunities", icon: "briefcase.fill")
            ResourceRow(title: "Resume Builder", description: "Create professional resumes", icon: "doc.text.fill")
            ResourceRow(title: "Interview Tips", description: "Ace your next interview", icon: "person.fill.questionmark")
            ResourceRow(title: "Financial Literacy", description: "Money management basics", icon: "dollarsign.circle.fill")
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(15)
    }
}

struct CommunityResourcesSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Community Resources")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
            
            ResourceRow(title: "Housing Assistance", description: "Find affordable housing", icon: "house.fill")
            ResourceRow(title: "Food Programs", description: "Meal assistance programs", icon: "fork.knife")
            ResourceRow(title: "Transportation", description: "Public transit information", icon: "bus.fill")
            ResourceRow(title: "Childcare Services", description: "Childcare support options", icon: "figure.2.and.child.holdinghands")
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(15)
    }
}

struct SupportServicesSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Support Services")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
            
            ResourceRow(title: "Counseling", description: "Mental health support", icon: "heart.circle.fill")
            ResourceRow(title: "Legal Aid", description: "Free legal consultation", icon: "building.columns.fill")
            ResourceRow(title: "Medical Clinic", description: "Healthcare services", icon: "cross.circle.fill")
            ResourceRow(title: "Emergency Hotline", description: "24/7 crisis support", icon: "phone.circle.fill")
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(15)
    }
}

struct ResourceRow: View {
    let title: String
    let description: String
    let icon: String
    
    var body: some View {
        Button(action: {
            // Open resource action
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(AppTheme.darkest)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppTheme.textTertiary)
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Check-In View (Keep for reference but not in tabs)
/*
struct CheckInView: View {
    @ObservedObject var viewModel: CompleteAppViewModel
    @State private var showingScanner = false
    @State private var scannedCode: String?
    @State private var showingSuccess = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.2, blue: 0.45), Color(red: 0.2, green: 0.1, blue: 0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("Daily Check-In")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 100))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("Scan a QR code to check in")
                    .foregroundColor(.white.opacity(0.8))
                
                Button(action: {
                    showingScanner = true
                }) {
                    Text("Scan QR Code")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                
                if !viewModel.checkIns.isEmpty {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Recent Check-Ins")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        ForEach(viewModel.checkIns.prefix(5)) { checkIn in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                
                                VStack(alignment: .leading) {
                                    Text(checkIn.timestamp, style: .date)
                                        .foregroundColor(.white)
                                    Text(checkIn.timestamp, style: .time)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                
                                Spacer()
                                
                                Text("+\(checkIn.pointsAwarded)")
                                    .foregroundColor(.yellow)
                                    .fontWeight(.bold)
                            }
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }
                    .padding()
                }
            }
            .padding()
        }
        .sheet(isPresented: $showingScanner) {
            QRCodeScannerView(scannedCode: $scannedCode, isPresented: $showingScanner)
        }
        .onChange(of: scannedCode) { newValue in
            if let code = newValue {
                viewModel.processCheckIn(qrCode: code)
                showingSuccess = true
                scannedCode = nil
            }
        }
        .alert("Check-In Successful!", isPresented: $showingSuccess) {
            Button("OK", role: .cancel, action: {})
        } message: {
            Text("You earned \(viewModel.adminSettings.pointsPerCheckIn) points!")
        }
    }
}
*/

// MARK: - Profile View
struct ProfileView: View {
    @ObservedObject var viewModel: CompleteAppViewModel

    var body: some View {
        NavigationView {
            ZStack {
                // Background image
                GeometryReader { geometry in
                    Image("ProfileBackground")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .opacity(0.3)
                }
                .ignoresSafeArea()

                AppTheme.mainGradient
                    .opacity(0.7)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Profile Header
                        VStack(spacing: 10) {
                            Circle()
                                .fill(AppTheme.dark.opacity(0.3))
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Text(String(viewModel.user.name.prefix(1)))
                                        .font(.system(size: 40, weight: .bold))
                                        .foregroundColor(AppTheme.darkest)
                                )
                            
                            Text(viewModel.user.name)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(AppTheme.textPrimary)
                            
                            Text(viewModel.user.email)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .padding()

                        // User Level and Points Chart
                        UserLevelChart(viewModel: viewModel, showDetailedStats: true)
                            .padding(.horizontal)

                        // Stats
                        VStack(spacing: 15) {
                            ProfileStatRow(label: "Total Points", value: "\(viewModel.user.pointsBalance)")
                            ProfileStatRow(label: "Tasks Completed", value: "\(viewModel.user.totalTasksCompleted)")
                            ProfileStatRow(label: "Current Streak", value: "\(viewModel.user.currentStreak) days")
                            ProfileStatRow(label: "Check-Ins", value: "\(viewModel.checkIns.count)")
                        }
                        .padding()
                        .background(AppTheme.cardBackground)
                        .cornerRadius(15)
                        
                        // Goals
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Your Goals")
                                .font(.headline)
                                .foregroundColor(AppTheme.textPrimary)

                            ForEach(viewModel.user.goals, id: \.self) { goal in
                                HStack {
                                    Image(systemName: "target")
                                        .foregroundColor(AppTheme.darkest)
                                    Text(goal)
                                        .foregroundColor(AppTheme.textPrimary)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppTheme.cardBackground)
                                .cornerRadius(10)
                            }
                        }
                        .padding()

                        // Network Settings
                        NetworkSettingsCard()
                            .padding(.horizontal)
                        
                        // Test Account Switcher (for development/testing)
                        TestAccountSwitcherCard(viewModel: viewModel)
                            .padding(.horizontal)
                    }
                    .padding()
                }
                .navigationTitle("Profile")
            }
        }
    }
}

struct ProfileStatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(AppTheme.textSecondary)
            Spacer()
            Text(value)
                .fontWeight(.bold)
                .foregroundColor(AppTheme.textPrimary)
        }
    }
}

// MARK: - Network Settings Card
struct NetworkSettingsCard: View {
    @ObservedObject private var ollamaService = OllamaService.shared
    @State private var customIP: String = ""
    @State private var isEditing = false
    @State private var connectionStatus: ConnectionStatus = .unknown
    @State private var isCheckingConnection = false

    enum ConnectionStatus {
        case unknown, connected, disconnected
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Network Settings")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)

            VStack(alignment: .leading, spacing: 12) {
                // Connection Status
                HStack {
                    Image(systemName: connectionStatus == .connected ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(connectionStatus == .connected ? .green : .red)
                    Text("Ollama Status")
                        .foregroundColor(AppTheme.textPrimary)
                    Spacer()
                    Text(connectionStatus == .connected ? "Connected" : connectionStatus == .disconnected ? "Disconnected" : "Unknown")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }

                // Current URL Display
                VStack(alignment: .leading, spacing: 5) {
                    Text("Current URL")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                    Text(ollamaService.getCurrentOllamaURL())
                        .font(.caption2)
                        .foregroundColor(AppTheme.textSecondary.opacity(0.8))
                        .lineLimit(1)
                }

                // Physical Device IP Configuration
                #if !targetEnvironment(simulator)
                Divider()
                    .background(AppTheme.textSecondary.opacity(0.3))

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Mac IP Address")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.textPrimary)

                        if ollamaService.customMacIP == nil || ollamaService.customMacIP?.isEmpty == true {
                            Text("REQUIRED")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red.opacity(0.8))
                                .cornerRadius(6)
                        }
                    }

                    if isEditing {
                        VStack(spacing: 10) {
                            TextField("IP, domain, or Cloudflare URL", text: $customIP)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .keyboardType(.URL)

                            HStack {
                                Button("Cancel") {
                                    isEditing = false
                                    customIP = ollamaService.customMacIP ?? ""
                                }
                                .foregroundColor(.red)

                                Spacer()

                                Button("Save") {
                                    ollamaService.customMacIP = customIP.isEmpty ? nil : customIP
                                    isEditing = false
                                    Task {
                                        await checkConnection()
                                    }
                                }
                                .foregroundColor(.blue)
                            }
                        }
                    } else {
                        HStack {
                            if let ip = ollamaService.customMacIP, !ip.isEmpty {
                                Text(ip)
                                    .foregroundColor(AppTheme.textPrimary)
                            } else {
                                Text("Not configured - tap Set Now")
                                    .foregroundColor(.orange.opacity(0.9))
                                    .italic()
                            }
                            Spacer()
                            Button(action: {
                                customIP = ollamaService.customMacIP ?? ""
                                isEditing = true
                            }) {
                                Text(ollamaService.customMacIP == nil || ollamaService.customMacIP?.isEmpty == true ? "Set Now" : "Edit")
                                    .foregroundColor(.blue)
                                    .fontWeight(ollamaService.customMacIP == nil || ollamaService.customMacIP?.isEmpty == true ? .semibold : .regular)
                            }
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            Text("📍 Connection Options:")
                                .font(.caption2)
                                .foregroundColor(AppTheme.textSecondary)
                                .padding(.top, 5)

                            Text("• Local IP: 192.168.1.100")
                                .font(.caption2)
                                .foregroundColor(AppTheme.textSecondary.opacity(0.8))

                            Text("• Cloudflare: ollama.yourdomain.com")
                                .font(.caption2)
                                .foregroundColor(AppTheme.textSecondary.opacity(0.8))

                            Text("• With port: 192.168.1.100:11434")
                                .font(.caption2)
                                .foregroundColor(AppTheme.textSecondary.opacity(0.8))

                            Divider()
                                .background(AppTheme.textSecondary.opacity(0.3))
                                .padding(.vertical, 4)

                            Text("Find IP: ipconfig getifaddr en0")
                                .font(.caption2)
                                .foregroundColor(AppTheme.textSecondary.opacity(0.8))
                                .fontWeight(.semibold)
                        }
                        .padding(.top, 8)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .background(AppTheme.dark.opacity(0.2))
                        .cornerRadius(8)
                    }
                }
                #endif

                // Test Connection Button
                Button(action: {
                    Task {
                        await checkConnection()
                    }
                }) {
                    HStack {
                        if isCheckingConnection {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "wifi.circle.fill")
                        }
                        Text("Test Connection")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.darkest.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isCheckingConnection)
            }
            .padding()
            .background(AppTheme.cardBackground)
            .cornerRadius(15)
        }
        .onAppear {
            customIP = ollamaService.customMacIP ?? ""
            Task {
                await checkConnection()
            }
        }
    }

    private func checkConnection() async {
        await MainActor.run {
            isCheckingConnection = true
        }

        let isConnected = await ollamaService.checkOllamaConnection()

        await MainActor.run {
            connectionStatus = isConnected ? .connected : .disconnected
            isCheckingConnection = false
        }
    }
}

// MARK: - Test Account Switcher Card
struct TestAccountSwitcherCard: View {
    @ObservedObject var viewModel: CompleteAppViewModel
    @State private var isExpanded = false
    
    // Define 5 test accounts with different profiles
    let testAccounts: [(id: String, name: String, email: String, description: String)] = [
        ("test_user_001", "Alex Johnson", "alex.johnson@test.com", "HVAC Track, High Engagement"),
        ("test_user_002", "Maria Garcia", "maria.garcia@test.com", "Nursing Track, New User"),
        ("test_user_003", "James Smith", "james.smith@test.com", "Spiritual Track, Regular User"),
        ("test_user_004", "Sarah Lee", "sarah.lee@test.com", "Mental Health Track, Power User"),
        ("test_user_005", "David Chen", "david.chen@test.com", "HVAC Track, Returning User")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Header with toggle
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "person.2.circle.fill")
                        .foregroundColor(.orange)
                    Text("Test Account Switcher")
                        .font(.headline)
                        .foregroundColor(AppTheme.textPrimary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle")
                        .foregroundColor(.orange)
                }
            }
            
            if isExpanded {
                VStack(spacing: 10) {
                    Text("Switch between test accounts to simulate different users")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                        .padding(.bottom, 5)
                    
                    ForEach(testAccounts, id: \.id) { account in
                        TestAccountRow(
                            account: account,
                            isCurrentUser: viewModel.user.id == account.id,
                            onSelect: {
                                switchToAccount(account)
                            }
                        )
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.orange.opacity(0.3), lineWidth: 2)
        )
    }
    
    private func switchToAccount(_ account: (id: String, name: String, email: String, description: String)) {
        let db = EnhancedDatabaseManager.shared
        
        // Check if user already exists
        if let existingUser = db.getUser(id: account.id) {
            // Switch to existing user
            viewModel.user = existingUser
            viewModel.loadData()
            print("✅ Switched to existing test account: \(account.name)")
        } else {
            // Create new test user with sample data
            let trackTypes: [TrackType] = [.hvac, .nursing, .spiritual, .mentalHealth]
            let track = trackTypes[Int.random(in: 0..<trackTypes.count)]
            
            let newUser = User(
                id: account.id,
                name: account.name,
                email: account.email,
                goals: ["Personal Development", "Career Growth", "Financial Stability"],
                pointsBalance: Int.random(in: 500...3000),
                currentStreak: Int.random(in: 0...15),
                totalTasksCompleted: Int.random(in: 5...50),
                selectedTrack: track,
                isAdmin: account.id == "test_user_001" // Make first test account admin
            )
            
            // Save to database
            db.saveUser(newUser)
            
            // Create some sample check-ins
            for dayOffset in 0..<Int.random(in: 3...10) {
                if let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date()) {
                    let checkIn = CheckInEvent(
                        id: UUID().uuidString,
                        userId: account.id,
                        timestamp: date,
                        qrCodeData: "TEST_QR_\(dayOffset)",
                        location: "Test Location",
                        pointsAwarded: 100
                    )
                    db.saveCheckIn(checkIn)
                }
            }
            
            // Switch to the new user
            viewModel.user = newUser
            viewModel.loadData()

            print("✅ Created and switched to new test account: \(account.name)")
            print("   Track: \(track.rawValue)")
            print("   Points: \(newUser.pointsBalance)")
            print("   Level: \(newUser.level)")
        }

        // Log the account switch
        db.logEvent(userId: account.id, eventType: "test_account_switch", eventData: account.name)
    }
}

struct TestAccountRow: View {
    let account: (id: String, name: String, email: String, description: String)
    let isCurrentUser: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Profile icon
                Circle()
                    .fill(isCurrentUser ? AppTheme.darkest : AppTheme.medium.opacity(0.5))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(account.name.prefix(1)))
                            .font(.headline)
                            .foregroundColor(.white)
                    )
                
                // Account info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(account.name)
                            .font(.subheadline)
                            .fontWeight(isCurrentUser ? .bold : .regular)
                            .foregroundColor(AppTheme.textPrimary)
                        
                        if isCurrentUser {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }
                    
                    Text(account.email)
                        .font(.caption2)
                        .foregroundColor(AppTheme.textSecondary)
                    
                    Text(account.description)
                        .font(.caption2)
                        .foregroundColor(AppTheme.textSecondary.opacity(0.8))
                        .italic()
                }
                
                Spacer()
                
                // Action indicator
                if !isCurrentUser {
                    Image(systemName: "arrow.right.circle")
                        .foregroundColor(AppTheme.darkest.opacity(0.6))
                }
            }
            .padding(12)
            .background(
                isCurrentUser
                    ? LinearGradient(
                        gradient: Gradient(colors: [AppTheme.darkest.opacity(0.3), AppTheme.medium.opacity(0.3)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    : LinearGradient(
                        gradient: Gradient(colors: [Color.clear, Color.clear]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
            )
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isCurrentUser ? AppTheme.darkest : AppTheme.textSecondary.opacity(0.2),
                        lineWidth: isCurrentUser ? 2 : 1
                    )
            )
        }
        .disabled(isCurrentUser)
    }
}

// MARK: - Admin Dashboard View
struct AdminDashboardView: View {
    @ObservedObject var viewModel: CompleteAppViewModel
    @State private var showingSettings = false

    var body: some View {
        NavigationView {
            ZStack {
                // Background image
                GeometryReader { geometry in
                    Image("AdminBackground")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .opacity(0.3)
                }
                .ignoresSafeArea()

                AppTheme.mainGradient
                    .opacity(0.7)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Budget Overview
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Budget Overview")
                                .font(.headline)
                                .foregroundColor(AppTheme.textPrimary)
                            
                            BudgetCard(
                                title: "Total Budget",
                                value: "$\(Int(viewModel.adminSettings.totalBudget))",
                                icon: "dollarsign.circle.fill",
                                color: AppTheme.success
                            )
                            
                            BudgetCard(
                                title: "Weekly Budget",
                                value: "$\(Int(viewModel.adminSettings.maxBudgetPerWeek))",
                                icon: "calendar",
                                color: AppTheme.mentalHealthColor
                            )
                            
                            BudgetCard(
                                title: "Expected Users/Week",
                                value: "\(viewModel.adminSettings.expectedUsersPerWeek)",
                                icon: "person.3.fill",
                                color: AppTheme.warning
                            )
                        }
                        .padding()
                        .background(AppTheme.cardBackground)
                        .cornerRadius(15)
                        
                        // Point Allocation Settings
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Point Allocation")
                                .font(.headline)
                                .foregroundColor(AppTheme.textPrimary)
                            
                            Toggle("Auto-Allocate Points", isOn: Binding(
                                get: { viewModel.adminSettings.autoAllocatePoints },
                                set: { newValue in
                                    var settings = viewModel.adminSettings
                                    settings.autoAllocatePoints = newValue
                                    viewModel.updateAdminSettings(settings)
                                }
                            ))
                            .foregroundColor(AppTheme.textPrimary)
                            .tint(AppTheme.darkest)
                            
                            PointValueRow(label: "Check-In", value: viewModel.adminSettings.pointsPerCheckIn)
                            PointValueRow(label: "Task Completion", value: viewModel.adminSettings.pointsPerTaskCompletion)
                            PointValueRow(label: "Quiz Pass", value: viewModel.adminSettings.pointsPerQuizPass)
                        }
                        .padding()
                        .background(AppTheme.cardBackground)
                        .cornerRadius(15)
                        
                        // Quick Actions
                        VStack(spacing: 12) {
                            Button(action: { showingSettings = true }) {
                                Text("Edit Settings")
                                    .font(.headline)
                                    .foregroundColor(AppTheme.lightest)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(AppTheme.darkest)
                                    .cornerRadius(12)
                            }
                            
                            NavigationLink(destination: LLMDiagnosticsView()) {
                                HStack {
                                    Image(systemName: "waveform")
                                        .foregroundColor(AppTheme.darkest)
                                    Text("LLM Diagnostics")
                                        .font(.headline)
                                        .foregroundColor(AppTheme.darkest)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppTheme.medium)
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding()
                }
                .navigationTitle("Admin Dashboard")
                .sheet(isPresented: $showingSettings) {
                    AdminSettingsView(viewModel: viewModel)
                }
            }
        }
    }
}

struct BudgetCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.textPrimary)
            }
            
            Spacer()
        }
        .padding()
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(10)
    }
}

struct PointValueRow: View {
    let label: String
    let value: Int
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(AppTheme.textSecondary)
            Spacer()
            Text("\(value) points")
                .fontWeight(.bold)
                .foregroundColor(AppTheme.darkest)
        }
    }
}

struct AdminSettingsView: View {
    @ObservedObject var viewModel: CompleteAppViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var totalBudget: String
    @State private var programLength: String
    @State private var usersPerWeek: String
    @State private var checkInPoints: String
    @State private var taskPoints: String
    @State private var quizPoints: String
    @State private var useClaudeFallback: Bool
    @State private var claudeAPIKey: String

    init(viewModel: CompleteAppViewModel) {
        self.viewModel = viewModel
        _totalBudget = State(initialValue: String(Int(viewModel.adminSettings.totalBudget)))
        _programLength = State(initialValue: String(viewModel.adminSettings.programLengthWeeks))
        _usersPerWeek = State(initialValue: String(viewModel.adminSettings.expectedUsersPerWeek))
        _checkInPoints = State(initialValue: String(viewModel.adminSettings.pointsPerCheckIn))
        _taskPoints = State(initialValue: String(viewModel.adminSettings.pointsPerTaskCompletion))
        _quizPoints = State(initialValue: String(viewModel.adminSettings.pointsPerQuizPass))
        _useClaudeFallback = State(initialValue: viewModel.adminSettings.useClaudeAPIFallback)
        _claudeAPIKey = State(initialValue: viewModel.adminSettings.claudeAPIKey ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Budget Settings")) {
                    HStack {
                        Text("Total Budget")
                        TextField("Amount", text: $totalBudget)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Program Length (weeks)")
                        TextField("Weeks", text: $programLength)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Expected Users/Week")
                        TextField("Users", text: $usersPerWeek)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section(header: Text("Point Values")) {
                    HStack {
                        Text("Check-In Points")
                        TextField("Points", text: $checkInPoints)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Task Completion Points")
                        TextField("Points", text: $taskPoints)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Quiz Pass Points")
                        TextField("Points", text: $quizPoints)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section(header: Text("AI Content Generation")) {
                    Toggle("Use Claude API Fallback", isOn: $useClaudeFallback)

                    if useClaudeFallback {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Claude API Key")
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)

                            SecureField("sk-ant-...", text: $claudeAPIKey)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()

                            Text("When Ollama connection fails, the app will automatically use Claude API to generate task content. Get your API key from console.anthropic.com")
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } else {
                        Text("Enable this to use Claude API as a fallback when Ollama is unavailable")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
            }
            .navigationTitle("Admin Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSettings()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveSettings() {
        var settings = viewModel.adminSettings

        if let budget = Double(totalBudget) {
            settings.totalBudget = budget
        }
        if let length = Int(programLength) {
            settings.programLengthWeeks = length
            settings.maxBudgetPerWeek = settings.totalBudget / Double(length)
        }
        if let users = Int(usersPerWeek) {
            settings.expectedUsersPerWeek = users
        }
        if let points = Int(checkInPoints) {
            settings.pointsPerCheckIn = points
        }
        if let points = Int(taskPoints) {
            settings.pointsPerTaskCompletion = points
        }
        if let points = Int(quizPoints) {
            settings.pointsPerQuizPass = points
        }

        // Save Claude API settings
        settings.useClaudeAPIFallback = useClaudeFallback
        settings.claudeAPIKey = claudeAPIKey.isEmpty ? nil : claudeAPIKey

        viewModel.updateAdminSettings(settings)
    }
}

// MARK: - LLM Diagnostics View
struct LLMDiagnosticsView: View {
    @State private var ollamaStatus = "Checking..."
    @State private var ragStatus = "Checking..."
    @State private var availableModels: [String] = []
    @State private var isChecking = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Ollama Service") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(ollamaStatus)
                            .foregroundColor(ollamaStatus == "Connected ✅" ? AppTheme.success : AppTheme.warning)
                    }
                    
                    if !availableModels.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Available Models")
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                            ForEach(availableModels, id: \.self) { model in
                                Text("• \(model)")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                        }
                    }
                }
                
                Section("RAG Service") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(ragStatus)
                            .foregroundColor(ragStatus == "Connected ✅" ? AppTheme.success : AppTheme.textSecondary)
                    }
                    
                    if ragStatus == "Connected ✅" {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("RAG Enabled")
                                .font(.caption)
                                .foregroundColor(AppTheme.success)
                            Text("Learning content will be enhanced with knowledge base")
                                .font(.caption2)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("RAG Disabled")
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                            Text("Using direct Ollama generation (still works great!)")
                                .font(.caption2)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                }
                
                Section("Setup Instructions") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("To use AI-powered learning content:")
                            .fontWeight(.semibold)
                        
                        Text("1. Install Ollama")
                            .font(.caption)
                        Text("Visit ollama.ai to download")
                            .font(.caption2)
                            .foregroundColor(AppTheme.textSecondary)
                        
                        Text("2. Start Ollama Server")
                            .font(.caption)
                        Text("Run 'ollama serve' in Terminal")
                            .font(.caption2)
                            .foregroundColor(AppTheme.textSecondary)
                        
                        Text("3. Pull a Model")
                            .font(.caption)
                        Text("Run 'ollama pull llama2' (or llama2/mistral for alternatives)")
                            .font(.caption2)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .padding(.vertical, 8)
                }
                
                Section {
                    Button {
                        _Concurrency.Task.detached { @MainActor in
                            await checkConnections()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if isChecking {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Text(isChecking ? "Checking..." : "Refresh Status")
                            Spacer()
                        }
                    }
                    .disabled(isChecking)
                }
            }
            .navigationTitle("LLM Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                _Concurrency.Task.detached { @MainActor in
                    await checkConnections()
                }
            }
        }
    }
    
    private func checkConnections() async {
        isChecking = true
        
        // Check Ollama
        let ollamaConnected = await OllamaService.shared.checkOllamaConnection()
        await MainActor.run {
            ollamaStatus = ollamaConnected ? "Connected ✅" : "Not Running ❌"
        }
        
        // Get available models if connected
        if ollamaConnected {
            do {
                let models = try await OllamaService.shared.getAvailableModels()
                await MainActor.run {
                    availableModels = models
                }
            } catch {
                await MainActor.run {
                    availableModels = []
                }
            }
        }
        
        // Check RAG
        let ragConnected = await OllamaService.shared.checkRAGConnection()
        await MainActor.run {
            ragStatus = ragConnected ? "Connected ✅" : "Optional (Not Running)"
            isChecking = false
        }
    }
}

// MARK: - Main App Entry Point
@main
struct WorkforceDevApp: App {
    var body: some Scene {
        WindowGroup {
            CompleteAppView()
        }
    }
}

// MARK: - Preview
struct CompleteAppView_Previews: PreviewProvider {
    static var previews: some View {
        CompleteAppView()
    }
}



