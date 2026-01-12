//
//  PulseSurveyIntegrationExample.swift
//  rpd_9+LLM
//
//  Example code showing how to use the Pulse Survey in different views
//

import SwiftUI

// MARK: - Example 1: Basic Integration (Already done in EnhancedTasksView)

struct TasksViewExample: View {
    @ObservedObject var viewModel: CompleteAppViewModel
    @State private var showPulseSurvey = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Pulse Survey Card at the top
                PulseSurveyCard {
                    showPulseSurvey = true
                }
                
                // Other content...
            }
            .padding()
        }
        .sheet(isPresented: $showPulseSurvey) {
            PulseSurveyView(
                userId: viewModel.user.id,
                onComplete: { points in
                    // Update user points
                    viewModel.user.pointsBalance += points
                    // You can also update database here if needed
                },
                isPresented: $showPulseSurvey
            )
        }
    }
}

// MARK: - Example 2: With Custom Points Handler

struct CustomTasksView: View {
    @ObservedObject var viewModel: CompleteAppViewModel
    @State private var showPulseSurvey = false
    @State private var showPointsToast = false
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    PulseSurveyCard {
                        showPulseSurvey = true
                    }
                }
                .padding()
            }
            
            // Optional: Show toast notification for points
            if showPointsToast {
                VStack {
                    Spacer()
                    Text("+500 points earned!")
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .transition(.move(edge: .bottom))
                }
                .padding()
            }
        }
        .sheet(isPresented: $showPulseSurvey) {
            PulseSurveyView(
                userId: viewModel.user.id,
                onComplete: { points in
                    // Custom handling
                    viewModel.user.pointsBalance += points
                    viewModel.db.updateUser(viewModel.user)
                    
                    // Show toast
                    withAnimation {
                        showPointsToast = true
                    }
                    
                    // Hide toast after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            showPointsToast = false
                        }
                    }
                },
                isPresented: $showPulseSurvey
            )
        }
    }
}

// MARK: - Example 3: Inline Card (Compact Version)

struct InlinePulseSurveyExample: View {
    @State private var showFullSurvey = false
    let userId: String
    
    var body: some View {
        VStack(spacing: 15) {
            // Compact inline version
            Button(action: { showFullSurvey = true }) {
                HStack {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundColor(.pink)
                    
                    Text("Complete weekly check-in")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("+500")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
            }
        }
        .sheet(isPresented: $showFullSurvey) {
            PulseSurveyView(
                userId: userId,
                onComplete: { _ in },
                isPresented: $showFullSurvey
            )
        }
    }
}

// MARK: - Example 4: With Completion Tracking

struct TrackedPulseSurveyView: View {
    @ObservedObject var viewModel: CompleteAppViewModel
    @State private var showPulseSurvey = false
    @State private var hasCompletedThisWeek = false
    
    var body: some View {
        VStack(spacing: 20) {
            if !hasCompletedThisWeek {
                // Show survey card
                PulseSurveyCard {
                    showPulseSurvey = true
                }
            } else {
                // Show completion message
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("You've completed this week's check-in!")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
            }
        }
        .sheet(isPresented: $showPulseSurvey) {
            PulseSurveyView(
                userId: viewModel.user.id,
                onComplete: { points in
                    viewModel.user.pointsBalance += points
                    hasCompletedThisWeek = true
                    
                    // Save completion status
                    UserDefaults.standard.set(true, forKey: "pulseSurveyCompleted_\(getCurrentWeek())")
                },
                isPresented: $showPulseSurvey
            )
        }
        .onAppear {
            // Check if completed this week
            hasCompletedThisWeek = UserDefaults.standard.bool(
                forKey: "pulseSurveyCompleted_\(getCurrentWeek())"
            )
        }
    }
    
    private func getCurrentWeek() -> String {
        let calendar = Calendar.current
        let weekOfYear = calendar.component(.weekOfYear, from: Date())
        let year = calendar.component(.year, from: Date())
        return "\(year)_\(weekOfYear)"
    }
}

// MARK: - Example 5: Custom Styling

struct CustomStyledPulseSurvey: View {
    let userId: String
    @Binding var isPresented: Bool
    let onComplete: (Int) -> Void
    
    var body: some View {
        // You can wrap PulseSurveyView with custom styling
        ZStack {
            // Custom background
            LinearGradient(
                colors: [.purple, .blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            PulseSurveyView(
                userId: userId,
                onComplete: onComplete,
                isPresented: $isPresented
            )
        }
    }
}

// MARK: - Example 6: With Navigation

struct NavigationPulseSurveyExample: View {
    @ObservedObject var viewModel: CompleteAppViewModel
    @State private var navigateToSurvey = false
    
    var body: some View {
        NavigationView {
            List {
                // Survey row in a list
                NavigationLink(destination: surveyDestination, isActive: $navigateToSurvey) {
                    HStack {
                        Image(systemName: "waveform.path.ecg")
                            .foregroundColor(.pink)
                        Text("Weekly Check-In")
                        Spacer()
                        Text("+500")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }
                
                // Other list items...
            }
            .navigationTitle("Tasks")
        }
    }
    
    private var surveyDestination: some View {
        PulseSurveyView(
            userId: viewModel.user.id,
            onComplete: { points in
                viewModel.user.pointsBalance += points
                navigateToSurvey = false
            },
            isPresented: $navigateToSurvey
        )
    }
}

// MARK: - Helper: Simple Button Version

struct SimplePulseSurveyButton: View {
    let userId: String
    let onComplete: (Int) -> Void
    @State private var showSurvey = false
    
    var body: some View {
        Button("Complete Weekly Check-In (+500 points)") {
            showSurvey = true
        }
        .padding()
        .background(Color.blue)
        .foregroundColor(.white)
        .cornerRadius(10)
        .sheet(isPresented: $showSurvey) {
            PulseSurveyView(
                userId: userId,
                onComplete: onComplete,
                isPresented: $showSurvey
            )
        }
    }
}

// MARK: - Usage Notes

/*
 INTEGRATION TIPS:
 =================
 
 1. BASIC USAGE:
    - Import PulseSurveyView
    - Add PulseSurveyCard where you want it to appear
    - Set up sheet presentation
    - Pass userId and onComplete handler
 
 2. POINT HANDLING:
    The onComplete closure receives the points earned (500).
    You're responsible for:
    - Updating the user's point balance
    - Saving to database if needed
    - Showing any additional UI feedback
 
 3. CUSTOMIZATION:
    - Use PulseSurveyCard for the standard card design
    - Create your own button/trigger if needed
    - Wrap in custom backgrounds/styling as desired
 
 4. COMPLETION TRACKING:
    - Optional: Track weekly completion
    - Use UserDefaults or database
    - Show different UI for completed state
 
 5. ANALYTICS:
    - All submissions are logged automatically
    - Use DatabaseManagerEnhanced.getPulseSurveys() to retrieve data
    - Query for trends and insights
 
 DATABASE QUERIES:
 =================
 
 To get survey history:
 ```swift
 let surveys = DatabaseManagerEnhanced.shared.getPulseSurveys(limit: 10)
 ```
 
 To check if user completed this week:
 ```swift
 let surveys = DatabaseManagerEnhanced.shared.getPulseSurveys(limit: 1)
 if let lastSurvey = surveys.first {
     let calendar = Calendar.current
     let isThisWeek = calendar.isDate(lastSurvey.timestamp, equalTo: Date(), toGranularity: .weekOfYear)
     // Show appropriate UI
 }
 ```
 
 TESTING:
 ========
 
 To test the survey:
 1. Run the app
 2. Navigate to Tasks tab
 3. Tap the pulse survey card
 4. Fill out the survey
 5. Submit
 6. Check that:
    - Points are awarded (check profile/balance)
    - Success animation shows
    - Modal dismisses automatically
    - Data persists (check database or reopen)
 
*/
