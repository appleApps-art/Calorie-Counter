import Foundation

enum UserProfileMapper {
    static func map(_ object: CDUserProfile) -> UserProfile? {
        guard let id = object.id else { return nil }
        return UserProfile(
            id: id,
            sex: object.sex.flatMap(BiologicalSex.init(rawValue:)),
            age: object.age?.intValue,
            heightCm: object.heightCm?.doubleValue,
            weightKg: object.weightKg?.doubleValue,
            activityLevel: object.activityLevel.flatMap(ActivityLevel.init(rawValue:)),
            goalType: object.goalType.flatMap(GoalType.init(rawValue:)),
            avatarFileName: object.avatarFileName,
            avatarURL: nil,
            onboardingStep: object.onboardingStep.flatMap(OnboardingStep.init(rawValue:)) ?? .welcome,
            onboardingCompleted: object.onboardingCompleted,
            updatedAt: object.updatedAt ?? Date()
        )
    }

    static func apply(_ profile: UserProfile, to object: CDUserProfile) {
        object.id = profile.id
        object.sex = profile.sex?.rawValue
        object.age = profile.age.map { NSNumber(value: $0) }
        object.heightCm = profile.heightCm.map { NSNumber(value: $0) }
        object.weightKg = profile.weightKg.map { NSNumber(value: $0) }
        object.activityLevel = profile.activityLevel?.rawValue
        object.goalType = profile.goalType?.rawValue
        object.avatarFileName = profile.avatarFileName
        object.onboardingStep = profile.onboardingStep.rawValue
        object.onboardingCompleted = profile.onboardingCompleted
        object.updatedAt = profile.updatedAt
    }
}

enum UserPreferenceMapper {
    static func map(_ object: CDUserPreference) -> UserPreference? {
        guard
            let id = object.id,
            let kindRaw = object.kind,
            let kind = UserPreferenceKind(rawValue: kindRaw),
            let value = object.value,
            let createdAt = object.createdAt
        else {
            return nil
        }
        return UserPreference(id: id, kind: kind, value: value, note: object.note, createdAt: createdAt)
    }

    static func apply(_ preference: UserPreference, to object: CDUserPreference) {
        object.id = preference.id
        object.kind = preference.kind.rawValue
        object.value = preference.value
        object.note = preference.note
        object.createdAt = preference.createdAt
    }
}

enum WorkoutEntryMapper {
    static func map(_ object: CDWorkoutEntry) -> WorkoutEntry? {
        guard let id = object.id, let name = object.name, let date = object.date else { return nil }
        return WorkoutEntry(
            id: id,
            name: name,
            durationMinutes: object.durationMinutes,
            caloriesBurned: object.caloriesBurned,
            date: date
        )
    }

    static func apply(_ entry: WorkoutEntry, to object: CDWorkoutEntry) {
        object.id = entry.id
        object.name = entry.name
        object.durationMinutes = entry.durationMinutes
        object.caloriesBurned = entry.caloriesBurned
        object.date = entry.date
    }
}

enum ProgressPhotoMapper {
    static func map(_ object: CDProgressPhoto) -> ProgressPhoto? {
        guard
            let id = object.id,
            let fileName = object.fileName,
            let kindRaw = object.kind,
            let date = object.date
        else {
            return nil
        }
        let pose = ProgressPhotoPose(rawValue: object.pose ?? "")
            ?? (kindRaw == "side" ? .side : .front)
        return ProgressPhoto(
            id: id,
            fileName: fileName,
            kind: ProgressPhotoKind(storedRawValue: kindRaw),
            pose: pose,
            note: object.note,
            date: date,
            fileURL: nil
        )
    }

    static func apply(_ photo: ProgressPhoto, to object: CDProgressPhoto) {
        object.id = photo.id
        object.fileName = photo.fileName
        object.kind = photo.kind.rawValue
        object.pose = photo.pose.rawValue
        object.note = photo.note
        object.date = photo.date
    }
}

enum ChatMessageMapper {
    static func map(_ object: CDChatMessage) -> ChatHistoryMessage? {
        guard
            let id = object.id,
            let role = object.role,
            let content = object.content,
            let createdAt = object.createdAt
        else {
            return nil
        }
        return ChatHistoryMessage(id: id, role: role, content: content, createdAt: createdAt)
    }

    static func apply(_ message: ChatHistoryMessage, to object: CDChatMessage) {
        object.id = message.id
        object.role = message.role
        object.content = message.content
        object.createdAt = message.createdAt
    }
}

enum RewardStateMapper {
    static func map(_ object: CDRewardState) -> RewardState {
        let badges: [String]
        if let raw = object.unlockedBadgeIDsJSON,
           let data = raw.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            badges = decoded
        } else {
            badges = []
        }
        return RewardState(
            totalXP: Int(object.totalXP),
            currentStreak: Int(object.currentStreak),
            longestStreak: Int(object.longestStreak),
            lastFoodLogDay: object.lastFoodLogDay,
            unlockedBadgeIDs: badges,
            updatedAt: object.updatedAt ?? Date()
        )
    }

    static func apply(_ state: RewardState, to object: CDRewardState) {
        if object.id == nil {
            object.id = UUID()
        }
        object.totalXP = Int32(state.totalXP)
        object.currentStreak = Int32(state.currentStreak)
        object.longestStreak = Int32(state.longestStreak)
        object.lastFoodLogDay = state.lastFoodLogDay
        object.updatedAt = state.updatedAt
        if let data = try? JSONEncoder().encode(state.unlockedBadgeIDs) {
            object.unlockedBadgeIDsJSON = String(data: data, encoding: .utf8)
        }
    }
}

enum XPEventMapper {
    static func map(_ object: CDXPEvent) -> XPEvent? {
        guard
            let id = object.id,
            let kindRaw = object.kind,
            let kind = XPEventKind(rawValue: kindRaw),
            let date = object.date
        else {
            return nil
        }
        return XPEvent(id: id, kind: kind, amount: Int(object.amount), date: date, relatedID: object.relatedID)
    }

    static func apply(_ event: XPEvent, to object: CDXPEvent) {
        object.id = event.id
        object.kind = event.kind.rawValue
        object.amount = Int32(event.amount)
        object.date = event.date
        object.relatedID = event.relatedID
    }
}
