//
//  EnhancedTasksView.swift
//  rpd_9+LLM
//
//  Created by Chris on 11/19/25.
//


import SwiftUI

// MARK: - INTEGRATION GUIDE
/*
 
 HOW TO INTEGRATE THE NEW DATA PIPELINE INTO YOUR APP
 =====================================================
 
 1. REPLACE DatabaseManager with DatabaseManagerEnhanced
    - In your main app file, change:
      private let db = DatabaseManager.shared
    - To:
      private let db = DatabaseManagerEnhanced.shared
 
 2. UPDATE ContentView to use EnhancedHomeView
    - Replace the existing HomeView with EnhancedHomeView
    - This provides track selection and QR scanning
 
 3. ADD Admin Access
    - Add a button in ProfileView to access AdminDashboardView
    - This allows admins to manage budget and settings
 
 4. UPDATE AppViewModel
    - Replace AppViewModel with EnhancedAppViewModel
    - This includes track management and automated point allocation
 
 5. UPDATE TasksView
    - Use EnhancedTasksView (below) to display track-based content
    - This dynamically loads tasks based on selected track
 
 ARCHITECTURE OVERVIEW
 =====================
 
 Data Flow:
 1. User selects track → DatabaseManagerEnhanced.saveUserTrack()
 2. Track content loaded → DatabaseManagerEnhanced.loadTrackContent()
 3. Tasks generated → EnhancedAppViewModel.loadTrackContent()
 4. Task completed → EnhancedAppViewModel.completeTask()
 5. Points calculated → DatabaseManagerEnhanced.calculateAutomatedPoints()
 6. Points saved → DatabaseManagerEnhanced.savePointAllocation()
 
 Admin Dashboard:
 1. Admin opens dashboard → AdminDashboardView
 2. Admin updates settings → AdminViewModel.saveSettings()
 3. Settings saved → DatabaseManagerEnhanced.updateAdminSetting()
 4. Point algorithm uses new settings for future allocations
 
 Point Allocation Algorithm:
 - Manual Mode: Uses base points defined in getBasePoints()
 - Auto Mode: Calculates based on:
   * Total budget
   * Program length
   * Expected users per week
   * Maximum weekly budget
   * Current week number
   * Budget already used this week
   * Task difficulty level
 
 DATABASE SCHEMA
 ===============
 
 New Tables:
 - track_content: Stores learning modules for each track
 - admin_settings: Stores budget and allocation parameters
 - point_allocations: Tracks all point allocations for analytics
 - user_tracks: History of user track selections
 - check_ins: QR code check-in records
 
 Enhanced Tables:
 - users: Added selected_track, track_selected_at
 - tasks: Added task_type, track_type, qr_code_data
 
 */

// MARK: - Enhanced Tasks View with Track Content
struct EnhancedTasksView: View {
    @ObservedObject var viewModel: EnhancedAppViewModel
    @State private var showPulseSurvey = false
    @State private var showLearningView = false
    @State private var selectedTask: UserTask?
    @State private var showTrackSelection = false
    
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
                        // Track Selection Prompt (if no track selected)
                        if viewModel.selectedTrack == nil {
                            selectTrackPrompt()
                        }
                        
                        // Current Track Banner
                        if let track = viewModel.selectedTrack {
                            currentTrackBanner(track: track)
                        }

                        // Pulse Survey Section - Always shown at the top
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Image(systemName: "waveform.path.ecg")
                                    .foregroundColor(.pink)
                                Text("Weekly Check-In")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            
                            PulseSurveyCard {
                                DatabaseManagerEnhanced.shared.logEvent(screen: "Tasks", action: "task_started", detail: "Pulse Survey")
                                showPulseSurvey = true
                            }
                        }

                        // Track-Specific Learning Content
                        if !viewModel.trackTasks.isEmpty {
                            trackLearningSection()
                        }
                        
                        // General Personal Development
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
                    }
                    .padding()
                }
            }
            .navigationTitle("Tasks")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showPulseSurvey) {
                PulseSurveyView(
                    userId: viewModel.user.id,
                    onComplete: { points in
                        viewModel.user.pointsBalance += points
                    },
                    isPresented: $showPulseSurvey
                )
            }
            .sheet(isPresented: $showLearningView) {
                if let task = selectedTask {
                    TrackLearningView(
                        task: task,
                        trackType: viewModel.selectedTrack?.rawValue ?? "",
                        viewModel: viewModel,
                        isPresented: $showLearningView
                    )
                }
            }
            .sheet(isPresented: $showTrackSelection) {
                TrackSelectionView(viewModel: viewModel, isPresented: $showTrackSelection)
            }
            .onAppear {
                DatabaseManagerEnhanced.shared.logEvent(screen: "Tasks", action: "view_appeared")
            }
        }
    }
    
    func selectTrackPrompt() -> some View {
        Button(action: {
            showTrackSelection = true
        }) {
            VStack(spacing: 15) {
                Image(systemName: "map.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
                
                Text("Select a Learning Track")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Choose from Job Development or Personal Growth to unlock personalized learning content")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                HStack {
                    Image(systemName: "arrow.right")
                    Text("Get Started")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    func currentTrackBanner(track: TrackType) -> some View {
        HStack {
            Image(systemName: track.icon)
                .font(.title)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Current Track")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                Text(track.displayName)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            Button(action: {
                showTrackSelection = true
            }) {
                Text("Change")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.3))
                    .cornerRadius(10)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.blue.opacity(0.5), lineWidth: 2)
        )
    }
    
    func trackLearningSection() -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "book.closed.fill")
                    .foregroundColor(.green)
                Text("\(viewModel.selectedTrack?.displayName ?? "Track") Learning")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            ForEach(viewModel.trackTasks, id: \.id) { task in
                TrackTaskCard(task: task) {
                    selectedTask = task
                    showLearningView = true
                }
            }
        }
    }
    
    func handleTaskTap(_ task: UserTask) {
        DatabaseManagerEnhanced.shared.logEvent(screen: "Tasks", action: "task_started", detail: task.title)
        selectedTask = task
        showLearningView = true
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

// MARK: - Track Task Card with Difficulty Badge
struct TrackTaskCard: View {
    let task: UserTask
    let action: () -> Void
    
    var difficultyColor: Color {
        guard let difficulty = task.difficultyLevel else { return .blue }
        switch difficulty.lowercased() {
        case "beginner": return .green
        case "intermediate": return .blue
        case "advanced": return .red
        default: return .blue
        }
    }
    
    var difficultyIcon: String {
        guard let difficulty = task.difficultyLevel else { return "chart.bar" }
        switch difficulty.lowercased() {
        case "beginner": return "chart.bar.fill"
        case "intermediate": return "chart.bar.fill"
        case "advanced": return "chart.bar.fill"
        default: return "chart.bar"
        }
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(task.title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if let difficulty = task.difficultyLevel {
                        Text(difficulty.capitalized)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(difficultyColor.opacity(0.3))
                            .cornerRadius(6)
                    }
                }
                
                Text(task.description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
            }
            
            Spacer()
            
            if task.isCompleted {
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
                    
                    Text("+\(task.points)")
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
                .stroke(task.isCompleted ? Color.green.opacity(0.3) : Color.white.opacity(0.2), lineWidth: 1)
        )
        .opacity(task.isCompleted ? 0.6 : 1.0)
    }
}

// MARK: - Track Learning View with RAG Integration
struct TrackLearningView: View {
    let task: UserTask
    let trackType: String
    @ObservedObject var viewModel: EnhancedAppViewModel
    @Binding var isPresented: Bool
    
    @StateObject private var ollamaService = OllamaService.shared
    @State private var generatedContent = ""
    @State private var showQuiz = false
    @State private var hasGeneratedContent = false
    @State private var showError = false
    @State private var useStreaming = true // Enable streaming for real-time feedback
    
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
                        learningHeader()
                        
                        // Generated Content
                        if !generatedContent.isEmpty {
                            contentSection()
                        }
                        
                        // Quiz Section
                        if hasGeneratedContent && !showQuiz {
                            Button(action: {
                                showQuiz = true
                            }) {
                                HStack {
                                    Image(systemName: "questionmark.circle.fill")
                                    Text("Take Quiz")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [.orange, .orange.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(16)
                            }
                            .padding(.horizontal)
                        }
                        
                        // Quiz View
                        if showQuiz {
                            quizSection()
                        }
                        
                        // Error Display
                        if let error = ollamaService.lastError {
                            errorView(error: error)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(task.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        DatabaseManagerEnhanced.shared.logEvent(screen: "Learning", action: "closed", detail: task.title)
                        isPresented = false
                    }
                    .foregroundColor(.white)
                }
            }
            .onAppear {
                DatabaseManagerEnhanced.shared.logEvent(screen: "Learning", action: "view_appeared", detail: task.title)
                generateContent()
            }
        }
    }
    
    func learningHeader() -> some View {
        VStack(spacing: 15) {
            HStack {
                Image(systemName: "book.fill")
                    .font(.title)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading) {
                    Text(task.title)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(task.description)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                VStack {
                    Text("+\(task.points)")
                        .font(.headline)
                        .foregroundColor(.yellow)
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                }
            }
            
            if ollamaService.isGenerating {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                    Text("Generating personalized content...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
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
    
    func contentSection() -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "book.pages.fill")
                    .foregroundColor(.green)
                Text("Learning Content")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Text(generatedContent)
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
                .lineSpacing(6)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
    
    func quizSection() -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(.orange)
                Text("Knowledge Check")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Text("Quiz functionality would go here")
                .foregroundColor(.white.opacity(0.7))
            
            Button(action: completeTask) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Complete Task")
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
    
    func errorView(error: String) -> some View {
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
    
    func generateContent() {
        Task {
            do {
                // Check if content is cached in database first
                if let cachedContent = await DatabaseManagerEnhanced.shared.getCachedContent(
                    taskId: task.id,
                    trackType: trackType
                ) {
                    await MainActor.run {
                        generatedContent = cachedContent
                        hasGeneratedContent = true
                    }
                    return
                }

                if useStreaming {
                    // Use streaming for real-time feedback - feels much faster!
                    let stream = try await ollamaService.generateTrackContentStreaming(
                        trackType: trackType,
                        title: task.title,
                        description: task.description,
                        difficulty: task.difficultyLevel ?? "intermediate",
                        userGoals: viewModel.user.goals
                    )

                    var fullContent = ""
                    for try await chunk in stream {
                        fullContent += chunk
                        await MainActor.run {
                            generatedContent = fullContent
                        }
                    }

                    await MainActor.run {
                        hasGeneratedContent = true
                    }

                    // Cache the generated content for future use
                    await DatabaseManagerEnhanced.shared.cacheContent(
                        taskId: task.id,
                        trackType: trackType,
                        content: fullContent
                    )

                } else {
                    // Use standard generation (non-streaming)
                    let content = try await ollamaService.generateTrackContent(
                        trackType: trackType,
                        title: task.title,
                        description: task.description,
                        difficulty: task.difficultyLevel ?? "intermediate",
                        userGoals: viewModel.user.goals,
                        useRAG: true
                    )

                    await MainActor.run {
                        generatedContent = content
                        hasGeneratedContent = true
                    }

                    // Cache the generated content for future use
                    await DatabaseManagerEnhanced.shared.cacheContent(
                        taskId: task.id,
                        trackType: trackType,
                        content: content
                    )
                }

            } catch {
                print("Failed to generate content: \(error)")
                await MainActor.run {
                    showError = true
                }
            }
        }
    }
    
    func completeTask() {
        viewModel.completeTask(task)
        
        DatabaseManagerEnhanced.shared.logEvent(screen: "Learning", action: "task_completed", detail: task.title)
        
        // Show success feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        isPresented = false
    }
}

// MARK: - Enhanced Profile View with Admin Access
struct EnhancedProfileView: View {
    @ObservedObject var viewModel: EnhancedAppViewModel
    @State private var showAdminDashboard = false
    @State private var showAdminPassword = false
    @State private var adminPassword = ""
    
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
                        // Profile Header
                        profileHeader()
                        
                        // Progress Section
                        progressSection()
                        
                        // Goals Section
                        goalsSection()
                        
                        // Admin Access Button
                        adminAccessButton()
                    }
                    .padding()
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showAdminDashboard) {
                AdminDashboardView()
            }
            .alert("Admin Access", isPresented: $showAdminPassword) {
                SecureField("Password", text: $adminPassword)
                Button("Cancel", role: .cancel) {
                    adminPassword = ""
                }
                Button("Enter") {
                    if adminPassword == "admin123" { // Change to secure password
                        showAdminDashboard = true
                        adminPassword = ""
                    }
                }
            } message: {
                Text("Enter admin password to access dashboard")
            }
            .onAppear {
                DatabaseManagerEnhanced.shared.logEvent(screen: "Profile", action: "view_appeared")
            }
        }
    }
    
    func profileHeader() -> some View {
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
    }
    
    func progressSection() -> some View {
        GlassProfileSection(title: "My Progress") {
            ProgressRow(title: "Completed Tasks", value: "\(viewModel.tasks.filter { $0.isCompleted }.count)")
            ProgressRow(title: "Current Streak", value: "\(viewModel.user.currentStreak) days")
            ProgressRow(title: "Points Earned", value: "\(viewModel.user.pointsBalance)")
            
            if let track = viewModel.selectedTrack {
                ProgressRow(title: "Current Track", value: track.displayName)
            }
        }
    }
    
    func goalsSection() -> some View {
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
    }
    
    func adminAccessButton() -> some View {
        Button(action: {
            showAdminPassword = true
        }) {
            HStack {
                Image(systemName: "lock.shield")
                Text("Admin Dashboard")
                Spacer()
                Image(systemName: "chevron.right")
            }
            .foregroundColor(.white.opacity(0.7))
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