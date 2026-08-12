import Foundation

final class SaveUserPreferenceUseCase {
    private let userPreferenceRepository: UserPreferenceRepositoryProtocol

    init(userPreferenceRepository: UserPreferenceRepositoryProtocol) {
        self.userPreferenceRepository = userPreferenceRepository
    }

    func execute(kind: UserPreferenceKind, value: String, note: String? = nil) throws -> UserPreference {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PreferenceError.emptyValue
        }
        let preference = UserPreference(
            id: UUID(),
            kind: kind,
            value: trimmed,
            note: note,
            createdAt: Date()
        )
        try userPreferenceRepository.save(preference)
        return preference
    }
}

final class FetchUserPreferencesUseCase {
    private let userPreferenceRepository: UserPreferenceRepositoryProtocol

    init(userPreferenceRepository: UserPreferenceRepositoryProtocol) {
        self.userPreferenceRepository = userPreferenceRepository
    }

    func execute() throws -> UserPreferenceProfile {
        UserPreferenceProfile(preferences: try userPreferenceRepository.fetchAll())
    }
}

enum PreferenceError: LocalizedError {
    case emptyValue

    var errorDescription: String? {
        switch self {
        case .emptyValue:
            return L10n.tr("preference.empty")
        }
    }
}

final class LogWorkoutUseCase {
    private let workoutEntryRepository: WorkoutEntryRepositoryProtocol
    private let awardXPUseCase: AwardXPUseCase?
    private let healthSync: HealthSyncing?
    private let appSettingsStore: AppSettingsStoring?

    init(
        workoutEntryRepository: WorkoutEntryRepositoryProtocol,
        awardXPUseCase: AwardXPUseCase? = nil,
        healthSync: HealthSyncing? = nil,
        appSettingsStore: AppSettingsStoring? = nil
    ) {
        self.workoutEntryRepository = workoutEntryRepository
        self.awardXPUseCase = awardXPUseCase
        self.healthSync = healthSync
        self.appSettingsStore = appSettingsStore
    }

    func execute(
        name: String,
        durationMinutes: Double,
        caloriesBurned: Double,
        date: Date = Date()
    ) throws -> WorkoutEntry {
        let entry = WorkoutEntry(
            id: UUID(),
            name: name,
            durationMinutes: durationMinutes,
            caloriesBurned: caloriesBurned,
            date: date
        )
        try workoutEntryRepository.save(entry)
        try awardXPUseCase?.execute(kind: .workout, relatedID: entry.id)
        let settings = appSettingsStore?.settings
        if settings?.healthSyncEnabled == true, settings?.healthSyncWorkouts == true {
            Task {
                try? await healthSync?.saveWorkout(entry)
            }
        }
        return entry
    }
}

final class SaveProgressPhotoUseCase {
    private let progressPhotoRepository: ProgressPhotoRepositoryProtocol
    private let fileStore: ProgressPhotoFileStoring
    private let awardXPUseCase: AwardXPUseCase?

    init(
        progressPhotoRepository: ProgressPhotoRepositoryProtocol,
        fileStore: ProgressPhotoFileStoring,
        awardXPUseCase: AwardXPUseCase? = nil
    ) {
        self.progressPhotoRepository = progressPhotoRepository
        self.fileStore = fileStore
        self.awardXPUseCase = awardXPUseCase
    }

    func execute(
        imageData: Data,
        kind: ProgressPhotoKind,
        pose: ProgressPhotoPose,
        note: String? = nil,
        date: Date = Date(),
        awardsXP: Bool = true
    ) throws -> ProgressPhoto {
        guard !imageData.isEmpty else {
            throw ProgressPhotoError.emptyImage
        }
        let id = UUID()
        let fileName = "\(id.uuidString).jpg"
        _ = try fileStore.saveJPEG(imageData, fileName: fileName)
        let photo = ProgressPhoto(
            id: id,
            fileName: fileName,
            kind: kind,
            pose: pose,
            note: note,
            date: date,
            fileURL: fileStore.url(for: fileName)
        )
        try progressPhotoRepository.save(photo)
        if awardsXP {
            try awardXPUseCase?.execute(kind: .progressPhoto, relatedID: id)
        }
        return photo
    }
}

final class DeleteProgressPhotoUseCase {
    private let progressPhotoRepository: ProgressPhotoRepositoryProtocol
    private let fileStore: ProgressPhotoFileStoring

    init(
        progressPhotoRepository: ProgressPhotoRepositoryProtocol,
        fileStore: ProgressPhotoFileStoring
    ) {
        self.progressPhotoRepository = progressPhotoRepository
        self.fileStore = fileStore
    }

    func execute(_ photo: ProgressPhoto) throws {
        try progressPhotoRepository.delete(id: photo.id)
        try? fileStore.delete(fileName: photo.fileName)
    }
}

final class DeleteUserPreferenceUseCase {
    private let userPreferenceRepository: UserPreferenceRepositoryProtocol

    init(userPreferenceRepository: UserPreferenceRepositoryProtocol) {
        self.userPreferenceRepository = userPreferenceRepository
    }

    func execute(id: UUID) throws {
        try userPreferenceRepository.delete(id: id)
    }
}

final class ImportHealthWeightUseCase {
    private let healthSync: HealthSyncing
    private let logWeightUseCase: LogWeightUseCase

    init(healthSync: HealthSyncing, logWeightUseCase: LogWeightUseCase) {
        self.healthSync = healthSync
        self.logWeightUseCase = logWeightUseCase
    }

    func execute() async throws -> WeightEntry? {
        guard let kilograms = try await healthSync.fetchLatestWeight() else {
            return nil
        }
        return try logWeightUseCase.execute(weightKilograms: kilograms)
    }
}

enum ProgressPhotoError: LocalizedError {
    case emptyImage

    var errorDescription: String? {
        switch self {
        case .emptyImage:
            return L10n.tr("progress.photoEmpty")
        }
    }
}

final class FetchProgressPhotosUseCase {
    private let progressPhotoRepository: ProgressPhotoRepositoryProtocol
    private let fileStore: ProgressPhotoFileStoring

    init(
        progressPhotoRepository: ProgressPhotoRepositoryProtocol,
        fileStore: ProgressPhotoFileStoring
    ) {
        self.progressPhotoRepository = progressPhotoRepository
        self.fileStore = fileStore
    }

    func execute() throws -> [ProgressPhoto] {
        try progressPhotoRepository.fetchAll().map { photo in
            var copy = photo
            if fileStore.fileExists(fileName: photo.fileName) {
                copy.fileURL = fileStore.url(for: photo.fileName)
            }
            return copy
        }
    }

    func baselinePair() throws -> ProgressPhotoPair {
        let photos = try execute()
            .filter { $0.kind == .baseline }
            .sorted { $0.date < $1.date }
        return ProgressPhotoPair.from(photos)
    }

    func latestPair() throws -> ProgressPhotoPair {
        let photos = try execute().sorted { $0.date < $1.date }
        return ProgressPhotoPair.from(photos)
    }
}

final class SaveBaselineBodyPhotoUseCase {
    private let saveProgressPhotoUseCase: SaveProgressPhotoUseCase
    private let fetchProgressPhotosUseCase: FetchProgressPhotosUseCase
    private let deleteProgressPhotoUseCase: DeleteProgressPhotoUseCase

    init(
        saveProgressPhotoUseCase: SaveProgressPhotoUseCase,
        fetchProgressPhotosUseCase: FetchProgressPhotosUseCase,
        deleteProgressPhotoUseCase: DeleteProgressPhotoUseCase
    ) {
        self.saveProgressPhotoUseCase = saveProgressPhotoUseCase
        self.fetchProgressPhotosUseCase = fetchProgressPhotosUseCase
        self.deleteProgressPhotoUseCase = deleteProgressPhotoUseCase
    }

    func execute(imageData: Data, pose: ProgressPhotoPose) throws -> ProgressPhotoPair {
        let existing = try fetchProgressPhotosUseCase.execute().filter {
            $0.kind == .baseline && $0.pose == pose
        }
        let hadPhoto = !existing.isEmpty
        for photo in existing {
            try deleteProgressPhotoUseCase.execute(photo)
        }
        _ = try saveProgressPhotoUseCase.execute(
            imageData: imageData,
            kind: .baseline,
            pose: pose,
            awardsXP: !hadPhoto
        )
        return try fetchProgressPhotosUseCase.baselinePair()
    }
}

final class DeleteBaselineBodyPhotoUseCase {
    private let fetchProgressPhotosUseCase: FetchProgressPhotosUseCase
    private let deleteProgressPhotoUseCase: DeleteProgressPhotoUseCase

    init(
        fetchProgressPhotosUseCase: FetchProgressPhotosUseCase,
        deleteProgressPhotoUseCase: DeleteProgressPhotoUseCase
    ) {
        self.fetchProgressPhotosUseCase = fetchProgressPhotosUseCase
        self.deleteProgressPhotoUseCase = deleteProgressPhotoUseCase
    }

    func execute(pose: ProgressPhotoPose) throws -> ProgressPhotoPair {
        let existing = try fetchProgressPhotosUseCase.execute().filter {
            $0.kind == .baseline && $0.pose == pose
        }
        for photo in existing {
            try deleteProgressPhotoUseCase.execute(photo)
        }
        return try fetchProgressPhotosUseCase.baselinePair()
    }
}
