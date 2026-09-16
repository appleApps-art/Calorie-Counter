import UIKit

final class MealRowView: UIControl {
    @IBOutlet private weak var iconBackgroundView: AdaptiveView!
    @IBOutlet private weak var iconImageView: UIImageView!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var goalLabel: AdaptiveLabel!

    private(set) var mealType: MealType = .breakfast

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func configure(_ item: HomeMealItem) {
        mealType = item.mealType
        titleLabel.text = item.title
        goalLabel.text = item.goalText
        iconBackgroundView.backgroundColor = item.mealType.iconBackgroundColor
        iconImageView.image = UIImage(systemName: item.mealType.systemImageName)
        iconImageView.tintColor = item.mealType.iconTintColor
    }

    private func commonInit() {
        backgroundColor = .clear
        embedNibContent()
        subviews.first?.isUserInteractionEnabled = false
    }
}

private extension MealType {
    var systemImageName: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snacks: return "carrot.fill"
        }
    }

    var iconBackgroundColor: UIColor {
        switch self {
        case .breakfast: return AppColor.breakfast
        case .lunch: return AppColor.lunch
        case .dinner: return AppColor.dinner
        case .snacks: return AppColor.snacks
        }
    }

    var iconTintColor: UIColor {
        switch self {
        case .breakfast: return UIColor(red: 1, green: 0.62, blue: 0.18, alpha: 1)
        case .lunch: return AppColor.carbs
        case .dinner: return UIColor(red: 0.45, green: 0.4, blue: 0.95, alpha: 1)
        case .snacks: return AppColor.primary
        }
    }
}
