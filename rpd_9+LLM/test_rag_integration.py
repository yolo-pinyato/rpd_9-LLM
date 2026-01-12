//
//  OllamaService.swift
//  rpd_9+LLM
//
//  Created by Chris on 11/19/25.
//  Enhanced for Track-Based Learning Pipeline
//

import Foundation
import Combine

@MainActor
final class OllamaService: ObservableObject {
    static let shared = OllamaService()
    
    // MARK: - Published Properties
    @Published var isGenerating = false
    @Published var lastError: String?
    @Published var streamedOutput: String = ""
    
    private init() {}
    
    // MARK: - Configuration
    private let ollamaURL = URL(string: "http://localhost:11434/api/generate")!
    private let ragURL = URL(string: "http://localhost:8000/generate")!
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Response Models
    
    struct OllamaResponse: Codable {
        let response: String
        let model: String?
        let done: Bool?
        let context: [Int]?
        let total_duration: Int?
        let load_duration: Int?
        let prompt_eval_duration: Int?
        let eval_duration: Int?
    }
    
    struct OllamaStreamResponse: Codable {
        let model: String?
        let response: String
        let done: Bool
        let context: [Int]?
    }
    
    // MARK: - Main Entry Points
    
    /// General-purpose content generation (non-streaming) - NEW for integration
    /// Use this for learning modules, track content, and other structured content
    /// If useRAG is true, tries RAG first; falls back to direct Ollama on failure
    func generateContent(prompt: String, model: String = "gpt-oss:20b", useRAG: Bool = false, track: String? = nil) async throws -> String {
        isGenerating = true
        lastError = nil
        defer { isGenerating = false }
        
        var payload: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": false  // Non-streaming for structured content
        ]
        
        // If using RAG, try RAG endpoint first
        if useRAG, let track = track {
            payload["track"] = track
            payload["top_k"] = 3  // Number of relevant documents to retrieve
            
            do {
                // Try RAG endpoint first (uses /Users/chris/Desktop/rag_service/chroma_db/)
                let response = try await fetchNonStreamingResponse(from: ragURL, payload: payload)
                return response
            } catch {
                // RAG failed, fall back to direct Ollama
                print("⚠️ RAG generation failed, falling back to direct Ollama: \(error.localizedDescription)")
                // Remove RAG-specific parameters for direct Ollama
                payload.removeValue(forKey: "track")
                payload.removeValue(forKey: "top_k")
                let response = try await fetchNonStreamingResponse(from: ollamaURL, payload: payload)
                return response
            }
        } else {
            // Direct Ollama (no RAG)
            let response = try await fetchNonStreamingResponse(from: ollamaURL, payload: payload)
            return response
        }
    }
    
    /// Streaming content generation (existing functionality preserved)
    /// Use this for chat interfaces and real-time generation
    func generateContent(topic: String, userGoals: [String] = [], useRAG: Bool = false, model: String = "gpt-oss:20b") async {
        isGenerating = true
        lastError = nil
        streamedOutput = ""
        
        let goalsText = userGoals.isEmpty ? "" : "considering these goals: \(userGoals.joined(separator: ", "))"
        let promptText = "Write a detailed explanation about \(topic) \(goalsText)."
        
        let payload: [String: Any] = [
            "model": model,
            "prompt": promptText,
            "stream": true
        ]
        
        do {
            let url = useRAG ? ragURL : ollamaURL
            try await streamResponse(from: url, payload: payload)
        } catch {
            lastError = error.localizedDescription
        }
        
        isGenerating = false
    }
    
    // MARK: - Track-Based Learning Integration
    
    /// Generate track-specific learning content with RAG
    /// Optimized for the new track system (HVAC, Nursing, Spiritual, Mental Health)
    /// Tries RAG first, then falls back to direct Ollama if RAG fails
    func generateTrackContent(
        trackType: String,
        title: String,
        description: String,
        difficulty: String,
        userGoals: [String] = [],
        useRAG: Bool = true
    ) async throws -> String {
        
        let prompt = buildTrackPrompt(
            trackType: trackType,
            title: title,
            description: description,
            difficulty: difficulty,
            userGoals: userGoals
        )
        
        // Try RAG first if requested and available
        if useRAG {
            let ragAvailable = await checkRAGConnection()
            if ragAvailable {
                do {
                    // Try RAG generation first
                    return try await generateContent(
                        prompt: prompt,
                        useRAG: true,
                        track: trackType.lowercased()
                    )
                } catch {
                    // RAG failed, fall back to direct Ollama
                    print("⚠️ RAG generation failed, falling back to direct Ollama: \(error.localizedDescription)")
                    return try await generateContent(
                        prompt: prompt,
                        useRAG: false,
                        track: nil
                    )
                }
            } else {
                // RAG not available, use direct Ollama
                print("ℹ️ RAG service not available, using direct Ollama")
                return try await generateContent(
                    prompt: prompt,
                    useRAG: false,
                    track: nil
                )
            }
        } else {
            // Direct Ollama requested
            return try await generateContent(
                prompt: prompt,
                useRAG: false,
                track: nil
            )
        }
    }
    
    /// Generate quiz questions for a learning module
    func generateQuizQuestions(
        topic: String,
        difficulty: String,
        questionCount: Int = 5
    ) async throws -> String {
        
        let prompt = """
        Generate \(questionCount) multiple-choice quiz questions about: \(topic)
        
        Difficulty level: \(difficulty)
        
        Format each question as:
        Q: [Question text]
        A) [Option A]
        B) [Option B]
        C) [Option C]
        D) [Option D]
        Correct: [Letter]
        Explanation: [Brief explanation]
        
        Make the questions practical and relevant for workforce development.
        """
        
        return try await generateContent(prompt: prompt)
    }
    
    /// Generate personalized feedback based on user progress
    func generatePersonalizedFeedback(
        completedTasks: [String],
        userGoals: [String],
        trackType: String
    ) async throws -> String {
        
        let tasksText = completedTasks.joined(separator: ", ")
        let goalsText = userGoals.joined(separator: ", ")
        
        let prompt = """
        Provide encouraging and constructive feedback for a learner in the \(trackType) track.
        
        Their goals: \(goalsText)
        Recently completed: \(tasksText)
        
        Give them:
        1. Recognition of their progress
        2. Suggestions for next steps
        3. Tips for success in this field
        
        Keep it motivating and practical (2-3 paragraphs).
        """
        
        return try await generateContent(prompt: prompt)
    }
    
    // MARK: - Private Helper Methods
    
    private func buildTrackPrompt(
        trackType: String,
        title: String,
        description: String,
        difficulty: String,
        userGoals: [String]
    ) -> String {
        
        let goalsText = userGoals.isEmpty ? "" : "\nLearner's goals: \(userGoals.joined(separator: ", "))"
        
        let trackContext = getTrackContext(trackType: trackType)
        
        return """
        Create a comprehensive learning module for workforce development.
        
        Track: \(trackContext)
        Topic: \(title)
        Description: \(description)
        Difficulty: \(difficulty)\(goalsText)
        
        Please provide:
        
        1. INTRODUCTION (2-3 paragraphs)
        - Overview of the topic
        - Why it matters in this field
        - Real-world relevance
        
        2. KEY CONCEPTS (4-5 main points)
        - Core principles explained clearly
        - Important terminology
        - Common misconceptions to avoid
        
        3. PRACTICAL APPLICATION (2-3 examples)
        - Real workplace scenarios
        - Step-by-step procedures
        - Best practices
        
        4. HANDS-ON TIPS (3-4 actionable tips)
        - Things to try immediately
        - Common mistakes to avoid
        - Pro tips from experienced professionals
        
        5. SUMMARY (1-2 paragraphs)
        - Key takeaways
        - How this connects to career success
        - Next steps in learning journey
        
        Write in a clear, engaging, and professional tone appropriate for someone learning \(difficulty) level content.
        Use specific examples and avoid jargon without explanation.
        """
    }
    
    private func getTrackContext(trackType: String) -> String {
        switch trackType.lowercased() {
        case "hvac":
            return "HVAC (Heating, Ventilation, and Air Conditioning) - preparing for careers in residential and commercial HVAC systems"
        case "nursing":
            return "Nursing - preparing for careers in patient care and clinical healthcare"
        case "spiritual":
            return "Spiritual Health - developing practices for spiritual wellness and Biblical understanding"
        case "mental_health":
            return "Mental Health - building skills in mindfulness, meditation, and emotional wellness"
        default:
            return "Professional Development"
        }
    }
    
    // MARK: - Non-Streaming Response Handler
    
    private func fetchNonStreamingResponse(from url: URL, payload: [String: Any]) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        request.timeoutInterval = 10 // Reduced timeout for faster error detection
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OllamaError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw OllamaError.httpError(statusCode: httpResponse.statusCode)
            }
            
            let ollamaResponse = try JSONDecoder().decode(OllamaResponse.self, from: data)
            return ollamaResponse.response
        } catch let urlError as URLError {
            // Handle connection errors specifically
            switch urlError.code {
            case .notConnectedToInternet:
                throw OllamaError.connectionFailed
            case .cannotConnectToHost:
                // Connection refused means Ollama is not running
                throw OllamaError.connectionFailed
            case .timedOut:
                throw OllamaError.connectionFailed
            default:
                // Convert other URL errors to connection failed
                throw OllamaError.connectionFailed
            }
        } catch {
            // Re-throw our custom errors, convert others
            if error is OllamaError {
                throw error
            } else {
                throw OllamaError.connectionFailed
            }
        }
    }
    
    // MARK: - Streaming Response Handler (Existing - Enhanced)
    
    private func streamResponse(from url: URL, payload: [String: Any]) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        request.timeoutInterval = 120
        
        let (stream, response) = try await URLSession.shared.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw OllamaError.httpError(statusCode: httpResponse.statusCode)
        }
        
        for try await line in stream.lines {
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            
            if let data = line.data(using: .utf8) {
                do {
                    let streamResponse = try JSONDecoder().decode(OllamaStreamResponse.self, from: data)
                    streamedOutput.append(streamResponse.response)
                    
                    // Check if done
                    if streamResponse.done {
                        break
                    }
                } catch {
                    // Fallback to original parsing if structured decode fails
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let token = json["response"] as? String {
                        streamedOutput.append(token)
                    }
                }
            }
        }
    }
    
    // MARK: - Connection & Health Checks
    
    /// Check if Ollama service is running and accessible
    func checkOllamaConnection() async -> Bool {
        guard let url = URL(string: "http://localhost:11434/api/tags") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 3 // Shorter timeout for faster checks
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return httpResponse.statusCode == 200
        } catch let urlError as URLError {
            // Suppress connection errors - we'll handle them gracefully
            switch urlError.code {
            case .cannotConnectToHost, .notConnectedToInternet:
                lastError = "Ollama is not running. Please start it with 'ollama serve' in Terminal."
                return false
            default:
                lastError = "Cannot connect to Ollama. Is it running? (ollama serve)"
                return false
            }
        } catch {
            lastError = "Cannot connect to Ollama. Is it running? (ollama serve)"
            return false
        }
    }
    
    /// Get list of available models
    func getAvailableModels() async throws -> [String] {
        guard let url = URL(string: "http://localhost:11434/api/tags") else {
            throw OllamaError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OllamaError.httpError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let models = json["models"] as? [[String: Any]] {
            return models.compactMap { $0["name"] as? String }
        }
        
        return []
    }
    
    /// Check RAG service health
    func checkRAGConnection() async -> Bool {
        guard let url = URL(string: "http://localhost:8000/health") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 3 // Shorter timeout for faster checks
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            
            if httpResponse.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = json["status"] as? String {
                return status == "healthy"
            }
            return false
        } catch let urlError as URLError {
            // Suppress connection errors - RAG is optional
            switch urlError.code {
            case .cannotConnectToHost, .notConnectedToInternet:
                // RAG not running is OK - we'll use direct Ollama
                return false
            default:
                return false
            }
        } catch {
            return false
        }
    }
    
    /// Get RAG knowledge base statistics
    func getRAGStats() async throws -> [String: Int] {
        guard let url = URL(string: "http://localhost:8000/stats") else {
            throw OllamaError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OllamaError.httpError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            var stats: [String: Int] = [:]
            for (track, value) in json {
                if let trackStats = value as? [String: Any],
                   let count = trackStats["document_count"] as? Int {
                    stats[track] = count
                }
            }
            return stats
        }
        
        return [:]
    }
    
    /// Add a document to the RAG knowledge base
    func addDocumentToRAG(
        track: String,
        content: String,
        metadata: [String: String]
    ) async throws {
        guard let url = URL(string: "http://localhost:8000/add_document") else {
            throw OllamaError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "track": track,
            "content": content,
            "metadata": metadata
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OllamaError.httpError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
    }
    
    // MARK: - Backward Compatibility
    
    /// Keeps older calls like `generateHVACContent(...)` functional
    func generateHVACContent(topic: String, userGoals: [String] = []) async throws -> String {
        // Use streaming version to populate streamedOutput
        await generateContent(topic: topic, userGoals: userGoals)
        
        // Check for errors
        if let error = lastError {
            throw OllamaError.generationFailed(error)
        }
        
        return streamedOutput
    }
    
    /// Legacy method for any track-specific content
    func generateContentForTrack(
        track: String,
        topic: String,
        userGoals: [String] = []
    ) async throws -> String {
        return try await generateTrackContent(
            trackType: track,
            title: topic,
            description: "Learning content for \(topic)",
            difficulty: "intermediate",
            userGoals: userGoals
        )
    }
    
    // MARK: - Error Types
    
    enum OllamaError: LocalizedError {
        case invalidURL
        case invalidResponse
        case httpError(statusCode: Int)
        case generationFailed(String)
        case connectionFailed
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid Ollama URL configuration"
            case .invalidResponse:
                return "Received invalid response from Ollama"
            case .httpError(let code):
                return "HTTP error: \(code)"
            case .generationFailed(let message):
                return "Generation failed: \(message)"
            case .connectionFailed:
                return "Cannot connect to Ollama. Make sure it's running with 'ollama serve'"
            }
        }
    }
    
    // MARK: - Utility Methods
    
    /// Clear the streamed output buffer
    func clearStreamedOutput() {
        streamedOutput = ""
    }
    
    /// Reset error state
    func clearError() {
        lastError = nil
    }
    
    /// Cancel any ongoing generation
    func cancelGeneration() {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        isGenerating = false
    }
}

// MARK: - Usage Examples and Documentation

/*
 USAGE EXAMPLES FOR NEW TRACK SYSTEM
 ====================================
 
 1. Generate Learning Module Content (Non-Streaming)
 ---------------------------------------------------
 
 Task {
     do {
         let content = try await OllamaService.shared.generateTrackContent(
             trackType: "hvac",
             title: "HVAC Basics",
             description: "Introduction to HVAC systems",
             difficulty: "beginner",
             userGoals: ["Career Growth", "Financial Stability"],
             useRAG: true
         )
         
         print("Generated content: \(content)")
     } catch {
         print("Error: \(error.localizedDescription)")
     }
 }
 
 2. Generate Quiz Questions
 ---------------------------
 
 Task {
     do {
         let quiz = try await OllamaService.shared.generateQuizQuestions(
             topic: "Residential HVAC Installation",
             difficulty: "intermediate",
             questionCount: 5
         )
         
         print("Quiz questions: \(quiz)")
     } catch {
         print("Error: \(error)")
     }
 }
 
 3. Streaming Content (Existing Usage - Still Works)
 ----------------------------------------------------
 
 Task {
     await OllamaService.shared.generateContent(
         topic: "HVAC Safety Protocols",
         userGoals: ["Learn Safety", "Career Development"]
     )
     
     // streamedOutput property updates in real-time
     print("Streamed: \(OllamaService.shared.streamedOutput)")
 }
 
 4. Personalized Feedback
 -------------------------
 
 Task {
     do {
         let feedback = try await OllamaService.shared.generatePersonalizedFeedback(
             completedTasks: ["HVAC Basics", "Safety Training"],
             userGoals: ["Career Growth"],
             trackType: "hvac"
         )
         
         print("Feedback: \(feedback)")
     } catch {
         print("Error: \(error)")
     }
 }
 
 5. Health Checks
 ----------------
 
 Task {
     let ollamaOK = await OllamaService.shared.checkOllamaConnection()
     let ragOK = await OllamaService.shared.checkRAGConnection()
     
     print("Ollama: \(ollamaOK ? "✅" : "❌")")
     print("RAG: \(ragOK ? "✅" : "❌")")
     
     if ollamaOK {
         let models = try? await OllamaService.shared.getAvailableModels()
         print("Available models: \(models ?? [])")
     }
 }
 
 6. Integration with TrackLearningView
 --------------------------------------
 
 In your view:
 
 @StateObject private var ollamaService = OllamaService.shared
 @State private var generatedContent = ""
 
 func generateContent() {
     Task {
         do {
             generatedContent = try await ollamaService.generateTrackContent(
                 trackType: viewModel.selectedTrack?.rawValue ?? "hvac",
                 title: task.title,
                 description: task.description,
                 difficulty: task.difficultyLevel ?? "intermediate",
                 userGoals: viewModel.user.goals
             )
         } catch {
             print("Generation failed: \(error)")
         }
     }
 }
 
 CONFIGURATION NOTES
 ===================
 
 1. Current Model:
    Using "gpt-oss:20b" as the default model
    Other available models: llama2, llama3, mistral, codellama, etc.
 
 2. RAG Endpoint:
    Update ragURL to match your RAG service
    Default: http://localhost:8000/generate
 
 3. Timeout:
    Default is 120 seconds
    Adjust based on your hardware and model size
 
 4. Error Handling:
    All async methods throw errors
    Always use try-catch blocks
    Check lastError property for debugging
 
 INTEGRATION WITH DATABASE
 =========================
 
 After generating content and user completes the task:
 
 // Calculate points
 let points = DatabaseManagerEnhanced.shared.calculateAutomatedPoints(
     taskType: "learning_module",
     difficulty: task.difficultyLevel ?? "intermediate"
 )
 
 // Save completion
 DatabaseManagerEnhanced.shared.saveTaskCompletion(
     taskId: task.id.uuidString,
     taskTitle: task.title,
     pointsEarned: points
 )
 
 // Update user balance
 viewModel.user.pointsBalance += points
 */

