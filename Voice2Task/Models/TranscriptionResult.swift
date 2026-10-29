import Foundation

struct TranscriptionResult: Equatable {
    let text: String
    let confidence: Double
    let timestamp: Date

    init(text: String, confidence: Double, timestamp: Date = .now) {
        self.text = text
        self.confidence = confidence
        self.timestamp = timestamp
    }
}
