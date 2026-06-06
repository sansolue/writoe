import Foundation

struct AIService {
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/messages"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    enum AIAction: String {
        case continueWriting = "Continue the story naturally from where it left off. Match the existing tone and style. Write 2-3 paragraphs."
        case rewrite = "Rewrite this passage to improve clarity, flow, and literary quality while keeping the same meaning and events."
        case brainstorm = "Based on this story excerpt, suggest 5 creative ideas for what could happen next. Be specific and interesting."
        case improveDialogue = "Improve the dialogue in this passage to sound more natural and reveal character personality."
    }

    func perform(_ action: AIAction, on text: String, novelContext: String = "") async throws -> String {
        guard !apiKey.isEmpty else { throw AIError.missingAPIKey }

        let systemPrompt = """
        You are a skilled literary assistant helping a novelist. You understand narrative craft, character development, pacing, and prose style.
        Novel context: \(novelContext.isEmpty ? "Not provided." : novelContext)
        """

        let body: [String: Any] = [
            "model": "claude-opus-4-8",
            "max_tokens": 1024,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": "\(action.rawValue)\n\n---\n\(text)"]
            ]
        ]

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AIError.requestFailed
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String else {
            throw AIError.parseError
        }

        return text
    }

    enum AIError: LocalizedError {
        case missingAPIKey, requestFailed, parseError

        var errorDescription: String? {
            switch self {
            case .missingAPIKey: return "No API key set. Add your Anthropic API key in Settings."
            case .requestFailed: return "AI request failed. Check your API key and internet connection."
            case .parseError: return "Could not parse AI response."
            }
        }
    }
}
