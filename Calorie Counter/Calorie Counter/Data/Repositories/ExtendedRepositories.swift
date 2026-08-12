import CoreData
import Foundation

protocol UserProfileRepositoryProtocol {
    func fetchProfile() throws -> UserProfile
    func save(_ profile: UserProfile) throws
}

final class UserProfileRepository: UserProfileRepositoryProtocol {
    private let coreDataStack: CoreDataStack

    init(coreDataStack: CoreDataStack) {
        self.coreDataStack = coreDataStack
    }

    func fetchProfile() throws -> UserProfile {
        let context = coreDataStack.viewContext
        let request = CDUserProfile.fetchRequest()
        request.fetchLimit = 1
        if let object = try context.fetch(request).first, let mapped = UserProfileMapper.map(object) {
            return mapped
        }
        let profile = UserProfile.empty
        let object = CDUserProfile(context: context)
        UserProfileMapper.apply(profile, to: object)
        try coreDataStack.saveContext()
        return profile
    }

    func save(_ profile: UserProfile) throws {
        let context = coreDataStack.viewContext
        let request = CDUserProfile.fetchRequest()
        request.fetchLimit = 1
        let object = try context.fetch(request).first ?? CDUserProfile(context: context)
        var toSave = profile
        toSave.updatedAt = Date()
        if object.id != nil, let existing = object.id {
            toSave.id = existing
        }
        UserProfileMapper.apply(toSave, to: object)
        try coreDataStack.saveContext()
    }
}

protocol UserPreferenceRepositoryProtocol {
    func fetchAll() throws -> [UserPreference]
    func save(_ preference: UserPreference) throws
    func delete(id: UUID) throws
}

final class UserPreferenceRepository: UserPreferenceRepositoryProtocol {
    private let coreDataStack: CoreDataStack

    init(coreDataStack: CoreDataStack) {
        self.coreDataStack = coreDataStack
    }

    func fetchAll() throws -> [UserPreference] {
        let context = coreDataStack.viewContext
        let request = CDUserPreference.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        return try context.fetch(request).compactMap(UserPreferenceMapper.map)
    }

    func save(_ preference: UserPreference) throws {
        let context = coreDataStack.viewContext
        let request = CDUserPreference.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", preference.id as CVarArg)
        let object = try context.fetch(request).first ?? CDUserPreference(context: context)
        UserPreferenceMapper.apply(preference, to: object)
        try coreDataStack.saveContext()
    }

    func delete(id: UUID) throws {
        let context = coreDataStack.viewContext
        let request = CDUserPreference.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        if let object = try context.fetch(request).first {
            context.delete(object)
            try coreDataStack.saveContext()
        }
    }
}

protocol WorkoutEntryRepositoryProtocol {
    func fetchEntries(from start: Date, to end: Date) throws -> [WorkoutEntry]
    func fetchEntries() throws -> [WorkoutEntry]
    func save(_ entry: WorkoutEntry) throws
    func delete(id: UUID) throws
}

final class WorkoutEntryRepository: WorkoutEntryRepositoryProtocol {
    private let coreDataStack: CoreDataStack

    init(coreDataStack: CoreDataStack) {
        self.coreDataStack = coreDataStack
    }

    func fetchEntries() throws -> [WorkoutEntry] {
        let context = coreDataStack.viewContext
        let request = CDWorkoutEntry.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        return try context.fetch(request).compactMap(WorkoutEntryMapper.map)
    }

    func fetchEntries(from start: Date, to end: Date) throws -> [WorkoutEntry] {
        let context = coreDataStack.viewContext
        let request = CDWorkoutEntry.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", start as NSDate, end as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        return try context.fetch(request).compactMap(WorkoutEntryMapper.map)
    }

    func save(_ entry: WorkoutEntry) throws {
        let context = coreDataStack.viewContext
        let request = CDWorkoutEntry.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", entry.id as CVarArg)
        let object = try context.fetch(request).first ?? CDWorkoutEntry(context: context)
        WorkoutEntryMapper.apply(entry, to: object)
        try coreDataStack.saveContext()
    }

    func delete(id: UUID) throws {
        let context = coreDataStack.viewContext
        let request = CDWorkoutEntry.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        if let object = try context.fetch(request).first {
            context.delete(object)
            try coreDataStack.saveContext()
        }
    }
}

protocol ProgressPhotoRepositoryProtocol {
    func fetchAll() throws -> [ProgressPhoto]
    func save(_ photo: ProgressPhoto) throws
    func delete(id: UUID) throws
}

final class ProgressPhotoRepository: ProgressPhotoRepositoryProtocol {
    private let coreDataStack: CoreDataStack

    init(coreDataStack: CoreDataStack) {
        self.coreDataStack = coreDataStack
    }

    func fetchAll() throws -> [ProgressPhoto] {
        let context = coreDataStack.viewContext
        let request = CDProgressPhoto.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        return try context.fetch(request).compactMap(ProgressPhotoMapper.map)
    }

    func save(_ photo: ProgressPhoto) throws {
        let context = coreDataStack.viewContext
        let request = CDProgressPhoto.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", photo.id as CVarArg)
        let object = try context.fetch(request).first ?? CDProgressPhoto(context: context)
        ProgressPhotoMapper.apply(photo, to: object)
        try coreDataStack.saveContext()
    }

    func delete(id: UUID) throws {
        let context = coreDataStack.viewContext
        let request = CDProgressPhoto.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        if let object = try context.fetch(request).first {
            context.delete(object)
            try coreDataStack.saveContext()
        }
    }
}

protocol ChatHistoryRepositoryProtocol {
    func fetchRecent(limit: Int) throws -> [ChatHistoryMessage]
    func append(_ message: ChatHistoryMessage) throws
    func replaceAll(_ messages: [ChatHistoryMessage]) throws
}

final class ChatHistoryRepository: ChatHistoryRepositoryProtocol {
    private let coreDataStack: CoreDataStack

    init(coreDataStack: CoreDataStack) {
        self.coreDataStack = coreDataStack
    }

    func fetchRecent(limit: Int) throws -> [ChatHistoryMessage] {
        let context = coreDataStack.viewContext
        let request = CDChatMessage.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        let all = try context.fetch(request).compactMap(ChatMessageMapper.map)
        if all.count <= limit {
            return all
        }
        return Array(all.suffix(limit))
    }

    func append(_ message: ChatHistoryMessage) throws {
        let context = coreDataStack.viewContext
        let object = CDChatMessage(context: context)
        ChatMessageMapper.apply(message, to: object)
        try coreDataStack.saveContext()
    }

    func replaceAll(_ messages: [ChatHistoryMessage]) throws {
        let context = coreDataStack.viewContext
        let request = CDChatMessage.fetchRequest()
        let existing = try context.fetch(request)
        existing.forEach(context.delete)
        for message in messages {
            let object = CDChatMessage(context: context)
            ChatMessageMapper.apply(message, to: object)
        }
        try coreDataStack.saveContext()
    }
}

protocol RewardsRepositoryProtocol {
    func fetchState() throws -> RewardState
    func save(_ state: RewardState) throws
    func fetchEvents() throws -> [XPEvent]
    func append(_ event: XPEvent) throws
}

final class RewardsRepository: RewardsRepositoryProtocol {
    private let coreDataStack: CoreDataStack

    init(coreDataStack: CoreDataStack) {
        self.coreDataStack = coreDataStack
    }

    func fetchState() throws -> RewardState {
        let context = coreDataStack.viewContext
        let request = CDRewardState.fetchRequest()
        request.fetchLimit = 1
        if let object = try context.fetch(request).first {
            return RewardStateMapper.map(object)
        }
        let state = RewardState.empty
        let object = CDRewardState(context: context)
        RewardStateMapper.apply(state, to: object)
        try coreDataStack.saveContext()
        return state
    }

    func save(_ state: RewardState) throws {
        let context = coreDataStack.viewContext
        let request = CDRewardState.fetchRequest()
        request.fetchLimit = 1
        let object = try context.fetch(request).first ?? CDRewardState(context: context)
        RewardStateMapper.apply(state, to: object)
        try coreDataStack.saveContext()
    }

    func fetchEvents() throws -> [XPEvent] {
        let context = coreDataStack.viewContext
        let request = CDXPEvent.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        return try context.fetch(request).compactMap(XPEventMapper.map)
    }

    func append(_ event: XPEvent) throws {
        let context = coreDataStack.viewContext
        let object = CDXPEvent(context: context)
        XPEventMapper.apply(event, to: object)
        try coreDataStack.saveContext()
    }
}
