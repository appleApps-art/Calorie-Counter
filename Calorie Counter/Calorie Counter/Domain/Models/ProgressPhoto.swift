import Foundation

enum ProgressPhotoPose: String, Codable, CaseIterable, Equatable {
    case front
    case side

    var title: String {
        switch self {
        case .front: return L10n.tr("pose.front")
        case .side: return L10n.tr("pose.side")
        }
    }
}

enum ProgressPhotoKind: String, Codable, CaseIterable, Equatable {
    case baseline
    case progress

    init(storedRawValue: String) {
        switch storedRawValue {
        case ProgressPhotoKind.baseline.rawValue, "before", "front", "side":
            self = .baseline
        default:
            self = .progress
        }
    }
}

struct ProgressPhoto: Identifiable, Equatable {
    let id: UUID
    let fileName: String
    let kind: ProgressPhotoKind
    let pose: ProgressPhotoPose
    let note: String?
    let date: Date
    var fileURL: URL?
}

struct ProgressPhotoPair: Equatable {
    var front: ProgressPhoto?
    var side: ProgressPhoto?

    var isComplete: Bool {
        front != nil && side != nil
    }

    static let empty = ProgressPhotoPair(front: nil, side: nil)

    static func from(_ photos: [ProgressPhoto]) -> ProgressPhotoPair {
        ProgressPhotoPair(
            front: photos.last(where: { $0.pose == .front }),
            side: photos.last(where: { $0.pose == .side })
        )
    }
}
