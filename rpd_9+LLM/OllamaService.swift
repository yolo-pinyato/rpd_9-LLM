//
//  OllamaService.swift
//  rpd_9+LLM
//
//  Simplified version for local RAG and Ollama integration
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
    @Published var customMacIP: String? {
        didSet {
            if let ip = customMacIP {
                UserDefaults.standard.set(ip, forKey: "customMacIP")
            }
        }
    }

    private init() {
        // Load saved custom IP
        self.customMacIP = UserDefaults.standard.string(forKey: "customMacIP")
    }
    
    // MARK: - Configuration
    // For iOS Simulator, use localhost (which resolves better than 127.0.0.1)
    // For physical devices, use your Mac's IP address
    private let defaultModel = "llama3.2:3b" // Faster model for quicker generation
    private let fastModel = "llama3.2:1b" // Ultra-fast model for simple content

    // Dynamic URL properties based on environment and user settings
    private var ollamaBaseURL: String {
        #if targetEnvironment(simulator)
        return "http://localhost:11434"
        #else
        return OllamaService.getMacIPURL(port: 11434, customIP: customMacIP)
        #endif
    }

    private var ragBaseURL: String {
        #if targetEnvironment(simulator)
        return "http://localhost:8000"
        #else
        return OllamaService.getMacIPURL(port: 8000, customIP: customMacIP)
        #endif
    }

    // MARK: - Network Configuration Helper

    /// Get the Mac's IP address dynamically for physical device connections
    /// Supports IP addresses, domains, and Cloudflare Tunnel URLs
    private static func getMacIPURL(port: Int, customIP: String?) -> String {
        // Use custom IP if provided
        if let custom = customIP, !custom.isEmpty {
            let trimmed = custom.trimmingCharacters(in: .whitespaces)

            // Already has protocol (http:// or https://)
            if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
                return trimmed
            }

            // Contains a domain (has dots but not just IP format with port)
            if trimmed.contains(".") && !trimmed.contains(":") {
                // Check if it looks like a domain name (not just an IP)
                let components = trimmed.components(separatedBy: ".")
                let lastComponent = components.last ?? ""

                // If last component is not all digits, it's likely a domain
                if !lastComponent.allSatisfy({ $0.isNumber }) {
                    // It's a domain - use HTTPS without port
                    print("🌐 Using domain with HTTPS: \(trimmed)")
                    return "https://\(trimmed)"
                }
            }

            // Contains port already
            if trimmed.contains(":") {
                return "http://\(trimmed)"
            }

            // It's a plain IP address - add http and port
            return "http://\(trimmed):\(port)"
        }

        // For physical devices, we MUST have a custom IP set by the user
        // ProcessInfo.processInfo.hostName returns the iPhone's hostname, not the Mac's
        // So we show a clear error message
        print("⚠️ No Mac IP address configured. Please set it in Profile > Network Settings")

        // Return a placeholder that will fail with a clear error
        // This encourages users to configure the IP properly
        return "http://CONFIGURE-MAC-IP-IN-SETTINGS:\(port)"
    }
    
    // MARK: - Response Models
    struct OllamaResponse: Codable {
        let response: String
        let model: String?
        let done: Bool?
    }
    
    struct RAGResponse: Codable {
        let response: String
        let model: String?
        let done: Bool?
        let sources: [RAGSource]?
    }
    
    struct RAGSource: Codable {
        let content: String?
        let metadata: [String: String]?
    }
    
    // MARK: - Main Content Generation

    /// Ask a direct question to Ollama
    func askQuestion(question: String, model: String? = nil) async throws -> String {
        let modelToUse = model ?? defaultModel

        await MainActor.run {
            self.isGenerating = true
            self.lastError = nil
            self.streamedOutput = ""
        }

        defer {
            Task { @MainActor in
                self.isGenerating = false
            }
        }

        return try await generateWithOllama(prompt: question, model: modelToUse)
    }

    /// Ask a question with streaming response for real-time feedback
    func askQuestionStreaming(question: String, model: String? = nil) async throws -> AsyncThrowingStream<String, Error> {
        let modelToUse = model ?? defaultModel

        await MainActor.run {
            self.isGenerating = true
            self.lastError = nil
            self.streamedOutput = ""
        }

        return try await generateWithOllamaStreaming(prompt: question, model: modelToUse)
    }

    /// Generate HVAC learning content with 200 character limit
    func generateHVACContent(topic: String, userGoals: [String] = []) async throws -> String {
        await MainActor.run {
            self.isGenerating = true
            self.lastError = nil
            self.streamedOutput = ""
        }

        defer {
            Task { @MainActor in
                self.isGenerating = false
            }
        }

        let goalsText = userGoals.isEmpty ? "" : "\nLearner's goals: \(userGoals.joined(separator: ", "))"

        let prompt = """
        Create a brief learning module about: \(topic)
        \(goalsText)

        Provide a concise overview (maximum 200 characters) that introduces the topic and explains why it's important in HVAC/Building Operations.

        Keep it clear, engaging, and focused on practical relevance.
        """

        let content = try await generateWithOllama(prompt: prompt, model: defaultModel)

        // Trim to 200 characters if needed
        if content.count > 200 {
            return String(content.prefix(200))
        }
        return content
    }

    /// Quiz Question Model
    struct QuizQuestion: Codable {
        let question: String
        let options: [String]
        let correctAnswer: Int
        let explanation: String
    }

    /// Generate a multiple choice question based on the shared content
    func generateQuizQuestion(content: String) async throws -> QuizQuestion {
        await MainActor.run {
            self.isGenerating = true
            self.lastError = nil
        }

        defer {
            Task { @MainActor in
                self.isGenerating = false
            }
        }

        let prompt = """
        Based on this content:
        "\(content)"

        Generate a multiple choice question with exactly 3 answer options to test understanding of this content.

        Respond ONLY with valid JSON in this exact format (no additional text):
        {
            "question": "Your question here?",
            "options": ["Option A", "Option B", "Option C"],
            "correctAnswer": 0,
            "explanation": "Brief explanation of the correct answer"
        }

        The correctAnswer should be the index (0, 1, or 2) of the correct option in the options array.
        Make the question specific to the content provided and ensure only one answer is clearly correct.
        """

        let response = try await generateWithOllama(prompt: prompt, model: defaultModel)

        // Try to extract JSON from the response
        let jsonString = extractJSON(from: response)

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw OllamaError.generationFailed("Invalid JSON format in response")
        }

        do {
            let quiz = try JSONDecoder().decode(QuizQuestion.self, from: jsonData)
            // Validate the quiz
            guard quiz.options.count == 3,
                  quiz.correctAnswer >= 0,
                  quiz.correctAnswer < 3 else {
                throw OllamaError.generationFailed("Invalid quiz structure")
            }
            return quiz
        } catch {
            throw OllamaError.generationFailed("Failed to parse quiz: \(error.localizedDescription)")
        }
    }

    /// Extract JSON from LLM response that may contain additional text
    private func extractJSON(from text: String) -> String {
        // Try to find JSON object between { and }
        if let start = text.firstIndex(of: "{"),
           let end = text.lastIndex(of: "}") {
            let jsonSubstring = text[start...end]
            return String(jsonSubstring)
        }
        return text
    }

    /// Generate track-specific learning content
    /// Tries RAG first (from /Users/chris/Desktop/rag_service/chroma_db/), falls back to direct Ollama
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

        // Try RAG first if requested
        if useRAG {
            if await checkRAGConnection() {
                do {
                    return try await generateWithRAG(
                        prompt: prompt,
                        track: trackType.lowercased(),
                        model: defaultModel
                    )
                } catch {
                    print("⚠️ RAG failed, using direct Ollama: \(error.localizedDescription)")
                    // Fall through to direct Ollama
                }
            } else {
                print("ℹ️ RAG service not available, using direct Ollama")
            }
        }

        // Direct Ollama generation
        return try await generateWithOllama(prompt: prompt, model: fastModel) // Use faster model
    }

    /// Generate track content with streaming for real-time feedback
    func generateTrackContentStreaming(
        trackType: String,
        title: String,
        description: String,
        difficulty: String,
        userGoals: [String] = []
    ) async throws -> AsyncThrowingStream<String, Error> {

        let prompt = buildTrackPrompt(
            trackType: trackType,
            title: title,
            description: description,
            difficulty: difficulty,
            userGoals: userGoals
        )

        // Use streaming for immediate feedback
        return try await generateWithOllamaStreaming(prompt: prompt, model: fastModel)
    }
    
    // MARK: - RAG Generation
    
    private func generateWithRAG(prompt: String, track: String, model: String) async throws -> String {
        guard let url = URL(string: "\(ragBaseURL)/generate") else {
            throw OllamaError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 180 // Increased timeout for LLM generation
        
        let payload: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "track": track,
            "top_k": 3,
            "stream": false
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            _ = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OllamaError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let ragResponse = try JSONDecoder().decode(RAGResponse.self, from: data)
        
        if let sources = ragResponse.sources, !sources.isEmpty {
            print("✅ RAG retrieved \(sources.count) sources from knowledge base")
        }
        
        return ragResponse.response
    }
    
    // MARK: - Direct Ollama Generation

    private func generateWithOllama(prompt: String, model: String) async throws -> String {
        guard let url = URL(string: "\(ollamaBaseURL)/api/generate") else {
            throw OllamaError.invalidURL
        }

        print("🔗 Connecting to Ollama at: \(ollamaBaseURL)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120 // Reduced timeout - faster models need less time

        let payload: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": false,
            "options": [
                "temperature": 0.7,
                "num_predict": 500  // Limit output length for faster generation
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? String {
                throw OllamaError.generationFailed(error)
            }
            throw OllamaError.httpError(statusCode: httpResponse.statusCode)
        }

        let ollamaResponse = try JSONDecoder().decode(OllamaResponse.self, from: data)
        return ollamaResponse.response
    }

    // MARK: - Streaming Generation for Real-Time Feedback

    private func generateWithOllamaStreaming(prompt: String, model: String) async throws -> AsyncThrowingStream<String, Error> {
        guard let url = URL(string: "\(ollamaBaseURL)/api/generate") else {
            throw OllamaError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let payload: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": true,
            "options": [
                "temperature": 0.7,
                "num_predict": 500
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw OllamaError.httpError(statusCode: httpResponse.statusCode)
        }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    var buffer = ""
                    for try await byte in bytes {
                        buffer.append(Character(UnicodeScalar(byte)))

                        // Process complete JSON lines
                        while let newlineRange = buffer.range(of: "\n") {
                            let line = String(buffer[..<newlineRange.lowerBound])
                            buffer.removeSubrange(..<newlineRange.upperBound)

                            if line.isEmpty { continue }

                            if let jsonData = line.data(using: .utf8),
                               let json = try? JSONDecoder().decode(OllamaResponse.self, from: jsonData) {

                                if !json.response.isEmpty {
                                    await MainActor.run {
                                        self.streamedOutput += json.response
                                    }
                                    continuation.yield(json.response)
                                }

                                if json.done == true {
                                    continuation.finish()
                                    await MainActor.run {
                                        self.isGenerating = false
                                    }
                                    return
                                }
                            }
                        }
                    }
                    continuation.finish()
                    await MainActor.run {
                        self.isGenerating = false
                    }
                } catch {
                    continuation.finish(throwing: error)
                    await MainActor.run {
                        self.isGenerating = false
                        self.lastError = error.localizedDescription
                    }
                }
            }
        }
    }
    
    // MARK: - Public URL Getters (for UI display)

    func getCurrentOllamaURL() -> String {
        return ollamaBaseURL
    }

    func getCurrentRAGURL() -> String {
        return ragBaseURL
    }

    // MARK: - Connection Checks

    func checkOllamaConnection() async -> Bool {
        guard let url = URL(string: "\(ollamaBaseURL)/api/tags") else { return false }
        print("🔍 Checking Ollama connection at: \(ollamaBaseURL)")

        // Configure session with better networking properties
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 10
        configuration.waitsForConnectivity = false
        let session = URLSession(configuration: configuration)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response from Ollama")
                return false
            }
            let isConnected = httpResponse.statusCode == 200
            print(isConnected ? "✅ Ollama connected successfully" : "❌ Ollama returned status \(httpResponse.statusCode)")
            return isConnected
        } catch {
            print("❌ Ollama connection failed: \(error.localizedDescription)")
            return false
        }
    }
    
    func checkRAGConnection() async -> Bool {
        guard let url = URL(string: "\(ragBaseURL)/health") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5 // Increased for network latency
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            
            if httpResponse.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = json["status"] as? String {
                return status == "healthy"
            }
            return false
        } catch {
            return false
        }
    }
    
    func getAvailableModels() async throws -> [String] {
        guard let url = URL(string: "\(ollamaBaseURL)/api/tags") else {
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
    
    // MARK: - Prompt Building
    
    private func buildTrackPrompt(
        trackType: String,
        title: String,
        description: String,
        difficulty: String,
        userGoals: [String]
    ) -> String {

        let trackContext = getTrackContext(trackType: trackType)

        // Optimized shorter prompt for faster generation
        return """
        Create a brief learning module for \(trackContext).

        Topic: \(title)
        Level: \(difficulty)

        Provide (250-300 words total):

        1. INTRODUCTION (2-3 sentences)
        - What this topic is and why it matters

        2. KEY CONCEPTS (3-4 bullet points)
        - Core ideas to understand
        - Important terms

        3. PRACTICAL EXAMPLE
        - One real workplace scenario

        4. QUICK TIPS (2-3 points)
        - What to remember
        - Common mistakes to avoid

        Keep it clear, concise, and actionable for \(difficulty) level learners.
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
                return "Invalid URL configuration"
            case .invalidResponse:
                return "Received invalid response"
            case .httpError(let code):
                return "HTTP error: \(code)"
            case .generationFailed(let message):
                return "Generation failed: \(message)"
            case .connectionFailed:
                return "Cannot connect to Ollama. Make sure it's running with 'ollama serve'"
            }
        }
    }

    // MARK: - Claude API Integration
    func generateWithClaudeAPI(prompt: String, apiKey: String) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let requestBody: [String: Any] = [
            "model": "claude-3-5-sonnet-20241022",
            "max_tokens": 2048,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 30

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw OllamaError.invalidResponse
            }

            if httpResponse.statusCode != 200 {
                // Try to parse error message
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorJson["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    throw OllamaError.generationFailed(message)
                }
                throw OllamaError.httpError(statusCode: httpResponse.statusCode)
            }

            // Parse response
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = json["content"] as? [[String: Any]],
                  let firstContent = content.first,
                  let text = firstContent["text"] as? String else {
                throw OllamaError.invalidResponse
            }

            return text
        } catch let error as OllamaError {
            throw error
        } catch {
            throw OllamaError.generationFailed(error.localizedDescription)
        }
    }
}

