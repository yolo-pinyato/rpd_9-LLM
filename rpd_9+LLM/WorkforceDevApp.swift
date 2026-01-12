//
/*
 * COMMENTED OUT - This file has been replaced by rpd_9_LLMApp.swift
 * This version contains the original implementation and is kept for reference only.
 * The active version is in rpd_9_LLMApp.swift which includes:
 * - Check-in functionality integrated into Home tab
 * - Rewards redemption system
 * - Resources directory
 * - All original features
 */

/*
//  WorkforceDevApp.swift
//  rpd_9+LLM
//
//  Created by Chris on 11/20/25.
//


import SwiftUI
import Combine
import SQLite3

// MARK: - App Entry Point
@main
struct WorkforceDevApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - Database Manager
// Note: Haptic feedback warnings in simulator console are normal and can be ignored.
// They only occur in the iOS Simulator and don't affect functionality.
class DatabaseManager {
    static let shared = DatabaseManager()
    private var db: OpaquePointer?
    private(set) var currentUserId: String = ""
    private(set) var currentSessionId: Int = 0
    
    // SQLite text destructor constant
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
        
        // Check if we need to reset the database
        let versionFile = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("db_version.txt")
        
        let currentVersion = "2.0"
        var needsReset = false
        
        if FileManager.default.fileExists(atPath: versionFile.path) {
            if let savedVersion = try? String(contentsOf: versionFile, encoding: .utf8) {
                if savedVersion != currentVersion {
                    needsReset = true
                    print("🔄 Database version mismatch. Old: \(savedVersion), New: \(currentVersion)")
                }
            }
        } else if FileManager.default.fileExists(atPath: fileURL.path) {
            // Database exists but no version file = old schema
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
        
        // Save current version
        try? currentVersion.write(to: versionFile, atomically: true, encoding: .utf8)
        print("✅ Database version: \(currentVersion)")
    }
    
    private func createTables() {
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
            last_session_id INTEGER DEFAULT 0
        );
        """
        
        let createTasksTable = """
        CREATE TABLE IF NOT EXISTS tasks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT,
            session_id INTEGER,
            task_id TEXT,
            task_title TEXT,
            points_earned INTEGER,
            completed_at TEXT
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
        
        executeSQL(createUsersTable)
        executeSQL(createTasksTable)
        executeSQL(createPulseSurveysTable)
        executeSQL(createRewardRedemptionsTable)
        executeSQL(createEventsTable)
    }
    
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
                        // Empty user ID found, create a new one
                        currentUserId = UUID().uuidString
                        print("🆕 Empty user ID found, created new: \(currentUserId)")
                        // Update the database with the new user ID
                        let updateSql = "UPDATE users SET user_id = ? WHERE user_id = '';"
                        var updateStatement: OpaquePointer?
                        if sqlite3_prepare_v2(db, updateSql, -1, &updateStatement, nil) == SQLITE_OK {
                            sqlite3_bind_text(updateStatement, 1, currentUserId, -1, SQLITE_TRANSIENT)
                            sqlite3_step(updateStatement)
                        }
                        sqlite3_finalize(updateStatement)
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
        
        // Update the session ID in the database
        let updateSql = "UPDATE users SET last_session_id = ? WHERE user_id = ?;"
        var updateStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, updateSql, -1, &updateStatement, nil) == SQLITE_OK {
            sqlite3_bind_int(updateStatement, 1, Int32(currentSessionId))
            sqlite3_bind_text(updateStatement, 2, currentUserId, -1, SQLITE_TRANSIENT)
            
            if sqlite3_step(updateStatement) == SQLITE_DONE {
                print("📊 Session ID: \(currentSessionId)")
            } else {
                print("⚠️ Failed to update session ID")
                print("📊 Session ID: \(currentSessionId) (not persisted)")
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
    
    func saveUser(_ user: User) {
        let goalsString = user.goals.joined(separator: ",")
        let dateString = ISO8601DateFormatter().string(from: Date())
        
        let sql = """
        INSERT OR REPLACE INTO users 
        (user_id, race, income_level, housing_situation, goals, points_balance, current_streak, has_completed_onboarding, created_at, last_session_id)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, currentUserId, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 2, user.race, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 3, user.incomeLevel, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 4, user.housingSituation, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 5, goalsString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(statement, 6, Int32(user.pointsBalance))
            sqlite3_bind_int(statement, 7, Int32(user.currentStreak))
            sqlite3_bind_int(statement, 8, user.hasCompletedOnboarding ? 1 : 0)
            sqlite3_bind_text(statement, 9, dateString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(statement, 10, Int32(currentSessionId))
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("User saved successfully")
                logEvent(screen: "Onboarding", action: "user_profile_saved")
            }
        }
        
        sqlite3_finalize(statement)
    }
    
    func updateUser(_ user: User) {
        let goalsString = user.goals.joined(separator: ",")
        
        let sql = """
        UPDATE users SET 
        race = ?, income_level = ?, housing_situation = ?, goals = ?, 
        points_balance = ?, current_streak = ?, has_completed_onboarding = ?
        WHERE user_id = ?;
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, user.race, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 2, user.incomeLevel, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 3, user.housingSituation, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 4, goalsString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(statement, 5, Int32(user.pointsBalance))
            sqlite3_bind_int(statement, 6, Int32(user.currentStreak))
            sqlite3_bind_int(statement, 7, user.hasCompletedOnboarding ? 1 : 0)
            sqlite3_bind_text(statement, 8, currentUserId, -1, SQLITE_TRANSIENT)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("User updated successfully")
            }
        }
        
        sqlite3_finalize(statement)
    }
    
    func loadUser() -> User? {
        let sql = "SELECT * FROM users WHERE user_id = ?;"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, currentUserId, -1, SQLITE_TRANSIENT)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                let race = String(cString: sqlite3_column_text(statement, 1))
                let incomeLevel = String(cString: sqlite3_column_text(statement, 2))
                let housingSituation = String(cString: sqlite3_column_text(statement, 3))
                let goalsString = String(cString: sqlite3_column_text(statement, 4))
                let pointsBalance = Int(sqlite3_column_int(statement, 5))
                let currentStreak = Int(sqlite3_column_int(statement, 6))
                let hasCompletedOnboarding = sqlite3_column_int(statement, 7) == 1
                
                let goals = goalsString.isEmpty ? [] : goalsString.split(separator: ",").map(String.init)
                
                sqlite3_finalize(statement)
                
                return User(
                    id: UUID(uuidString: currentUserId) ?? UUID(),
                    race: race,
                    incomeLevel: incomeLevel,
                    housingSituation: housingSituation,
                    goals: goals,
                    pointsBalance: pointsBalance,
                    currentStreak: currentStreak,
                    hasCompletedOnboarding: hasCompletedOnboarding
                )
            }
        }
        
        sqlite3_finalize(statement)
        return nil
    }
    
    func saveTaskCompletion(taskId: String, taskTitle: String, pointsEarned: Int) {
        let dateString = ISO8601DateFormatter().string(from: Date())
        
        let sql = """
        INSERT INTO tasks 
        (user_id, session_id, task_id, task_title, points_earned, completed_at)
        VALUES (?, ?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, currentUserId, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(statement, 2, Int32(currentSessionId))
            sqlite3_bind_text(statement, 3, taskId, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 4, taskTitle, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(statement, 5, Int32(pointsEarned))
            sqlite3_bind_text(statement, 6, dateString, -1, SQLITE_TRANSIENT)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("✅ Task completion saved: \(taskTitle)")
                logEvent(screen: "Tasks", action: "task_completed", detail: taskTitle)
            }
        }
        
        sqlite3_finalize(statement)
    }
    
    func loadCompletedTasks() -> Set<String> {
        let sql = "SELECT DISTINCT task_id FROM tasks WHERE user_id = ?;"
        var statement: OpaquePointer?
        var completedTaskIds = Set<String>()
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, currentUserId, -1, SQLITE_TRANSIENT)
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let taskId = String(cString: sqlite3_column_text(statement, 0))
                completedTaskIds.insert(taskId)
            }
        }
        
        sqlite3_finalize(statement)
        return completedTaskIds
    }
    
    func savePulseSurvey(weekRating: Int, weekFeelings: String,
                        programRating: Int, programFeelings: String) {
        let dateString = ISO8601DateFormatter().string(from: Date())
        
        let sql = """
        INSERT INTO pulse_surveys 
        (user_id, session_id, week_rating, week_feelings, program_rating, program_feelings, submitted_at)
        VALUES (?, ?, ?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, currentUserId, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(statement, 2, Int32(currentSessionId))
            sqlite3_bind_int(statement, 3, Int32(weekRating))
            sqlite3_bind_text(statement, 4, weekFeelings, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(statement, 5, Int32(programRating))
            sqlite3_bind_text(statement, 6, programFeelings, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 7, dateString, -1, SQLITE_TRANSIENT)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("✅ Pulse survey saved")
                logEvent(screen: "Pulse Survey", action: "survey_submitted", detail: "Week: \(weekRating), Program: \(programRating)")
            }
        }
        
        sqlite3_finalize(statement)
    }
    
    func loadPulseSurveys() -> [(weekRating: Int, programRating: Int, date: Date)] {
        let sql = "SELECT week_rating, program_rating, submitted_at FROM pulse_surveys WHERE user_id = ? ORDER BY submitted_at DESC;"
        var statement: OpaquePointer?
        var surveys: [(Int, Int, Date)] = []
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, currentUserId, -1, SQLITE_TRANSIENT)
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let weekRating = Int(sqlite3_column_int(statement, 0))
                let programRating = Int(sqlite3_column_int(statement, 1))
                let dateString = String(cString: sqlite3_column_text(statement, 2))
                
                if let date = ISO8601DateFormatter().date(from: dateString) {
                    surveys.append((weekRating, programRating, date))
                }
            }
        }
        
        sqlite3_finalize(statement)
        return surveys
    }
    
    func saveRewardRedemption(rewardTitle: String, pointsCost: Int) {
        let dateString = ISO8601DateFormatter().string(from: Date())
        
        let sql = """
        INSERT INTO reward_redemptions 
        (user_id, session_id, reward_title, points_cost, redeemed_at)
        VALUES (?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, currentUserId, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(statement, 2, Int32(currentSessionId))
            sqlite3_bind_text(statement, 3, rewardTitle, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(statement, 4, Int32(pointsCost))
            sqlite3_bind_text(statement, 5, dateString, -1, SQLITE_TRANSIENT)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("✅ Reward redemption saved")
                logEvent(screen: "Rewards", action: "reward_redeemed", detail: rewardTitle)
            }
        }
        
        sqlite3_finalize(statement)
    }
    
    func loadRewardRedemptions() -> [(title: String, points: Int, date: Date)] {
        let sql = "SELECT reward_title, points_cost, redeemed_at FROM reward_redemptions WHERE user_id = ? ORDER BY redeemed_at DESC;"
        var statement: OpaquePointer?
        var redemptions: [(String, Int, Date)] = []
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, currentUserId, -1, nil)
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let title = String(cString: sqlite3_column_text(statement, 0))
                let points = Int(sqlite3_column_int(statement, 1))
                let dateString = String(cString: sqlite3_column_text(statement, 2))
                
                if let date = ISO8601DateFormatter().date(from: dateString) {
                    redemptions.append((title, points, date))
                }
            }
        }
        
        sqlite3_finalize(statement)
        return redemptions
    }
    
    deinit {
        sqlite3_close(db)
    }
    
    // MARK: - Debug Helpers
    func exportDatabaseToDesktop() {
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("workforce_dev.sqlite")
        
        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let destinationURL = desktopURL.appendingPathComponent("workforce_dev_export.sqlite")
        
        do {
            // Remove existing export if it exists
            try? FileManager.default.removeItem(at: destinationURL)
            // Copy database to desktop
            try FileManager.default.copyItem(at: fileURL, to: destinationURL)
            print("✅ Database exported to: \(destinationURL.path)")
            print("💾 Open this file with DB Browser for SQLite to view data")
        } catch {
            print("❌ Export failed: \(error)")
        }
    }
    
    func printDatabasePath() {
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("workforce_dev.sqlite")
        print("📂 Full database path:")
        print(fileURL.path)
    }
}

// MARK: - Models
// Note: OllamaService is defined in a separate file and imported
struct User {
    var id = UUID()
    var race: String = ""
    var incomeLevel: String = ""
    var housingSituation: String = ""
    var goals: [String] = []
    var pointsBalance: Int = 0
    var currentStreak: Int = 0
    var hasCompletedOnboarding: Bool = false
}

struct UserTask {
    let id = UUID()
    let title: String
    let description: String
    let points: Int
    let category: TaskCategory
    var isCompleted: Bool = false
}

enum TaskCategory {
    case pulseSurvey
    case personalDevelopment
    case learningMaterials
}

struct Reward {
    let id = UUID()
    let title: String
    let description: String
    let pointCost: Int
    let type: RewardType
    let discount: Double?
    let discountDaysLeft: Int?
}

enum RewardType {
    case cash
    case giftCard
}

// MARK: - View Models
class AppViewModel: ObservableObject {
    @Published var user = User()
    @Published var showOnboarding = true
    @Published var tasks: [UserTask] = [
        UserTask(title: "Weekly Pulse Survey", description: "Rate your week and share feedback", points: 500, category: .pulseSurvey),
        UserTask(title: "Custom Learning Plan", description: "Complete your personalized learning path", points: 250, category: .personalDevelopment),
        UserTask(title: "HVAC Residential Systems", description: "Learn about residential HVAC systems", points: 250, category: .personalDevelopment),
        UserTask(title: "HVAC Industrial Systems", description: "Master industrial HVAC concepts", points: 250, category: .personalDevelopment),
        UserTask(title: "Building Operations Management", description: "Understand building operations", points: 250, category: .personalDevelopment),
        UserTask(title: "Test What You've Learned", description: "Take the comprehensive test", points: 1000, category: .learningMaterials)
    ]
    @Published var rewards: [Reward] = [
        Reward(title: "$5 Venmo Transfer", description: "Instant cash transfer", pointCost: 1500, type: .cash, discount: nil, discountDaysLeft: nil),
        Reward(title: "$25 Venmo Transfer", description: "Instant cash transfer", pointCost: 5000, type: .cash, discount: nil, discountDaysLeft: nil),
        Reward(title: "$100 Weekly Raffle", description: "Enter weekly cash raffle", pointCost: 10000, type: .cash, discount: nil, discountDaysLeft: nil),
        Reward(title: "$25 Amazon Gift Card", description: "Amazon shopping credit", pointCost: 4000, type: .giftCard, discount: 0.10, discountDaysLeft: 3),
        Reward(title: "$5 Target Gift Card", description: "Target shopping credit", pointCost: 1000, type: .giftCard, discount: 0.10, discountDaysLeft: 3)
    ]
    
    private let db = DatabaseManager.shared
    
    init() {
        loadUserData()
    }
    
    private func loadUserData() {
        if let savedUser = db.loadUser() {
            user = savedUser
            showOnboarding = !savedUser.hasCompletedOnboarding
            
            let completedTaskIds = db.loadCompletedTasks()
            for i in 0..<tasks.count {
                if completedTaskIds.contains(tasks[i].id.uuidString) {
                    tasks[i].isCompleted = true
                }
            }
        }
    }
    
    func completeOnboarding(race: String, income: String, housing: String, goals: [String]) {
        user.race = race
        user.incomeLevel = income
        user.housingSituation = housing
        user.goals = goals
        user.hasCompletedOnboarding = true
        user.pointsBalance = 750
        user.currentStreak = 1
        showOnboarding = false
        
        db.saveUser(user)
        db.logEvent(screen: "Onboarding", action: "onboarding_completed", detail: "Goals: \(goals.joined(separator: ", "))")
    }
    
    func completeTask(_ task: UserTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].isCompleted = true
            user.pointsBalance += task.points
            
            db.saveTaskCompletion(
                taskId: task.id.uuidString,
                taskTitle: task.title,
                pointsEarned: task.points
            )
            db.updateUser(user)
        }
    }
    
    func submitPulseSurvey(weekRating: Int, weekFeelings: String,
                          programRating: Int, programFeelings: String) {
        user.pointsBalance += 500
        
        db.savePulseSurvey(
            weekRating: weekRating,
            weekFeelings: weekFeelings,
            programRating: programRating,
            programFeelings: programFeelings
        )
        
        // Also log as a task completion
        db.saveTaskCompletion(
            taskId: "pulse_survey_\(Date().timeIntervalSince1970)",
            taskTitle: "Weekly Pulse Survey",
            pointsEarned: 500
        )
        
        db.updateUser(user)
    }
    
    func redeemReward(_ reward: Reward) {
        let cost = Int(Double(reward.pointCost) * (1.0 - (reward.discount ?? 0.0)))
        if user.pointsBalance >= cost {
            user.pointsBalance -= cost
            
            db.saveRewardRedemption(
                rewardTitle: reward.title,
                pointsCost: cost
            )
            db.updateUser(user)
        }
    }
    
    func getPulseSurveyHistory() -> [(weekRating: Int, programRating: Int, date: Date)] {
        return db.loadPulseSurveys()
    }
    
    func getRewardHistory() -> [(title: String, points: Int, date: Date)] {
        return db.loadRewardRedemptions()
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.2, blue: 0.45), Color(red: 0.2, green: 0.1, blue: 0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if viewModel.showOnboarding {
                OnboardingFlow(viewModel: viewModel)
            } else {
                MainTabView(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Onboarding Flow
struct OnboardingFlow: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var currentStep = 0
    @State private var selectedRace = ""
    @State private var selectedIncome = ""
    @State private var selectedHousing = ""
    @State private var selectedGoals: Set<String> = []
    
    let races = ["White", "Black or African American", "Hispanic or Latino", "Asian", "Native American", "Pacific Islander", "Other", "Prefer not to answer"]
    let incomeOptions = ["Under $25,000", "$25,000-$50,000", "$50,000-$75,000", "$75,000-$100,000", "Over $100,000", "Prefer not to answer"]
    let housingOptions = ["Own my home", "Rent", "Living with family/friends", "Temporary housing", "Other"]
    let goalOptions = ["Personal Development", "Career Growth", "Financial Stability", "Access to Resources", "Mental Health", "Physical Wellness"]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dark blue gradient background matching the rest of the app
                LinearGradient(
                    colors: [Color(red: 0.1, green: 0.2, blue: 0.45), Color(red: 0.2, green: 0.1, blue: 0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        // Updated progress view with glass styling
                        VStack(spacing: 12) {
                            HStack {
                                Text("Step \(currentStep + 1) of 4")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                Spacer()
                                Text("\(Int((Double(currentStep + 1) / 4.0) * 100))%")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                            }
                            
                            ProgressView(value: Double(currentStep + 1), total: 4.0)
                                .tint(.blue)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(8)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .padding(.horizontal)
                    
                    switch currentStep {
                    case 0:
                        glassSelectionView(
                            title: "What is your race?",
                            options: races,
                            selection: $selectedRace
                        )
                    case 1:
                        glassSelectionView(
                            title: "What is your income level?",
                            options: incomeOptions,
                            selection: $selectedIncome
                        )
                    case 2:
                        glassSelectionView(
                            title: "What is your current housing situation?",
                            options: housingOptions,
                            selection: $selectedHousing
                        )
                    case 3:
                        glassMultiSelectionView(
                            title: "What are your goals for participating in the program?",
                            subtitle: "Select all that apply",
                            options: goalOptions,
                            selections: $selectedGoals
                        )
                    default:
                        EmptyView()
                    }
                    
                    // Updated navigation buttons with glass styling
                    HStack(spacing: 15) {
                        if currentStep > 0 {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    currentStep -= 1
                                }
                            }) {
                                HStack {
                                    Image(systemName: "chevron.left")
                                        .font(.caption)
                                    Text("Previous")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(.ultraThinMaterial)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                            }
                        }
                        
                        Button(action: {
                            if currentStep == 3 {
                                viewModel.completeOnboarding(
                                    race: selectedRace,
                                    income: selectedIncome,
                                    housing: selectedHousing,
                                    goals: Array(selectedGoals)
                                )
                            } else {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    currentStep += 1
                                }
                            }
                        }) {
                            HStack {
                                Text(currentStep == 3 ? "Complete" : "Next")
                                if currentStep < 3 {
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                }
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                canProceed ?
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ) :
                                LinearGradient(
                                    colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.2)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(canProceed ? Color.blue.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
                            )
                            .shadow(color: canProceed ? .blue.opacity(0.3) : .clear, radius: 8)
                        }
                        .disabled(!canProceed)
                        .scaleEffect(canProceed ? 1.0 : 0.98)
                        .animation(.easeInOut(duration: 0.2), value: canProceed)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .padding(.vertical)
            }
            .navigationTitle("Welcome!")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear {
                DatabaseManager.shared.logEvent(screen: "Onboarding", action: "view_appeared", detail: "Step \(currentStep + 1)")
            }
        }
    }
    }
    
    var canProceed: Bool {
        switch currentStep {
        case 0: return !selectedRace.isEmpty
        case 1: return !selectedIncome.isEmpty
        case 2: return !selectedHousing.isEmpty
        case 3: return !selectedGoals.isEmpty
        default: return false
        }
    }
    
    // Updated single selection view with glass styling
    func glassSelectionView(title: String, options: [String], selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            ForEach(options, id: \.self) { option in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selection.wrappedValue = option
                    }
                }) {
                    HStack(spacing: 15) {
                        Image(systemName: selection.wrappedValue == option ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selection.wrappedValue == option ? .blue : .white.opacity(0.6))
                            .font(.title3)
                            .animation(.easeInOut(duration: 0.2), value: selection.wrappedValue == option)
                        
                        Text(option)
                            .foregroundColor(.white)
                            .font(.body)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                selection.wrappedValue == option ?
                                LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing) :
                                LinearGradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.1)], startPoint: .leading, endPoint: .trailing),
                                lineWidth: selection.wrappedValue == option ? 2 : 1
                            )
                    )
                    .shadow(color: selection.wrappedValue == option ? .blue.opacity(0.2) : .clear, radius: 4)
                    .scaleEffect(selection.wrappedValue == option ? 1.02 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: selection.wrappedValue == option)
                }
                .padding(.horizontal)
            }
        }
    }
    
    // Updated multi-selection view with glass styling
    func glassMultiSelectionView(title: String, subtitle: String, options: [String], selections: Binding<Set<String>>) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal)
            
            ForEach(options, id: \.self) { option in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if selections.wrappedValue.contains(option) {
                            selections.wrappedValue.remove(option)
                        } else {
                            selections.wrappedValue.insert(option)
                        }
                    }
                }) {
                    HStack(spacing: 15) {
                        Image(systemName: selections.wrappedValue.contains(option) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selections.wrappedValue.contains(option) ? .blue : .white.opacity(0.6))
                            .font(.title3)
                            .animation(.easeInOut(duration: 0.2), value: selections.wrappedValue.contains(option))
                        
                        Text(option)
                            .foregroundColor(.white)
                            .font(.body)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                        
                        // Add a small indicator for selected items
                        if selections.wrappedValue.contains(option) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                                .scaleEffect(0.8)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                selections.wrappedValue.contains(option) ?
                                LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing) :
                                LinearGradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.1)], startPoint: .leading, endPoint: .trailing),
                                lineWidth: selections.wrappedValue.contains(option) ? 2 : 1
                            )
                    )
                    .shadow(color: selections.wrappedValue.contains(option) ? .blue.opacity(0.2) : .clear, radius: 4)
                    .scaleEffect(selections.wrappedValue.contains(option) ? 1.02 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: selections.wrappedValue.contains(option))
                }
                .padding(.horizontal)
            }
            
            // Selection counter
            if !selections.wrappedValue.isEmpty {
                HStack {
                    Spacer()
                    Text("\(selections.wrappedValue.count) selected")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(12)
                    Spacer()
                }
                .padding(.horizontal)
                .transition(.opacity.combined(with: .scale))
            }
        }
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(viewModel: viewModel, selectedTab: $selectedTab)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            TasksView(viewModel: viewModel)
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
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
        }
        .tint(.white)
    }
}

// MARK: - Home View
struct HomeView: View {
    @ObservedObject var viewModel: AppViewModel
    @Binding var selectedTab: Int
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.1, green: 0.2, blue: 0.45), Color(red: 0.2, green: 0.1, blue: 0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 15) {
                            GlassDashboardCard(
                                title: "Points",
                                value: "\(viewModel.user.pointsBalance)",
                                icon: "star.fill",
                                color: .yellow
                            ) {
                                selectedTab = 2 // Open Rewards tab
                            }
                            
                            GlassDashboardCard(
                                title: "Tasks",
                                value: "\(viewModel.tasks.filter { !$0.isCompleted }.count)",
                                icon: "checklist",
                                color: .blue
                            ) {
                                selectedTab = 1 // Open Tasks tab
                            }
                            
                            GlassDashboardCard(
                                title: "Streak",
                                value: "\(viewModel.user.currentStreak)",
                                icon: "flame.fill",
                                color: .orange
                            ) {
                                selectedTab = 4 // Open Profile tab
                            }
                        }
                        .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 15) {
                            Text("My Day")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            GlassSuggestedTaskCard(
                                title: "Complete Weekly Pulse Survey",
                                description: "Share how your week is going",
                                points: 500,
                                icon: "chart.line.uptrend.xyaxis"
                            ) {
                                DatabaseManager.shared.logEvent(screen: "Home", action: "button_tap", detail: "Pulse Survey Card")
                                selectedTab = 1 // Open Tasks tab
                            }
                            
                            GlassSuggestedTaskCard(
                                title: "HVAC Learning Module",
                                description: "Continue your learning journey",
                                points: 250,
                                icon: "book.fill"
                            ) {
                                DatabaseManager.shared.logEvent(screen: "Home", action: "button_tap", detail: "HVAC Learning Card")
                                selectedTab = 1 // Open Tasks tab
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear {
                DatabaseManager.shared.logEvent(screen: "Home", action: "view_appeared")
            }
        }
        .accentColor(.white) // Makes "Home" title white
    }
}

// MARK: - HVAC Learning View
struct HVACLearningView: View {
    let taskTitle: String
    let taskDescription: String
    let points: Int
    @ObservedObject var viewModel: AppViewModel
    @Binding var isPresented: Bool

    @StateObject private var ollamaService = OllamaService.shared
    @State private var generatedContent = ""
    @State private var showError = false
    @State private var hasGeneratedContent = false
    @State private var quizQuestion: OllamaService.QuizQuestion?
    @State private var selectedAnswer: Int?
    @State private var showQuizResult = false
    @State private var isLoadingQuiz = false
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.1, green: 0.2, blue: 0.45), Color(red: 0.2, green: 0.1, blue: 0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        // Header Card
                        VStack(spacing: 15) {
                            HStack {
                                Image(systemName: "gear.badge")
                                    .font(.title)
                                    .foregroundColor(.blue)
                                
                                VStack(alignment: .leading) {
                                    Text(taskTitle)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text(taskDescription)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                
                                Spacer()
                                
                                VStack {
                                    Text("+\(points)")
                                        .font(.headline)
                                        .foregroundColor(.yellow)
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                }
                            }
                            
                            if !hasGeneratedContent {
                                Button(action: generateContent) {
                                    HStack {
                                        if ollamaService.isGenerating {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                                .tint(.white)
                                        } else {
                                            Image(systemName: "wand.and.rays")
                                        }
                                        Text(ollamaService.isGenerating ? "Generating Content..." : "Generate Learning Content")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        LinearGradient(
                                            colors: ollamaService.isGenerating ? [.gray, .gray.opacity(0.8)] : [.blue, .purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(16)
                                    .shadow(color: .blue.opacity(0.3), radius: 8)
                                }
                                .disabled(ollamaService.isGenerating)
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        
                        // Generated Content
                        if !generatedContent.isEmpty {
                            VStack(alignment: .leading, spacing: 15) {
                                HStack {
                                    Image(systemName: "book.fill")
                                        .foregroundColor(.green)
                                    Text("Learning Content")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    Spacer()
                                }

                                Text(generatedContent)
                                    .font(.body)
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineSpacing(4)
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        }

                        // Quiz Section
                        if hasGeneratedContent && !generatedContent.isEmpty {
                            VStack(alignment: .leading, spacing: 15) {
                                HStack {
                                    Image(systemName: "questionmark.circle.fill")
                                        .foregroundColor(.purple)
                                    Text("Knowledge Check")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    Spacer()
                                }

                                if let quiz = quizQuestion {
                                    // Question
                                    Text(quiz.question)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding(.bottom, 8)

                                    // Answer Options
                                    ForEach(0..<quiz.options.count, id: \.self) { index in
                                        Button(action: {
                                            if selectedAnswer == nil {
                                                selectedAnswer = index
                                                showQuizResult = true
                                            }
                                        }) {
                                            HStack {
                                                Text(quiz.options[index])
                                                    .font(.body)
                                                    .foregroundColor(.white)
                                                    .multilineTextAlignment(.leading)

                                                Spacer()

                                                if showQuizResult {
                                                    if index == quiz.correctAnswer {
                                                        Image(systemName: "checkmark.circle.fill")
                                                            .foregroundColor(.green)
                                                    } else if index == selectedAnswer {
                                                        Image(systemName: "xmark.circle.fill")
                                                            .foregroundColor(.red)
                                                    }
                                                }
                                            }
                                            .padding()
                                            .background(
                                                showQuizResult && index == quiz.correctAnswer ?
                                                    Color.green.opacity(0.2) :
                                                    showQuizResult && index == selectedAnswer ?
                                                    Color.red.opacity(0.2) :
                                                    Color.white.opacity(0.1)
                                            )
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(
                                                        showQuizResult && index == quiz.correctAnswer ?
                                                            Color.green :
                                                            showQuizResult && index == selectedAnswer ?
                                                            Color.red :
                                                            Color.white.opacity(0.3),
                                                        lineWidth: showQuizResult && (index == quiz.correctAnswer || index == selectedAnswer) ? 2 : 1
                                                    )
                                            )
                                        }
                                        .disabled(selectedAnswer != nil)
                                    }

                                    // Explanation
                                    if showQuizResult {
                                        VStack(alignment: .leading, spacing: 8) {
                                            if selectedAnswer == quiz.correctAnswer {
                                                HStack {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundColor(.green)
                                                    Text("Correct!")
                                                        .font(.headline)
                                                        .foregroundColor(.green)
                                                }
                                            } else {
                                                HStack {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .foregroundColor(.red)
                                                    Text("Not quite right")
                                                        .font(.headline)
                                                        .foregroundColor(.red)
                                                }
                                            }

                                            Text(quiz.explanation)
                                                .font(.subheadline)
                                                .foregroundColor(.white.opacity(0.9))
                                        }
                                        .padding()
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(12)

                                        Button(action: completeTask) {
                                            HStack {
                                                Image(systemName: "checkmark.circle.fill")
                                                Text("Complete Task (+\(points) points)")
                                            }
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(
                                                LinearGradient(
                                                    colors: [.green, .green.opacity(0.8)],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .cornerRadius(16)
                                            .shadow(color: .green.opacity(0.3), radius: 8)
                                        }
                                    }
                                } else if isLoadingQuiz {
                                    HStack {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .tint(.white)
                                        Text("Generating quiz question...")
                                            .font(.body)
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                } else {
                                    Button(action: generateQuiz) {
                                        HStack {
                                            Image(systemName: "play.circle.fill")
                                            Text("Start Quiz")
                                        }
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(
                                            LinearGradient(
                                                colors: [.purple, .blue],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .cornerRadius(16)
                                        .shadow(color: .purple.opacity(0.3), radius: 8)
                                    }
                                }
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        }
                        
                        // Error Display
                        if let error = ollamaService.lastError {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading) {
                                    Text("Connection Issue")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                Spacer()
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("HVAC Learning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        DatabaseManager.shared.logEvent(screen: "HVAC Learning", action: "closed", detail: taskTitle)
                        isPresented = false
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if hasGeneratedContent {
                        Button("Complete Task") {
                            completeTask()
                        }
                        .foregroundColor(.green)
                    }
                }
            }
            .onAppear {
                DatabaseManager.shared.logEvent(screen: "HVAC Learning", action: "view_appeared", detail: taskTitle)
                
                Task {
                    do {
                        let content = try await ollamaService.generateHVACContent(
                            topic: taskTitle,
                            userGoals: viewModel.user.goals
                        )
                        
                        await MainActor.run {
                            generatedContent = content
                            hasGeneratedContent = true
                        }
                        
                    } catch {
                        print("Failed to generate content: \(error)")
                        await MainActor.run {
                            showError = true
                        }
                    }
                }
            }
        }
    }
    
    func generateContent() {
        Task {
            do {
                let content = try await ollamaService.generateHVACContent(
                    topic: taskTitle,
                    userGoals: viewModel.user.goals
                )
                
                await MainActor.run {
                    generatedContent = content
                    hasGeneratedContent = true
                }
                
            } catch {
                print("Failed to generate content: \(error)")
                await MainActor.run {
                    showError = true
                }
            }
        }
    }
    
    func generateQuiz() {
        Task {
            await MainActor.run {
                isLoadingQuiz = true
            }

            do {
                let quiz = try await ollamaService.generateQuizQuestion(content: generatedContent)

                await MainActor.run {
                    quizQuestion = quiz
                    isLoadingQuiz = false
                }

            } catch {
                print("Failed to generate quiz: \(error)")
                await MainActor.run {
                    isLoadingQuiz = false
                    showError = true
                }
            }
        }
    }

    func completeTask() {
        if let task = viewModel.tasks.first(where: { $0.title == taskTitle }) {
            viewModel.completeTask(task)
        }

        DatabaseManager.shared.logEvent(screen: "HVAC Learning", action: "task_completed", detail: taskTitle)
        isPresented = false
    }
}

// MARK: - Tasks View
struct TasksView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showPulseSurvey = false
    @State private var showHVACLearning = false
    @State private var selectedTask: UserTask?
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.1, green: 0.2, blue: 0.45), Color(red: 0.2, green: 0.1, blue: 0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        taskSection(title: "Pulse Survey", icon: "waveform.path.ecg") {
                            GlassTaskCard(
                                title: "Weekly Check-in",
                                description: "Rate your week and share feedback",
                                points: 500,
                                isCompleted: false
                            ) {
                                DatabaseManager.shared.logEvent(screen: "Tasks", action: "task_started", detail: "Pulse Survey")
                                showPulseSurvey = true
                            }
                        }
                        
                        taskSection(title: "Personal Development", icon: "person.fill.badge.plus") {
                            ForEach(viewModel.tasks.filter { $0.category == .personalDevelopment }, id: \.id) { task in
                                GlassTaskCard(
                                    title: task.title,
                                    description: task.description,
                                    points: task.points,
                                    isCompleted: task.isCompleted
                                ) {
                                    handleTaskTap(task)
                                }
                            }
                        }
                        
                        taskSection(title: "Learning Materials", icon: "book.closed.fill") {
                            ForEach(viewModel.tasks.filter { $0.category == .learningMaterials }, id: \.id) { task in
                                GlassTaskCard(
                                    title: task.title,
                                    description: task.description,
                                    points: task.points,
                                    isCompleted: task.isCompleted
                                ) {
                                    handleTaskTap(task)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Tasks")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showPulseSurvey) {
                PulseSurveyView(viewModel: viewModel, isPresented: $showPulseSurvey)
            }
            .sheet(isPresented: $showHVACLearning) {
                if let task = selectedTask {
                    HVACLearningView(
                        taskTitle: task.title,
                        taskDescription: task.description,
                        points: task.points,
                        viewModel: viewModel,
                        isPresented: $showHVACLearning
                    )
                }
            }
            .onAppear {
                DatabaseManager.shared.logEvent(screen: "Tasks", action: "view_appeared")
            }
        }
    }
    
    func handleTaskTap(_ task: UserTask) {
        DatabaseManager.shared.logEvent(screen: "Tasks", action: "task_started", detail: task.title)
        
        // Check if it's an HVAC or Building Operations related task
        let hvacKeywords = ["hvac", "heating", "cooling", "building operations", "residential systems", "industrial systems"]
        let isHVACTask = hvacKeywords.contains { keyword in
            task.title.lowercased().contains(keyword) || task.description.lowercased().contains(keyword)
        }
        
        if isHVACTask {
            // Show HVAC learning view with AI-generated content
            selectedTask = task
            showHVACLearning = true
        } else {
            // Handle other tasks normally (complete immediately)
            viewModel.completeTask(task)
        }
    }
    
    func taskSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.white.opacity(0.9))
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            content()
        }
    }
}

// MARK: - Pulse Survey View
struct PulseSurveyView: View {
    @ObservedObject var viewModel: AppViewModel
    @Binding var isPresented: Bool
    @State private var weekRating: Double = 5
    @State private var weekFeelings: String = ""
    @State private var programRating: Double = 5
    @State private var programFeelings: String = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.1, green: 0.2, blue: 0.45), Color(red: 0.2, green: 0.1, blue: 0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        surveyQuestion(
                            question: "On a scale of 1-10, how do you feel this week is going?",
                            rating: $weekRating
                        )
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("What words would you use to describe how you're feeling right now?")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            TextEditor(text: $weekFeelings)
                                .frame(height: 100)
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        
                        surveyQuestion(
                            question: "On a scale of 1-10, how well do you feel like the program has helped this week?",
                            rating: $programRating
                        )
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("What words would you use to describe how you're feeling about the program right now?")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            TextEditor(text: $programFeelings)
                                .frame(height: 100)
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        
                        Button(action: {
                            viewModel.submitPulseSurvey(
                                weekRating: Int(weekRating),
                                weekFeelings: weekFeelings,
                                programRating: Int(programRating),
                                programFeelings: programFeelings
                            )
                            isPresented = false
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Submit Survey (+500 points)")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: .blue.opacity(0.5), radius: 10)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Pulse Survey")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        DatabaseManager.shared.logEvent(screen: "Pulse Survey", action: "button_tap", detail: "Cancel")
                        isPresented = false
                    }
                    .foregroundColor(.white)
                }
            }
            .onAppear {
                DatabaseManager.shared.logEvent(screen: "Pulse Survey", action: "view_appeared")
            }
        }
    }
    
    func surveyQuestion(question: String, rating: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(question)
                .font(.headline)
                .foregroundColor(.white)
            
            HStack {
                Text("1")
                    .foregroundColor(.white.opacity(0.7))
                Slider(value: rating, in: 1...10, step: 1)
                    .tint(.blue)
                Text("10")
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Text("Current rating: \(Int(rating.wrappedValue))")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Rewards View
struct RewardsView: View {
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.1, green: 0.2, blue: 0.45), Color(red: 0.2, green: 0.1, blue: 0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        VStack(spacing: 20) {
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Your Balance")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.7))
                                    Text("\(viewModel.user.pointsBalance)")
                                        .font(.system(size: 48, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("points")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                Spacer()
                                Image(systemName: "star.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.yellow)
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(24)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            
                            VStack(spacing: 10) {
                                ProgressView(value: Double(viewModel.user.pointsBalance % 1500), total: 1500.0)
                                    .tint(.blue)
                                
                                Text("\(1500 - (viewModel.user.pointsBalance % 1500)) points to next reward")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .padding()
                        
                        rewardSection(title: "Cash", icon: "dollarsign.circle.fill", color: .green) {
                            ForEach(viewModel.rewards.filter { $0.type == .cash }, id: \.id) { reward in
                                GlassRewardCard(reward: reward, userBalance: viewModel.user.pointsBalance) {
                                    viewModel.redeemReward(reward)
                                }
                            }
                        }
                        
                        rewardSection(title: "Gift Cards", icon: "giftcard.fill", color: .purple) {
                            ForEach(viewModel.rewards.filter { $0.type == .giftCard }, id: \.id) { reward in
                                GlassRewardCard(reward: reward, userBalance: viewModel.user.pointsBalance) {
                                    viewModel.redeemReward(reward)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Rewards")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear {
                DatabaseManager.shared.logEvent(screen: "Rewards", action: "view_appeared")
            }
        }
    }
    
    func rewardSection<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .padding(.horizontal)
            
            content()
        }
    }
}

// MARK: - Resources View
struct ResourcesView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showPlanner = false
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.1, green: 0.2, blue: 0.45), Color(red: 0.2, green: 0.1, blue: 0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        resourceSection(title: "Support", icon: "bubble.left.fill", color: .blue) {
                            GlassButton(
                                title: "Chat with AI Advisor",
                                icon: "message.fill",
                                url: "https://example.com/ai-advisor"
                            )
                            GlassButton(
                                title: "Schedule Meeting with Support Coach",
                                icon: "calendar",
                                url: "https://calendly.com/your-booking-link"
                            )
                        }

                        resourceSection(title: "Planner", icon: "calendar", color: .green) {
                            GlassButton(title: "Identify Daily Growth Time", icon: "clock.fill", action: {
                                showPlanner = true
                            })
                        }
                        
                        resourceSection(title: "Opportunities", icon: "briefcase.fill", color: .orange) {
                            GlassOpportunityCard(
                                title: "HVAC Technician",
                                company: "ABC Heating & Cooling",
                                location: "Chicago, IL",
                                applyUrl: "https://example.com/jobs/hvac-technician"
                            )

                            GlassOpportunityCard(
                                title: "Building Operations Assistant",
                                company: "Metro Property Management",
                                location: "Chicago, IL",
                                applyUrl: "https://example.com/jobs/building-ops"
                            )
                        }

                        resourceSection(title: "Benefits", icon: "gift.fill", color: .purple) {
                            GlassBenefitCard(
                                title: "Save 30% on household essentials",
                                description: "Use discount code at Target",
                                code: "SAVE30WD",
                                benefitUrl: "https://www.target.com"
                            )

                            GlassBenefitCard(
                                title: "Free CTA Bus Pass",
                                description: "Get free public transportation",
                                code: "Apply Now",
                                benefitUrl: "https://www.transitchicago.com/fares/ventra"
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Resources")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showPlanner) {
                PlannerView(isPresented: $showPlanner)
            }
            .onAppear {
                DatabaseManager.shared.logEvent(screen: "Resources", action: "view_appeared")
            }
        }
    }
    
    func resourceSection<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            content()
        }
    }
}

// MARK: - Profile View
struct ProfileView: View {
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.1, green: 0.2, blue: 0.45), Color(red: 0.2, green: 0.1, blue: 0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        VStack(spacing: 15) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 100))
                                .foregroundColor(.white.opacity(0.9))
                            
                            Text("Welcome back!")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("\(viewModel.user.pointsBalance) total points earned")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding()
                        
                        GlassProfileSection(title: "My Progress") {
                            ProgressRow(title: "Completed Tasks", value: "\(viewModel.tasks.filter { $0.isCompleted }.count)")
                            ProgressRow(title: "Current Streak", value: "\(viewModel.user.currentStreak) days")
                            ProgressRow(title: "Points Earned", value: "\(viewModel.user.pointsBalance)")
                        }
                        
                        GlassProfileSection(title: "My Goals") {
                            ForEach(viewModel.user.goals, id: \.self) { goal in
                                HStack {
                                    Image(systemName: "target")
                                        .foregroundColor(.blue)
                                    Text(goal)
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                            }
                        }
                        
                        GlassProfileSection(title: "Pulse Tracker") {
                            let surveys = viewModel.getPulseSurveyHistory().prefix(7)
                            if surveys.isEmpty {
                                Text("No pulse surveys completed yet")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding()
                            } else {
                                HStack(spacing: 12) {
                                    ForEach(Array(surveys.enumerated()), id: \.offset) { index, survey in
                                        VStack(spacing: 8) {
                                            Rectangle()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [.blue, .purple],
                                                        startPoint: .bottom,
                                                        endPoint: .top
                                                    )
                                                )
                                                .frame(width: 35, height: CGFloat(survey.weekRating * 10))
                                                .cornerRadius(8)
                                            Text("W\(index + 1)")
                                                .font(.caption2)
                                                .foregroundColor(.white.opacity(0.7))
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical)
                            }
                        }

                        NetworkSettingsSection()
                    }
                    .padding()
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear {
                DatabaseManager.shared.logEvent(screen: "Profile", action: "view_appeared")
            }
        }
    }
}

// MARK: - Planner View
struct PlannerView: View {
    @Binding var isPresented: Bool
    @State private var selectedTime = "1 hour"
    @State private var selectedGoals: Set<String> = []
    @State private var selectedActivities: Set<String> = []
    
    let timeOptions = ["30 mins", "1 hour", "2 hours", "4 hours"]
    let goalOptions = ["Learn something new", "Establish a routine", "Improve my mental health"]
    let activityOptions = [
        ("Learning/Studying", "30 mins"),
        ("Meditation", "30 mins"),
        ("Read/Write", "30 mins"),
        ("Chores/Errands", "60 mins"),
        ("Check in with life coach", "60 mins"),
        ("Make my appointments", "60 mins")
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.1, green: 0.2, blue: 0.45), Color(red: 0.2, green: 0.1, blue: 0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        plannerSection(title: "How much time do you have this week?") {
                            ForEach(timeOptions, id: \.self) { time in
                                Button(action: { selectedTime = time }) {
                                    HStack {
                                        Image(systemName: selectedTime == time ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedTime == time ? .blue : .white.opacity(0.6))
                                        Text(time)
                                            .foregroundColor(.white)
                                        Spacer()
                                    }
                                    .padding()
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(selectedTime == time ? Color.blue : Color.white.opacity(0.1), lineWidth: 1)
                                    )
                                }
                            }
                        }
                        
                        plannerSection(title: "Select your goals for the week") {
                            ForEach(goalOptions, id: \.self) { goal in
                                Button(action: {
                                    if selectedGoals.contains(goal) {
                                        selectedGoals.remove(goal)
                                    } else {
                                        selectedGoals.insert(goal)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: selectedGoals.contains(goal) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedGoals.contains(goal) ? .blue : .white.opacity(0.6))
                                        Text(goal)
                                            .foregroundColor(.white)
                                        Spacer()
                                    }
                                    .padding()
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(selectedGoals.contains(goal) ? Color.blue : Color.white.opacity(0.1), lineWidth: 1)
                                    )
                                }
                            }
                        }
                        
                        plannerSection(title: "Select activities") {
                            ForEach(activityOptions, id: \.0) { activity, duration in
                                Button(action: {
                                    if selectedActivities.contains(activity) {
                                        selectedActivities.remove(activity)
                                    } else {
                                        selectedActivities.insert(activity)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: selectedActivities.contains(activity) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedActivities.contains(activity) ? .blue : .white.opacity(0.6))
                                        VStack(alignment: .leading) {
                                            Text(activity)
                                                .foregroundColor(.white)
                                            Text(duration)
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.6))
                                        }
                                        Spacer()
                                    }
                                    .padding()
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(selectedActivities.contains(activity) ? Color.blue : Color.white.opacity(0.1), lineWidth: 1)
                                    )
                                }
                            }
                        }
                        
                        Button(action: { isPresented = false }) {
                            HStack {
                                Image(systemName: "calendar.badge.checkmark")
                                Text("Generate My Schedule")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: .blue.opacity(0.5), radius: 10)
                        }
                        .disabled(selectedGoals.isEmpty || selectedActivities.isEmpty)
                    }
                    .padding()
                }
            }
            .navigationTitle("Weekly Planner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        DatabaseManager.shared.logEvent(screen: "Planner", action: "button_tap", detail: "Cancel")
                        isPresented = false
                    }
                    .foregroundColor(.white)
                }
            }
            .onAppear {
                DatabaseManager.shared.logEvent(screen: "Planner", action: "view_appeared")
            }
        }
    }
    
    func plannerSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            content()
        }
    }
}

// MARK: - Glass Components

struct GlassDashboardCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct GlassSuggestedTaskCard: View {
    let title: String
    let description: String
    let points: Int
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 50, height: 50)
                    .background(Color.blue.opacity(0.2))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    Text("+\(points)")
                        .font(.headline)
                        .foregroundColor(.yellow)
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .padding(.horizontal)
    }
}

struct GlassTaskCard: View {
    let title: String
    let description: String
    let points: Int
    let isCompleted: Bool
    let action: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .strikethrough(isCompleted)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            } else {
                VStack(spacing: 8) {
                    Button(action: action) {
                        Text("Start")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                    }
                    
                    Text("+\(points)")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .opacity(isCompleted ? 0.6 : 1.0)
    }
}

struct GlassRewardCard: View {
    let reward: Reward
    let userBalance: Int
    let action: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(reward.title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(reward.description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                if let discount = reward.discount, let days = reward.discountDaysLeft {
                    Text("\(Int(discount * 100))% off - \(days) days left!")
                        .font(.caption)
                        .foregroundColor(.red)
                        .fontWeight(.semibold)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 8) {
                let cost = Int(Double(reward.pointCost) * (1.0 - (reward.discount ?? 0.0)))
                Text("\(cost) pts")
                    .font(.headline)
                    .foregroundColor(.white)
                if reward.discount != nil {
                    Text("\(reward.pointCost) pts")
                        .font(.caption)
                        .strikethrough()
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Button(action: action) {
                    Text("Redeem")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            userBalance >= cost ?
                            LinearGradient(colors: [.green, .green.opacity(0.8)], startPoint: .leading, endPoint: .trailing) :
                            LinearGradient(colors: [.gray, .gray.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(12)
                }
                .disabled(userBalance < cost)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

struct GlassButton: View {
    let title: String
    let icon: String
    var url: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: {
            DatabaseManager.shared.logEvent(screen: "Resources", action: "button_tap", detail: title)

            if let urlString = url, let url = URL(string: urlString) {
                // Open external link
                UIApplication.shared.open(url)
            } else if let action = action {
                // Execute custom action
                action()
            }
        }) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.white.opacity(0.9))
                Text(title)
                    .foregroundColor(.white)
                Spacer()

                if url != nil {
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.white.opacity(0.5))
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

struct GlassOpportunityCard: View {
    let title: String
    let company: String
    let location: String
    var applyUrl: String? = nil

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(company)
                    .font(.subheadline)
                    .foregroundColor(.blue)
                Text(location)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            Button(action: {
                if let urlString = applyUrl, let url = URL(string: urlString) {
                    DatabaseManager.shared.logEvent(screen: "Resources", action: "opportunity_apply", detail: title)
                    UIApplication.shared.open(url)
                }
            }) {
                HStack(spacing: 4) {
                    Text("Apply")
                        .font(.caption)
                        .fontWeight(.semibold)
                    if applyUrl != nil {
                        Image(systemName: "arrow.up.right")
                            .font(.caption2)
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: [.green, .green.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .disabled(applyUrl == nil)
            .opacity(applyUrl == nil ? 0.5 : 1.0)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

struct GlassBenefitCard: View {
    let title: String
    let description: String
    let code: String
    var benefitUrl: String? = nil

    var body: some View {
        Button(action: {
            if let urlString = benefitUrl, let url = URL(string: urlString) {
                DatabaseManager.shared.logEvent(screen: "Resources", action: "benefit_tap", detail: title)
                UIApplication.shared.open(url)
            }
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                HStack(spacing: 4) {
                    Text(code)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                    if benefitUrl != nil {
                        Image(systemName: "arrow.up.right")
                            .font(.caption2)
                            .foregroundColor(.purple)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.purple.opacity(0.2))
                .cornerRadius(8)
            }
        }
        .disabled(benefitUrl == nil)
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

struct GlassProfileSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(title)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

struct ProgressRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.white.opacity(0.9))
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
        }
    }
}

// MARK: - Network Settings Section
struct NetworkSettingsSection: View {
    @ObservedObject private var ollamaService = OllamaService.shared
    @State private var customIP: String = ""
    @State private var isEditing = false
    @State private var connectionStatus: ConnectionStatus = .unknown
    @State private var isCheckingConnection = false

    enum ConnectionStatus {
        case unknown, connected, disconnected
    }

    var body: some View {
        GlassProfileSection(title: "Network Settings") {
            VStack(alignment: .leading, spacing: 15) {
                // Connection Status
                HStack {
                    Image(systemName: connectionStatus == .connected ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(connectionStatus == .connected ? .green : .red)
                    Text("Ollama Status")
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                    Text(connectionStatus == .connected ? "Connected" : connectionStatus == .disconnected ? "Disconnected" : "Unknown")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }

                // Current URL Display
                VStack(alignment: .leading, spacing: 5) {
                    Text("Current URL")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text(ollamaService.getCurrentOllamaURL())
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }

                // Physical Device IP Configuration
                #if !targetEnvironment(simulator)
                Divider()
                    .background(Color.white.opacity(0.3))

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Mac IP Address (Physical Device)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)

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
                            TextField("e.g., 192.168.1.100", text: $customIP)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .keyboardType(.decimalPad)

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
                                    .foregroundColor(.white.opacity(0.7))
                            } else {
                                Text("Not configured - tap Edit to set")
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
                            Text("📍 How to find your Mac's IP address:")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.top, 5)

                            Text("1. Open Terminal on your Mac")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))

                            Text("2. Run: ipconfig getifaddr en0")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                                .fontWeight(.semibold)

                            Text("3. Enter the IP address shown above")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.top, 8)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
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
                    .background(Color.blue.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isCheckingConnection)
            }
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


    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.white.opacity(0.9))
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
        }
    }
}
 */ // End of commented WorkforceDevApp.swift file
