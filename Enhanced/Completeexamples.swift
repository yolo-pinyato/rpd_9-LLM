//
//  Example1.swift
//  rpd_9+LLM
//
//  Created by Chris on 11/19/25.
//


import SwiftUI

// MARK: - COMPLETE WORKING EXAMPLE
// This file demonstrates how all components work together

/*
 COMPLETE DATA FLOW EXAMPLE
 ==========================
 
 This example shows the complete journey from user interaction to database storage
 */

// EXAMPLE 1: User Selects HVAC Track
// ===================================

struct Example1_TrackSelection {
    /*
     1. User taps "Select Track" button on home screen
     2. TrackSelectionView appears
     3. User taps "HVAC Track" card
     4. System executes:
     */
    
    func selectHVACTrack() {
        // Save track selection to database
        DatabaseManagerEnhanced.shared.saveUserTrack(trackType: "hvac")
        // Result: Creates entry in user_tracks table with is_active=1
        //         Updates users table with selected_track='hvac'
        //         Logs event to events table
        
        // Load track content
        let viewModel = EnhancedAppViewModel()
        viewModel.loadTrackContent(trackType: "hvac")
        // Result: Queries track_content table for all hvac modules
        //         Creates UserTask objects for each module
        //         Updates trackTasks array in viewModel
        
        // UI updates automatically via @Published properties
        // Tasks tab now shows HVAC-specific learning modules
    }
}

// EXAMPLE 2: User Completes QR Check-In
// =====================================

struct Example2_QRCheckIn {
    /*
     1. User arrives at program location
     2. Opens app and taps "Check-In" button
     3. QRCodeScannerView opens camera
     4. User scans QR code
     5. System executes:
     */
    
    func handleQRScan(qrCode: String, viewModel: EnhancedAppViewModel) {
        // Calculate points based on admin settings
        let points = DatabaseManagerEnhanced.shared.calculateAutomatedPoints(
            taskType: "check_in"
        )
        
        /* 
         Point calculation flow:
         1. Gets admin setting for "auto_allocate_points"
         2. If true, calculates based on:
            - Total budget: $10,000
            - Program length: 12 weeks
            - Current week: 3
            - Weekly budget: $1,000
            - Budget used this week: $450
            - Points per dollar: 100
         3. Calculates: ($1000 - $450) * 100 = 55,000 points available
         4. Estimates remaining tasks: (50 users * 5 tasks) - 127 completed = 123 remaining
         5. Average per task: 55,000 / 123 = ~447 points
         6. Check-in base points: 50
         7. Final points: min(50, 447) = 50 points
         */
        
        // Save check-in to database
        DatabaseManagerEnhanced.shared.saveCheckIn(
            qrCodeData: qrCode,
            location: "Main Office",
            pointsEarned: points
        )
        // Result: Creates entry in check_ins table
        //         Logs event to events table
        
        // Save point allocation for tracking
        // (This happens inside calculateAutomatedPoints)
        // Result: Creates entry in point_allocations table
        //         Records: user_id, task_id, points, method='automated', week=3
        
        // Update user balance
        viewModel.user.pointsBalance += points
        // Result: Will be persisted when updateUser() is called
        
        // Show success message to user
        print("✅ Check-in successful! +\(points) points")
    }
}

// EXAMPLE 3: User Completes HVAC Learning Module
// ==============================================

struct Example3_LearningModule {
    /*
     1. User taps "Start" on "HVAC Basics" task
     2. TrackLearningView opens
     3. Ollama generates personalized content
     4. User reads content and takes quiz
     5. User taps "Complete Task"
     6. System executes:
     */
    
    func completeHVACBasics(task: UserTask, viewModel: EnhancedAppViewModel) {
        // Calculate points with difficulty considered
        let points = DatabaseManagerEnhanced.shared.calculateAutomatedPoints(
            taskType: "learning_module",
            difficulty: "beginner" // from task.difficultyLevel
        )
        
        /*
         Point calculation with difficulty:
         1. Base points for learning_module: 200
         2. Difficulty multiplier for beginner: 0.8
         3. Budget-adjusted cap: 447 (from previous example)
         4. Final calculation: min(200, 447) * 0.8 = 160 points
         */
        
        // Update user points
        viewModel.user.pointsBalance += points
        
        // Mark task as completed
        if let index = viewModel.trackTasks.firstIndex(where: { $0.id == task.id }) {
            viewModel.trackTasks[index].isCompleted = true
        }
        
        // This would be saved to database in production:
        // DatabaseManagerEnhanced.shared.saveTaskCompletion(...)
        // Result: Creates entry in tasks table
        //         Logs completion event
        //         Updates point_allocations
        
        print("✅ HVAC Basics completed! +\(points) points")
    }
}

// EXAMPLE 4: Admin Updates Budget Settings
// ========================================

struct Example4_AdminUpdate {
    /*
     1. Admin opens app
     2. Goes to Profile → Admin Dashboard
     3. Enters admin password
     4. Updates weekly budget from $1,000 to $800
     5. Enables auto-allocation
     6. Taps "Save Settings"
     7. System executes:
     */
    
    func updateAdminSettings() {
        let db = DatabaseManagerEnhanced.shared
        
        // Update individual settings
        db.updateAdminSetting(key: "max_budget_per_week", value: "800")
        // Result: Updates or inserts row in admin_settings table
        
        db.updateAdminSetting(key: "auto_allocate_points", value: "true")
        // Result: Updates or inserts row in admin_settings table
        
        /*
         Database changes:
         admin_settings table now has:
         ┌────────────────────────┬───────────────┬─────────────────────────┐
         │ setting_key            │ setting_value │ updated_at              │
         ├────────────────────────┼───────────────┼─────────────────────────┤
         │ max_budget_per_week    │ 800           │ 2025-01-16T15:30:00Z    │
         │ auto_allocate_points   │ true          │ 2025-01-16T15:30:00Z    │
         └────────────────────────┴───────────────┴─────────────────────────┘
         */
        
        // All future point allocations will now use new settings
        // Next task completion will use $800 weekly budget cap
        
        print("✅ Admin settings updated")
        print("📊 New weekly budget: $800")
        print("🤖 Auto-allocation: enabled")
    }
}

// EXAMPLE 5: Complete User Journey - Day 1
// ========================================

struct Example5_CompleteJourney {
    /*
     This example shows a complete day in the life of a user
     */
    
    func dayOneJourney() {
        let viewModel = EnhancedAppViewModel()
        let db = DatabaseManagerEnhanced.shared
        
        // 9:00 AM - User arrives and checks in
        print("\n=== 9:00 AM - Check-In ===")
        let checkInPoints = db.calculateAutomatedPoints(taskType: "check_in")
        db.saveCheckIn(qrCodeData: "QR_MAIN_OFFICE", location: "Main Office", pointsEarned: checkInPoints)
        viewModel.user.pointsBalance += checkInPoints
        print("Balance: \(viewModel.user.pointsBalance) points")
        
        // 10:00 AM - User selects HVAC track
        print("\n=== 10:00 AM - Track Selection ===")
        db.saveUserTrack(trackType: "hvac")
        viewModel.loadTrackContent(trackType: "hvac")
        print("Track: HVAC selected")
        print("Available tasks: \(viewModel.trackTasks.count)")
        
        // 11:00 AM - User completes HVAC Basics (beginner)
        print("\n=== 11:00 AM - HVAC Basics ===")
        let basicPoints = db.calculateAutomatedPoints(
            taskType: "learning_module",
            difficulty: "beginner"
        )
        viewModel.user.pointsBalance += basicPoints
        print("Balance: \(viewModel.user.pointsBalance) points")
        
        // 2:00 PM - User completes Residential HVAC (intermediate)
        print("\n=== 2:00 PM - Residential HVAC ===")
        let intermediatePoints = db.calculateAutomatedPoints(
            taskType: "learning_module",
            difficulty: "intermediate"
        )
        viewModel.user.pointsBalance += intermediatePoints
        print("Balance: \(viewModel.user.pointsBalance) points")
        
        // 4:00 PM - User completes Pulse Survey
        print("\n=== 4:00 PM - Pulse Survey ===")
        let surveyPoints = db.calculateAutomatedPoints(taskType: "pulse_survey")
        viewModel.user.pointsBalance += surveyPoints
        print("Balance: \(viewModel.user.pointsBalance) points")
        
        // End of day summary
        print("\n=== End of Day Summary ===")
        print("Total points earned today: \(viewModel.user.pointsBalance)")
        print("Tasks completed: 4")
        print("Current streak: \(viewModel.user.currentStreak) days")
        
        /*
         Database state at end of day:
         
         users table:
         - pointsBalance: 910 (check-in:50 + basics:160 + residential:200 + survey:500)
         - selected_track: 'hvac'
         - currentStreak: 1
         
         check_ins table:
         - 1 entry for morning check-in
         
         tasks table:
         - 3 entries for completed learning tasks
         - 1 entry for pulse survey
         
         point_allocations table:
         - 4 entries tracking each point allocation
         - Shows automated method
         - Records week 1 budget impact
         
         events table:
         - ~15 entries tracking all user actions
         - App launch, view navigation, task starts, completions
         */
    }
}

// EXAMPLE 6: Admin Dashboard Analytics Query
// ==========================================

struct Example6_AdminAnalytics {
    /*
     Admin wants to see program metrics
     */
    
    func generateWeeklyReport() {
        let db = DatabaseManagerEnhanced.shared
        
        // Query 1: Total users
        let totalUsers = queryTotalUsers()
        // SELECT COUNT(DISTINCT user_id) FROM users;
        
        // Query 2: Tasks completed this week
        let tasksThisWeek = queryTasksThisWeek()
        // SELECT COUNT(*) FROM point_allocations WHERE week_number = 3;
        
        // Query 3: Budget used this week
        let budgetUsed = queryWeeklyBudget()
        // SELECT SUM(allocated_points) FROM point_allocations WHERE week_number = 3;
        // Then divide by points_per_dollar
        
        // Query 4: Most popular track
        let popularTrack = queryPopularTrack()
        // SELECT track_type, COUNT(*) as count FROM user_tracks 
        // WHERE is_active = 1 GROUP BY track_type ORDER BY count DESC LIMIT 1;
        
        // Query 5: Average points per user
        let avgPoints = queryAveragePoints()
        // SELECT AVG(points_balance) FROM users;
        
        print("\n=== Weekly Report - Week 3 ===")
        print("Total Users: \(totalUsers)")
        print("Tasks Completed: \(tasksThisWeek)")
        print("Budget Used: $\(String(format: "%.2f", budgetUsed))")
        print("Most Popular Track: \(popularTrack)")
        print("Avg Points/User: \(Int(avgPoints))")
        
        /*
         Export to CSV:
         
         weekly_report_week3.csv:
         metric,value
         total_users,15
         tasks_completed,127
         budget_used,450.00
         budget_remaining,550.00
         most_popular_track,hvac
         avg_points_per_user,910
         check_ins,89
         pulse_surveys,15
         */
    }
    
    // Mock query functions
    func queryTotalUsers() -> Int { 15 }
    func queryTasksThisWeek() -> Int { 127 }
    func queryWeeklyBudget() -> Double { 450.00 }
    func queryPopularTrack() -> String { "HVAC" }
    func queryAveragePoints() -> Double { 910.0 }
}

// EXAMPLE 7: Budget Algorithm Visualization
// =========================================

struct Example7_BudgetVisualization {
    /*
     Detailed walkthrough of point calculation
     */
    
    func visualizeBudgetCalculation() {
        print("\n=== Budget Calculation Example ===")
        
        // Admin Settings
        let totalBudget = 10000.0          // $10,000 total
        let programWeeks = 12              // 12 week program
        let expectedUsers = 50             // 50 users/week
        let weeklyBudget = 1000.0          // $1,000/week max
        let pointsPerDollar = 100          // 100 points = $1
        
        // Current State (Week 3)
        let currentWeek = 3
        let budgetUsedThisWeek = 450.0     // $450 used so far
        let tasksCompleted = 127           // 127 tasks done
        
        print("\nAdmin Settings:")
        print("  Total Budget: $\(String(format: "%.2f", totalBudget))")
        print("  Program Length: \(programWeeks) weeks")
        print("  Expected Users/Week: \(expectedUsers)")
        print("  Max Weekly Budget: $\(String(format: "%.2f", weeklyBudget))")
        print("  Points per Dollar: \(pointsPerDollar)")
        
        print("\nCurrent State (Week \(currentWeek)):")
        print("  Budget Used This Week: $\(String(format: "%.2f", budgetUsedThisWeek))")
        print("  Tasks Completed: \(tasksCompleted)")
        
        // Calculate available budget
        let budgetRemaining = weeklyBudget - budgetUsedThisWeek
        let pointsAvailable = budgetRemaining * Double(pointsPerDollar)
        
        print("\nAvailable Resources:")
        print("  Budget Remaining: $\(String(format: "%.2f", budgetRemaining))")
        print("  Points Available: \(Int(pointsAvailable))")
        
        // Estimate tasks remaining
        let estimatedTotalTasks = expectedUsers * 5 // Assume 5 tasks/user
        let tasksRemaining = estimatedTotalTasks - tasksCompleted
        
        print("\nTask Projections:")
        print("  Estimated Total Tasks: \(estimatedTotalTasks)")
        print("  Tasks Remaining: \(tasksRemaining)")
        
        // Calculate average points per task
        let avgPointsPerTask = tasksRemaining > 0 ? pointsAvailable / Double(tasksRemaining) : 0
        
        print("\nPoint Allocation:")
        print("  Avg Points/Task: \(Int(avgPointsPerTask))")
        
        // Example allocations
        let taskTypes = [
            ("Check-In", 50, "N/A"),
            ("Learning Module (Beginner)", 200, "beginner"),
            ("Learning Module (Intermediate)", 300, "intermediate"),
            ("Learning Module (Advanced)", 400, "advanced"),
            ("Pulse Survey", 500, "N/A")
        ]
        
        print("\nExample Allocations:")
        for (name, base, difficulty) in taskTypes {
            let multiplier: Double = {
                switch difficulty {
                case "beginner": return 0.8
                case "intermediate": return 1.0
                case "advanced": return 1.3
                default: return 1.0
                }
            }()
            
            let cappedBase = min(Double(base), avgPointsPerTask)
            let final = Int(cappedBase * multiplier)
            
            print("  \(name):")
            print("    Base: \(base) pts")
            print("    Capped: \(Int(cappedBase)) pts")
            print("    Multiplier: \(multiplier)x")
            print("    Final: \(final) pts")
        }
        
        /*
         Visual representation of budget over time:
         
         Week 1: |████████░░| 80% ($800/$1000)
         Week 2: |██████░░░░| 60% ($600/$1000)
         Week 3: |█████░░░░░| 45% ($450/$1000) ← Current
         Week 4: |          | Projected...
         
         As the week progresses and budget is used:
         - Early in week: Higher points possible
         - Late in week: Lower points to conserve budget
         - Next week: Resets to full weekly budget
         */
    }
}

// EXAMPLE 8: Error Handling and Edge Cases
// ========================================

struct Example8_ErrorHandling {
    /*
     Demonstrates proper error handling
     */
    
    func handleEdgeCases() {
        let db = DatabaseManagerEnhanced.shared
        
        // Case 1: Budget exhausted for the week
        print("\n=== Case 1: Budget Exhausted ===")
        // Simulate: $1000 weekly budget, $1000 used
        // Result: calculateAutomatedPoints returns minimum (50 points)
        // Action: Task still completable but with reduced points
        
        // Case 2: Ollama service unavailable
        print("\n=== Case 2: Ollama Unavailable ===")
        // Result: OllamaService sets lastError
        // Action: Show error message, allow retry
        // Fallback: Show cached/default content
        
        // Case 3: Duplicate QR scan
        print("\n=== Case 3: Duplicate Check-In ===")
        // Check if user already checked in today
        // Result: Prevent duplicate points
        // Action: Show "Already checked in today" message
        
        // Case 4: Invalid track content
        print("\n=== Case 4: Invalid Track ===")
        // User selects track but no content exists
        // Result: loadTrackContent returns empty array
        // Action: Show "Content coming soon" message
        
        // Case 5: Admin setting missing
        print("\n=== Case 5: Missing Admin Setting ===")
        // getAdminSetting returns nil
        // Result: Use default fallback value
        // Action: Log warning, continue with defaults
    }
}

// EXAMPLE 9: Data Migration and Backup
// ====================================

struct Example9_DataManagement {
    /*
     Managing data over time
     */
    
    func performWeeklyMaintenance() {
        print("\n=== Weekly Maintenance ===")
        
        // 1. Archive old events (keep last 30 days)
        archiveOldEvents()
        
        // 2. Generate weekly reports
        generateWeeklyReports()
        
        // 3. Backup database
        backupDatabase()
        
        // 4. Update cached analytics
        updateAnalyticsCache()
        
        // 5. Clean up temporary data
        cleanupTempData()
    }
    
    func archiveOldEvents() {
        // Move events older than 30 days to archive table
        print("Archiving events older than 30 days...")
    }
    
    func generateWeeklyReports() {
        // Generate CSV reports for admin
        print("Generating weekly reports...")
    }
    
    func backupDatabase() {
        // Copy database to backup location
        print("Backing up database...")
    }
    
    func updateAnalyticsCache() {
        // Pre-calculate common queries
        print("Updating analytics cache...")
    }
    
    func cleanupTempData() {
        // Remove temporary files
        print("Cleaning up temporary data...")
    }
}

// EXAMPLE 10: Complete Integration Test
// =====================================

struct Example10_IntegrationTest {
    /*
     Full end-to-end test of the system
     */
    
    func runIntegrationTest() {
        print("\n=== INTEGRATION TEST START ===\n")
        
        // Setup
        let viewModel = EnhancedAppViewModel()
        let db = DatabaseManagerEnhanced.shared
        
        // Test 1: Onboarding
        print("Test 1: Onboarding")
        viewModel.completeOnboarding(
            race: "White",
            income: "$25,000-$50,000",
            housing: "Rent",
            goals: ["Career Growth", "Financial Stability"]
        )
        assert(viewModel.user.pointsBalance == 750, "❌ Onboarding points incorrect")
        print("✅ Onboarding complete")
        
        // Test 2: Track Selection
        print("\nTest 2: Track Selection")
        db.saveUserTrack(trackType: "hvac")
        viewModel.loadTrackContent(trackType: "hvac")
        assert(!viewModel.trackTasks.isEmpty, "❌ Track tasks not loaded")
        print("✅ Track selected and content loaded")
        
        // Test 3: QR Check-In
        print("\nTest 3: QR Check-In")
        let checkInPoints = db.calculateAutomatedPoints(taskType: "check_in")
        db.saveCheckIn(qrCodeData: "TEST_QR", location: "Test Location", pointsEarned: checkInPoints)
        viewModel.user.pointsBalance += checkInPoints
        print("✅ Check-in successful")
        
        // Test 4: Learning Module
        print("\nTest 4: Learning Module")
        let initialBalance = viewModel.user.pointsBalance
        if let task = viewModel.trackTasks.first {
            viewModel.completeTask(task)
            assert(viewModel.user.pointsBalance > initialBalance, "❌ Points not added")
        }
        print("✅ Learning module completed")
        
        // Test 5: Admin Settings
        print("\nTest 5: Admin Settings")
        db.updateAdminSetting(key: "test_setting", value: "test_value")
        let retrieved = db.getAdminSetting(key: "test_setting")
        assert(retrieved == "test_value", "❌ Admin setting not saved")
        print("✅ Admin settings working")
        
        // Test 6: Budget Algorithm
        print("\nTest 6: Budget Algorithm")
        let points1 = db.calculateAutomatedPoints(taskType: "learning_module", difficulty: "beginner")
        let points2 = db.calculateAutomatedPoints(taskType: "learning_module", difficulty: "advanced")
        assert(points2 > points1, "❌ Difficulty multiplier not working")
        print("✅ Budget algorithm functioning")
        
        print("\n=== INTEGRATION TEST COMPLETE ===")
        print("All tests passed! ✅")
    }
}

/*
 USAGE EXAMPLES
 ==============
 
 To use these examples in your app:
 
 1. Copy the relevant example to your view or view model
 2. Adapt the code to your specific needs
 3. Test thoroughly with real data
 4. Monitor logs for database operations
 
 Example Usage in a View:
 
 struct MyTestView: View {
     var body: some View {
         Button("Run Integration Test") {
             Example10_IntegrationTest().runIntegrationTest()
         }
     }
 }
 */