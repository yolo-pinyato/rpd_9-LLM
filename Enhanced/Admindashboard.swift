//
//  EnhancedAppViewModel.swift
//  rpd_9+LLM
//
//  Created by Chris on 11/19/25.
//


import SwiftUI
import Combine

// MARK: - Enhanced App View Model
class EnhancedAppViewModel: ObservableObject {
    @Published var user = User()
    @Published var showOnboarding = true
    @Published var tasks: [UserTask] = []
    @Published var trackTasks: [UserTask] = [] // Tasks specific to selected track
    @Published var rewards: [Reward] = []
    @Published var selectedTrack: TrackType?
    
    private let db = DatabaseManagerEnhanced.shared
    
    // Default tasks that are always available
    private let defaultTasks: [UserTask] = [
        UserTask(title: "Weekly Pulse Survey", description: "Rate your week and share feedback", points: 500, category: .pulseSurvey),
        UserTask(title: "Custom Learning Plan", description: "Complete your personalized learning path", points: 250, category: .personalDevelopment)
    ]
    
    // Default rewards
    private let defaultRewards: [Reward] = [
        Reward(title: "$5 Venmo Transfer", description: "Instant cash transfer", pointCost: 1500, type: .cash, discount: nil, discountDaysLeft: nil),
        Reward(title: "$25 Venmo Transfer", description: "Instant cash transfer", pointCost: 5000, type: .cash, discount: nil, discountDaysLeft: nil),
        Reward(title: "$100 Weekly Raffle", description: "Enter weekly cash raffle", pointCost: 10000, type: .cash, discount: nil, discountDaysLeft: nil),
        Reward(title: "$25 Amazon Gift Card", description: "Amazon shopping credit", pointCost: 4000, type: .giftCard, discount: 0.10, discountDaysLeft: 3),
        Reward(title: "$5 Target Gift Card", description: "Target shopping credit", pointCost: 1000, type: .giftCard, discount: 0.10, discountDaysLeft: 3)
    ]
    
    init() {
        loadUserData()
        loadDefaultData()
        loadSelectedTrack()
    }
    
    private func loadUserData() {
        // Load user from original database (assuming migration)
        // You would implement migration logic here if needed
        user.pointsBalance = 750
        user.currentStreak = 1
        showOnboarding = !user.hasCompletedOnboarding
    }
    
    private func loadDefaultData() {
        tasks = defaultTasks
        rewards = defaultRewards
    }
    
    private func loadSelectedTrack() {
        if let trackString = db.getUserSelectedTrack(),
           let track = TrackType(rawValue: trackString) {
            selectedTrack = track
            loadTrackContent(trackType: trackString)
        }
    }
    
    func loadTrackContent(trackType: String) {
        let contentItems = db.loadTrackContent(trackType: trackType)
        
        // Convert track content to tasks
        trackTasks = contentItems.map { item in
            UserTask(
                title: item.title,
                description: item.description,
                points: item.pointsValue,
                category: .learningMaterials,
                trackType: trackType,
                difficultyLevel: item.difficultyLevel
            )
        }
        
        // Update selected track
        if let track = TrackType(rawValue: trackType) {
            selectedTrack = track
        }
        
        print("✅ Loaded \(trackTasks.count) tasks for track: \(trackType)")
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
        
        // Save to database (implement similar to original)
        db.logEvent(screen: "Onboarding", action: "onboarding_completed", detail: "Goals: \(goals.joined(separator: ", "))")
    }
    
    func completeTask(_ task: UserTask) {
        // Calculate points based on admin settings
        let points = db.calculateAutomatedPoints(
            taskType: task.category.rawValue,
            difficulty: task.difficultyLevel ?? "intermediate"
        )
        
        // Update points
        user.pointsBalance += points
        
        // Mark task as completed
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].isCompleted = true
        }
        if let index = trackTasks.firstIndex(where: { $0.id == task.id }) {
            trackTasks[index].isCompleted = true
        }
        
        print("✅ Task completed: \(task.title) - \(points) points earned")
    }
    
    func submitPulseSurvey(weekRating: Int, weekFeelings: String,
                          programRating: Int, programFeelings: String) {
        let points = db.calculateAutomatedPoints(taskType: "pulse_survey")
        user.pointsBalance += points
        
        db.logEvent(screen: "Pulse Survey", action: "survey_submitted", detail: "Week: \(weekRating), Program: \(programRating)")
    }
    
    func redeemReward(_ reward: Reward) {
        let cost = Int(Double(reward.pointCost) * (1.0 - (reward.discount ?? 0.0)))
        if user.pointsBalance >= cost {
            user.pointsBalance -= cost
            db.logEvent(screen: "Rewards", action: "reward_redeemed", detail: reward.title)
        }
    }
}

// MARK: - Enhanced User Task Model
struct UserTaskEnhanced: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let points: Int
    let category: TaskCategory
    var isCompleted: Bool = false
    var trackType: String?
    var difficultyLevel: String?
}

extension UserTask {
    init(title: String, description: String, points: Int, category: TaskCategory, trackType: String? = nil, difficultyLevel: String? = nil) {
        self.init(title: title, description: description, points: points, category: category)
        // Note: You may need to modify the original UserTask struct to include these properties
    }
}

extension TaskCategory {
    var rawValue: String {
        switch self {
        case .pulseSurvey: return "pulse_survey"
        case .personalDevelopment: return "personal_development"
        case .learningMaterials: return "learning_module"
        }
    }
}

// MARK: - Admin Dashboard View
struct AdminDashboardView: View {
    @StateObject private var viewModel = AdminViewModel()
    @Environment(\.dismiss) var dismiss
    
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
                        // Budget Overview
                        budgetOverviewSection()
                        
                        // Settings
                        settingsSection()
                        
                        // Analytics
                        analyticsSection()
                        
                        // Export Data
                        exportSection()
                    }
                    .padding()
                }
            }
            .navigationTitle("Admin Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .onAppear {
                viewModel.loadSettings()
                DatabaseManagerEnhanced.shared.logEvent(screen: "Admin Dashboard", action: "view_appeared")
            }
        }
    }
    
    func budgetOverviewSection() -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundColor(.green)
                Text("Budget Overview")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 15) {
                BudgetMetricRow(
                    title: "Total Budget",
                    value: "$\(String(format: "%.2f", viewModel.totalBudget))",
                    icon: "banknote"
                )
                
                BudgetMetricRow(
                    title: "Weekly Budget",
                    value: "$\(String(format: "%.2f", viewModel.maxWeeklyBudget))",
                    icon: "calendar"
                )
                
                BudgetMetricRow(
                    title: "Budget Used This Week",
                    value: "$\(String(format: "%.2f", viewModel.weeklyBudgetUsed))",
                    icon: "chart.line.uptrend.xyaxis"
                )
                
                // Progress Bar
                VStack(spacing: 8) {
                    HStack {
                        Text("Weekly Budget")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Text("\(Int((viewModel.weeklyBudgetUsed / viewModel.maxWeeklyBudget) * 100))% Used")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(viewModel.weeklyBudgetUsed > viewModel.maxWeeklyBudget * 0.8 ? .red : .green)
                    }
                    
                    ProgressView(value: viewModel.weeklyBudgetUsed, total: viewModel.maxWeeklyBudget)
                        .tint(viewModel.weeklyBudgetUsed > viewModel.maxWeeklyBudget * 0.8 ? .red : .green)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                }
                .padding()
                .background(Color.black.opacity(0.2))
                .cornerRadius(12)
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
    
    func settingsSection() -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "gear")
                    .foregroundColor(.blue)
                Text("Settings")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 15) {
                SettingRow(
                    title: "Total Budget",
                    value: $viewModel.totalBudgetString,
                    icon: "dollarsign.circle",
                    type: .currency
                )
                
                SettingRow(
                    title: "Program Length (weeks)",
                    value: $viewModel.programLengthString,
                    icon: "calendar",
                    type: .number
                )
                
                SettingRow(
                    title: "Expected Users/Week",
                    value: $viewModel.expectedUsersString,
                    icon: "person.2",
                    type: .number
                )
                
                SettingRow(
                    title: "Max Weekly Budget",
                    value: $viewModel.maxWeeklyBudgetString,
                    icon: "chart.bar",
                    type: .currency
                )
                
                SettingRow(
                    title: "Points per Dollar",
                    value: $viewModel.pointsPerDollarString,
                    icon: "star",
                    type: .number
                )
                
                Toggle(isOn: $viewModel.autoAllocatePoints) {
                    HStack {
                        Image(systemName: "wand.and.stars")
                            .foregroundColor(.purple)
                        Text("Auto-Allocate Points")
                            .foregroundColor(.white)
                    }
                }
                .tint(.purple)
                .padding()
                .background(Color.black.opacity(0.2))
                .cornerRadius(12)
                
                Button(action: {
                    viewModel.saveSettings()
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Save Settings")
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
    }
    
    func analyticsSection() -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.orange)
                Text("Analytics")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 15) {
                AnalyticsCard(
                    title: "Total Users",
                    value: "\(viewModel.totalUsers)",
                    icon: "person.3.fill",
                    color: .blue
                )
                
                AnalyticsCard(
                    title: "Tasks Completed",
                    value: "\(viewModel.tasksCompleted)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                AnalyticsCard(
                    title: "Points Allocated",
                    value: "\(viewModel.totalPointsAllocated)",
                    icon: "star.fill",
                    color: .yellow
                )
                
                AnalyticsCard(
                    title: "Check-Ins",
                    value: "\(viewModel.totalCheckIns)",
                    icon: "qrcode",
                    color: .purple
                )
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
    
    func exportSection() -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "arrow.down.doc")
                    .foregroundColor(.indigo)
                Text("Export Data")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 12) {
                ExportButton(
                    title: "Export User Data",
                    icon: "person.2",
                    action: viewModel.exportUserData
                )
                
                ExportButton(
                    title: "Export Task Completions",
                    icon: "checklist",
                    action: viewModel.exportTaskData
                )
                
                ExportButton(
                    title: "Export Point Allocations",
                    icon: "star",
                    action: viewModel.exportPointData
                )
                
                ExportButton(
                    title: "Export All Data (CSV)",
                    icon: "doc.text",
                    action: viewModel.exportAllData
                )
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

// MARK: - Admin View Model
class AdminViewModel: ObservableObject {
    @Published var totalBudget: Double = 10000.0
    @Published var totalBudgetString: String = "10000"
    @Published var programLength: Int = 12
    @Published var programLengthString: String = "12"
    @Published var expectedUsers: Int = 50
    @Published var expectedUsersString: String = "50"
    @Published var maxWeeklyBudget: Double = 1000.0
    @Published var maxWeeklyBudgetString: String = "1000"
    @Published var pointsPerDollar: Int = 100
    @Published var pointsPerDollarString: String = "100"
    @Published var autoAllocatePoints: Bool = true
    
    @Published var weeklyBudgetUsed: Double = 0.0
    @Published var totalUsers: Int = 0
    @Published var tasksCompleted: Int = 0
    @Published var totalPointsAllocated: Int = 0
    @Published var totalCheckIns: Int = 0
    
    private let db = DatabaseManagerEnhanced.shared
    
    func loadSettings() {
        let settings = db.getAllAdminSettings()
        
        totalBudget = Double(settings["total_budget"] ?? "10000") ?? 10000.0
        totalBudgetString = String(format: "%.0f", totalBudget)
        
        programLength = Int(settings["program_length_weeks"] ?? "12") ?? 12
        programLengthString = "\(programLength)"
        
        expectedUsers = Int(settings["expected_users_per_week"] ?? "50") ?? 50
        expectedUsersString = "\(expectedUsers)"
        
        maxWeeklyBudget = Double(settings["max_budget_per_week"] ?? "1000") ?? 1000.0
        maxWeeklyBudgetString = String(format: "%.0f", maxWeeklyBudget)
        
        pointsPerDollar = Int(settings["points_per_dollar"] ?? "100") ?? 100
        pointsPerDollarString = "\(pointsPerDollar)"
        
        autoAllocatePoints = (settings["auto_allocate_points"] ?? "true").lowercased() == "true"
        
        // Load analytics
        loadAnalytics()
    }
    
    func saveSettings() {
        db.updateAdminSetting(key: "total_budget", value: totalBudgetString)
        db.updateAdminSetting(key: "program_length_weeks", value: programLengthString)
        db.updateAdminSetting(key: "expected_users_per_week", value: expectedUsersString)
        db.updateAdminSetting(key: "max_budget_per_week", value: maxWeeklyBudgetString)
        db.updateAdminSetting(key: "points_per_dollar", value: pointsPerDollarString)
        db.updateAdminSetting(key: "auto_allocate_points", value: autoAllocatePoints ? "true" : "false")
        
        print("✅ Admin settings saved")
        
        // Reload to update computed values
        loadSettings()
    }
    
    func loadAnalytics() {
        // These would query the database - simplified for example
        totalUsers = 15
        tasksCompleted = 127
        totalPointsAllocated = 35000
        totalCheckIns = 89
        weeklyBudgetUsed = 450.0
    }
    
    func exportUserData() {
        print("📤 Exporting user data...")
        DatabaseManagerEnhanced.shared.logEvent(screen: "Admin Dashboard", action: "export", detail: "user_data")
        // Implement CSV export
    }
    
    func exportTaskData() {
        print("📤 Exporting task data...")
        DatabaseManagerEnhanced.shared.logEvent(screen: "Admin Dashboard", action: "export", detail: "task_data")
        // Implement CSV export
    }
    
    func exportPointData() {
        print("📤 Exporting point allocation data...")
        DatabaseManagerEnhanced.shared.logEvent(screen: "Admin Dashboard", action: "export", detail: "point_data")
        // Implement CSV export
    }
    
    func exportAllData() {
        print("📤 Exporting all data...")
        DatabaseManagerEnhanced.shared.logEvent(screen: "Admin Dashboard", action: "export", detail: "all_data")
        // Implement comprehensive CSV export
    }
}

// MARK: - Admin Dashboard Components

struct BudgetMetricRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.7))
            Text(title)
                .foregroundColor(.white)
            Spacer()
            Text(value)
                .font(.headline)
                .foregroundColor(.green)
        }
        .padding()
        .background(Color.black.opacity(0.2))
        .cornerRadius(12)
    }
}

struct SettingRow: View {
    let title: String
    @Binding var value: String
    let icon: String
    let type: SettingType
    
    enum SettingType {
        case number
        case currency
        case text
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.7))
            Text(title)
                .foregroundColor(.white)
                .font(.subheadline)
            Spacer()
            TextField("", text: $value)
                .multilineTextAlignment(.trailing)
                .foregroundColor(.blue)
                .font(.headline)
                .keyboardType(type == .text ? .default : .decimalPad)
                .frame(width: 100)
        }
        .padding()
        .background(Color.black.opacity(0.2))
        .cornerRadius(12)
    }
}

struct AnalyticsCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 50, height: 50)
                .background(color.opacity(0.2))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.black.opacity(0.2))
        .cornerRadius(12)
    }
}

struct ExportButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
                Spacer()
                Image(systemName: "arrow.down.circle")
            }
            .foregroundColor(.white)
            .padding()
            .background(Color.black.opacity(0.2))
            .cornerRadius(12)
        }
    }
}