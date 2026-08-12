import Foundation

enum UserPreferenceKind: String, Codable, CaseIterable, Equatable {
    case allergy
    case dislike
    case like
    case diet
    case goalType = "goal_type"
    case other
}

struct UserPreference: Identifiable, Equatable {
    let id: UUID
    let kind: UserPreferenceKind
    let value: String
    let note: String?
    let createdAt: Date
}

struct UserPreferenceProfile: Equatable {
    var allergies: [String]
    var dislikes: [String]
    var likes: [String]
    var diet: String?
    var goalType: String?

    static let empty = UserPreferenceProfile(
        allergies: [],
        dislikes: [],
        likes: [],
        diet: nil,
        goalType: nil
    )

    init(allergies: [String], dislikes: [String], likes: [String], diet: String?, goalType: String?) {
        self.allergies = allergies
        self.dislikes = dislikes
        self.likes = likes
        self.diet = diet
        self.goalType = goalType
    }

    init(preferences: [UserPreference]) {
        allergies = preferences.filter { $0.kind == .allergy }.map(\.value)
        dislikes = preferences.filter { $0.kind == .dislike }.map(\.value)
        likes = preferences.filter { $0.kind == .like }.map(\.value)
        diet = preferences.last(where: { $0.kind == .diet })?.value
        goalType = preferences.last(where: { $0.kind == .goalType })?.value
    }
}
