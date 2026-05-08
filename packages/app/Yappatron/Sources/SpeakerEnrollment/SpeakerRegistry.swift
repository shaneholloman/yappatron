import Foundation

/// One enrolled speaker with a voiceprint embedding.
struct EnrolledSpeaker: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var embedding: [Float]
    let createdAt: Date
    var updatedAt: Date
}

/// JSON-backed list of enrolled speakers stored under
/// `~/Library/Application Support/Yappatron/enrolled-speakers.json`.
enum SpeakerRegistry {

    private static let filename = "enrolled-speakers.json"

    private struct OnDisk: Codable {
        var version: Int
        var speakers: [EnrolledSpeaker]
    }

    private static var fileURL: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let dir = appSupport.appendingPathComponent("Yappatron", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(filename)
    }

    static func loadAll() -> [EnrolledSpeaker] {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(OnDisk.self, from: data) else {
            return []
        }
        return decoded.speakers
    }

    static func saveAll(_ speakers: [EnrolledSpeaker]) throws {
        let payload = OnDisk(version: 1, speakers: speakers)
        let data = try JSONEncoder().encode(payload)
        try data.write(to: fileURL, options: .atomic)
    }

    static func upsert(_ speaker: EnrolledSpeaker) throws {
        var current = loadAll()
        if let idx = current.firstIndex(where: { $0.id == speaker.id }) {
            var updated = speaker
            updated.updatedAt = Date()
            current[idx] = updated
        } else {
            current.append(speaker)
        }
        try saveAll(current)
    }

    static func remove(id: String) throws {
        var current = loadAll()
        current.removeAll { $0.id == id }
        try saveAll(current)
    }

    static func setName(id: String, name: String) throws {
        var current = loadAll()
        guard let idx = current.firstIndex(where: { $0.id == id }) else { return }
        current[idx].name = name
        current[idx].updatedAt = Date()
        try saveAll(current)
    }
}
