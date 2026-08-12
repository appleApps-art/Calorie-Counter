import Foundation

protocol AppSettingsStoring: AnyObject {
    var settings: AppSettings { get set }
}

final class AppSettingsStore: AppSettingsStoring {
    private let defaults: UserDefaults
    private let key = "avo.app.settings"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var settings: AppSettings {
        get {
            guard let data = defaults.data(forKey: key),
                  let decoded = try? JSONDecoder().decode(AppSettings.self, from: data)
            else {
                return .default
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: key)
            }
        }
    }
}

protocol LocalImageFileStoring {
    func saveJPEG(_ data: Data, fileName: String) throws -> URL
    func url(for fileName: String) -> URL
    func delete(fileName: String) throws
    func fileExists(fileName: String) -> Bool
}

typealias ProgressPhotoFileStoring = LocalImageFileStoring

final class LocalImageFileStore: LocalImageFileStoring {
    private let directory: URL

    init(folderName: String, fileManager: FileManager = .default) {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        directory = base.appendingPathComponent(folderName, isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func saveJPEG(_ data: Data, fileName: String) throws -> URL {
        let url = url(for: fileName)
        try data.write(to: url, options: .atomic)
        return url
    }

    func url(for fileName: String) -> URL {
        directory.appendingPathComponent(fileName)
    }

    func delete(fileName: String) throws {
        try FileManager.default.removeItem(at: url(for: fileName))
    }

    func fileExists(fileName: String) -> Bool {
        FileManager.default.fileExists(atPath: url(for: fileName).path)
    }
}
