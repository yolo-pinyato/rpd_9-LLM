//
//  PulseSurveyView.swift
//  rpd_9+LLM
//
//  Created by Assistant on 1/12/26.
//

import SwiftUI
import UIKit

// MARK: - Pulse Survey Model
struct PulseSurvey: Codable {
    let id: String
    let userId: String
    let timestamp: Date
    let weeklyFeeling: Int // 1-10 scale
    let weeklyFeelingReason: String? // Optional text
    let programFeeling: Int // 1-10 scale
    let programFeelingReason: String? // Optional text
    
    init(id: String = UUID().uuidString,
         userId: String,
         timestamp: Date = Date(),
         weeklyFeeling: Int,
         weeklyFeelingReason: String?,
         programFeeling: Int,
         programFeelingReason: String?) {
        self.id = id
        self.userId = userId
        self.timestamp = timestamp
        self.weeklyFeeling = weeklyFeeling
        self.weeklyFeelingReason = weeklyFeelingReason
        self.programFeeling = programFeeling
        self.programFeelingReason = programFeelingReason
    }
}

// MARK: - Pulse Survey View
struct PulseSurveyView: View {
    let userId: String
    let onComplete: (Int) -> Void // Callback with points earned
    @Binding var isPresented: Bool
    
    @State private var weeklyFeeling: Double = 5.0
    @State private var weeklyFeelingReason: String = ""
    @State private var programFeeling: Double = 5.0
    @State private var programFeelingReason: String = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    
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
                        // Header
                        surveyHeader()
                        
                        // Question 1: Weekly Feeling
                        questionSection(
                            title: "How are you feeling so far this week?",
                            icon: "heart.fill",
                            color: .pink
                        ) {
                            VStack(spacing: 20) {
                                SliderQuestion(
                                    value: $weeklyFeeling,
                                    range: 1...10,
                                    step: 1
                                )
                                
                                TextFieldQuestion(
                                    text: $weeklyFeelingReason,
                                    placeholder: "(Optional) In 1-2 sentences, why are you feeling this way?"
                                )
                            }
                        }
                        
                        // Question 2: Program Feeling
                        questionSection(
                            title: "How are you feeling so far this week about the program?",
                            icon: "star.fill",
                            color: .orange
                        ) {
                            VStack(spacing: 20) {
                                SliderQuestion(
                                    value: $programFeeling,
                                    range: 1...10,
                                    step: 1
                                )
                                
                                TextFieldQuestion(
                                    text: $programFeelingReason,
                                    placeholder: "(Optional) In 1-2 sentences, why are you feeling this way about the program?"
                                )
                            }
                        }
                        
                        // Submit Button
                        submitButton()
                        
                        // Note about points
                        surveyNote()
                    }
                    .padding()
                }
                .opacity(showSuccess ? 0 : 1)
                
                // Success Overlay
                if showSuccess {
                    successOverlay()
                }
            }
            .navigationTitle("Weekly Check-In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        isPresented = false
                    }
                    .foregroundColor(.white)
                }
            }
            .disabled(isSubmitting || showSuccess)
            .onAppear {
                DatabaseManagerEnhanced.shared.logEvent(screen: "Pulse Survey", action: "view_appeared")
            }
        }
    }
    
    // MARK: - View Components
    
    func surveyHeader() -> some View {
        VStack(spacing: 15) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("Weekly Pulse Check")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Help us understand how you're doing this week")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
    
    func questionSection<Content: View>(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            content()
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
    
    func submitButton() -> some View {
        Button(action: submitSurvey) {
            HStack {
                if isSubmitting {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Submit Check-In")
                }
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
            .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .disabled(isSubmitting)
    }
    
    func surveyNote() -> some View {
        HStack {
            Image(systemName: "star.fill")
                .foregroundColor(.yellow)
            Text("Earn 500 points for completing this check-in")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    func successOverlay() -> some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                
                Text("Thank You!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Your feedback helps us improve")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                
                Text("+500 points")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.yellow)
            }
            .padding(40)
            .background(.ultraThinMaterial)
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.3), radius: 20)
        }
        .transition(.opacity)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                isPresented = false
            }
        }
    }
    
    // MARK: - Actions
    
    func submitSurvey() {
        guard !isSubmitting else { return }
        
        isSubmitting = true
        DatabaseManagerEnhanced.shared.logEvent(
            screen: "Pulse Survey",
            action: "survey_submitted",
            detail: "Weekly:\(Int(weeklyFeeling)), Program:\(Int(programFeeling))"
        )
        
        // Create survey object
        let survey = PulseSurvey(
            userId: userId,
            weeklyFeeling: Int(weeklyFeeling),
            weeklyFeelingReason: weeklyFeelingReason.isEmpty ? nil : weeklyFeelingReason,
            programFeeling: Int(programFeeling),
            programFeelingReason: programFeelingReason.isEmpty ? nil : programFeelingReason
        )
        
        // Save to database
        DatabaseManagerEnhanced.shared.savePulseSurvey(survey)
        
        // Award points
        let points = 500
        DatabaseManagerEnhanced.shared.savePointAllocation(
            taskId: "pulse_survey_\(Date().timeIntervalSince1970)",
            taskType: "pulse_survey",
            pointsAwarded: points,
            reason: "Weekly pulse check-in completed"
        )
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Call completion handler
        onComplete(points)
        
        // Show success animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation {
                showSuccess = true
            }
        }
    }
}

// MARK: - Slider Question Component
struct SliderQuestion: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    
    var body: some View {
        VStack(spacing: 15) {
            // Current value display
            HStack {
                Text("1")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                
                Spacer()
                
                Text("\(Int(value))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 60)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.3))
                    )
                
                Spacer()
                
                Text("10")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            
            // Slider
            Slider(value: $value, in: range, step: step)
                .tint(.blue)
            
            // Scale labels
            HStack {
                Text("Low")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
                
                Spacer()
                
                Text("High")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }
}

// MARK: - Text Field Question Component
struct TextFieldQuestion: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(placeholder)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
            
            ZStack(alignment: .topLeading) {
                // Background
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                
                // TextEditor
                if #available(iOS 16.0, *) {
                    TextEditor(text: $text)
                        .frame(minHeight: 80, maxHeight: 120)
                        .padding(12)
                        .foregroundColor(.white)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                } else {
                    TextEditor(text: $text)
                        .frame(minHeight: 80, maxHeight: 120)
                        .padding(12)
                        .foregroundColor(.white)
                        .background(Color.clear)
                }
            }
        }
    }
}

// MARK: - Compact Pulse Survey Card (for Tasks tab)
struct PulseSurveyCard: View {
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "waveform.path.ecg")
                            .foregroundColor(.pink)
                            .font(.title2)
                        
                        Text("Weekly Pulse Survey")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    
                    Text("Rate your week and share feedback")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    Text("+500")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white.opacity(0.5))
                        .font(.caption)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.pink.opacity(0.3), lineWidth: 2)
            )
            .shadow(color: .pink.opacity(0.2), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview
#Preview {
    PulseSurveyCard {
        print("Survey tapped")
    }
    .padding()
    .background(
        LinearGradient(
            colors: [Color(red: 0.1, green: 0.2, blue: 0.45), Color(red: 0.2, green: 0.1, blue: 0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}
