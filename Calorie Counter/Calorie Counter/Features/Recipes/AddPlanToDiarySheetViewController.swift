import UIKit

/// Choosing which days a saved plan goes into the diary, as the design shows: the plan itself, a
/// calendar, and one button. A plan opened straight after it was made skips this — its day simply
/// goes in.
final class AddPlanToDiarySheetViewController: UIViewController, UICalendarSelectionMultiDateDelegate {
    private let plan: MealPlan
    private let calendar = Calendar.current

    private let closeButton = UIButton(type: .system)
    private let titleLabel = AdaptiveLabel()
    private let planCard = AdaptiveView()
    private let coverView = UIImageView()
    private let planTitleLabel = AdaptiveLabel()
    private let planSubtitleLabel = AdaptiveLabel()
    private let datesCard = AdaptiveView()
    private let datesTitleLabel = AdaptiveLabel()
    private let datesValueLabel = AdaptiveLabel()
    private let datesPillView = UIView()
    private let separatorView = UIView()
    private let calendarView = UICalendarView()
    private var selection: UICalendarSelectionMultiDate?
    private let addButton = UIButton(type: .system)
    private var selectedDates: [Date] = []

    var onAdd: (([Date]) -> Void)?
    var onClose: (() -> Void)?

    init(plan: MealPlan) {
        self.plan = plan
        let today = Calendar.current.startOfDay(for: Date())
        selectedDates = (0..<plan.dayCount).compactMap {
            Calendar.current.date(byAdding: .day, value: $0, to: today)
        }
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColor.sheetGlassTint
        build()
        renderDates()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        datesPillView.layer.cornerRadius = datesPillView.bounds.height / 2
        coverView.image = MealPlanCover.image(
            title: plan.title,
            size: coverView.bounds.size,
            traits: traitCollection
        )
    }

    func multiDateSelection(_ selection: UICalendarSelectionMultiDate, didSelectDate dateComponents: DateComponents) {
        publishDates(selection)
    }

    func multiDateSelection(_ selection: UICalendarSelectionMultiDate, didDeselectDate dateComponents: DateComponents) {
        publishDates(selection)
    }

    // MARK: - Building

    private func build() {
        OnboardingStyle.styleGlassSymbolButton(closeButton, systemName: "xmark", foregroundColor: AppColor.iconSecondary)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        titleLabel.text = L10n.tr("recipes.mealPlan.addToDiaryTitle")
        titleLabel.textAlignment = .center
        OnboardingStyle.lockFigmaFont(titleLabel, size: 17, weight: .semibold, color: AppColor.labelVibrantPrimary, kern: -0.43)
        OnboardingStyle.stylePrimaryButton(
            addButton,
            title: L10n.tr("recipes.mealPlan.addToDiaryConfirm"),
            systemImage: "plus"
        )
        addButton.addTarget(self, action: #selector(addTapped), for: .touchUpInside)

        buildPlanCard()
        buildDatesCard()

        [closeButton, titleLabel, planCard, datesCard, addButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            closeButton.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: .adaptWidth(16)),
            closeButton.topAnchor.constraint(equalTo: safe.topAnchor, constant: .adaptHeight(8)),
            closeButton.widthAnchor.constraint(equalToConstant: .adaptWidth(44)),
            closeButton.heightAnchor.constraint(equalToConstant: .adaptWidth(44)),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            planCard.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: .adaptHeight(16)),
            planCard.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: .adaptWidth(16)),
            planCard.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: .adaptWidth(-16)),
            datesCard.topAnchor.constraint(equalTo: planCard.bottomAnchor, constant: .adaptHeight(16)),
            datesCard.leadingAnchor.constraint(equalTo: planCard.leadingAnchor),
            datesCard.trailingAnchor.constraint(equalTo: planCard.trailingAnchor),
            addButton.topAnchor.constraint(greaterThanOrEqualTo: datesCard.bottomAnchor, constant: .adaptHeight(16)),
            addButton.leadingAnchor.constraint(equalTo: planCard.leadingAnchor),
            addButton.trailingAnchor.constraint(equalTo: planCard.trailingAnchor),
            addButton.heightAnchor.constraint(equalToConstant: .adaptHeight(50)),
            addButton.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: .adaptHeight(-8))
        ])
    }

    private func buildPlanCard() {
        planCard.useLiveGlass = false
        planCard.applyCardShadow = true
        planCard.cardFillColor = AppColor.backgroundsPrimaryElevated
        planCard.adaptCornerRadius = true
        planCard.designCornerRadius = 16
        coverView.contentMode = .scaleAspectFill
        coverView.clipsToBounds = true
        coverView.layer.cornerRadius = .adaptWidth(12)
        coverView.layer.cornerCurve = .continuous
        planTitleLabel.text = plan.title
        planTitleLabel.numberOfLines = 2
        OnboardingStyle.lockFigmaFont(planTitleLabel, size: 17, weight: .semibold, color: AppColor.labelsPrimary, kern: -0.43)
        planSubtitleLabel.text = plan.subtitle
        OnboardingStyle.lockFigmaFont(planSubtitleLabel, size: 15, weight: .regular, color: AppColor.labelsSecondary, kern: -0.23)

        let text = UIStackView(arrangedSubviews: [planTitleLabel, planSubtitleLabel])
        text.axis = .vertical
        text.spacing = .adaptHeight(2)
        [coverView, text].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            planCard.addSubview($0)
        }
        NSLayoutConstraint.activate([
            coverView.leadingAnchor.constraint(equalTo: planCard.leadingAnchor, constant: .adaptWidth(12)),
            coverView.topAnchor.constraint(equalTo: planCard.topAnchor, constant: .adaptHeight(12)),
            coverView.bottomAnchor.constraint(equalTo: planCard.bottomAnchor, constant: .adaptHeight(-12)),
            coverView.widthAnchor.constraint(equalToConstant: .adaptWidth(52)),
            coverView.heightAnchor.constraint(equalToConstant: .adaptWidth(52)),
            text.leadingAnchor.constraint(equalTo: coverView.trailingAnchor, constant: .adaptWidth(12)),
            text.trailingAnchor.constraint(equalTo: planCard.trailingAnchor, constant: .adaptWidth(-16)),
            text.centerYAnchor.constraint(equalTo: coverView.centerYAnchor)
        ])
    }

    private func buildDatesCard() {
        datesCard.useLiveGlass = false
        datesCard.applyCardShadow = true
        datesCard.cardFillColor = AppColor.backgroundsPrimaryElevated
        datesCard.adaptCornerRadius = true
        datesCard.designCornerRadius = 16

        let icon = UIImageView(image: UIImage(systemName: "calendar")?.withRenderingMode(.alwaysTemplate))
        icon.tintColor = AppColor.labelsPrimary
        icon.contentMode = .scaleAspectFit
        datesTitleLabel.text = L10n.tr("recipes.create.selectDates")
        OnboardingStyle.lockFigmaFont(datesTitleLabel, size: 17, weight: .regular, color: AppColor.labelsPrimary, kern: -0.43)
        OnboardingStyle.lockFigmaFont(datesValueLabel, size: 17, weight: .regular, color: AppColor.labelsPrimary, kern: -0.43)
        datesPillView.backgroundColor = AppColor.fillQuaternary
        datesPillView.isUserInteractionEnabled = false
        datesPillView.layer.cornerCurve = .continuous
        separatorView.backgroundColor = AppColor.separatorOnCard

        calendarView.calendar = calendar
        calendarView.locale = .autoupdatingCurrent
        calendarView.tintColor = AppColor.teal
        calendarView.backgroundColor = .clear
        calendarView.wantsDateDecorations = false
        let selection = UICalendarSelectionMultiDate(delegate: self)
        selection.setSelectedDates(selectedDates.map { calendar.dateComponents([.year, .month, .day], from: $0) }, animated: false)
        calendarView.selectionBehavior = selection
        self.selection = selection

        [icon, datesPillView, datesTitleLabel, datesValueLabel, separatorView, calendarView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            datesCard.addSubview($0)
        }
        datesCard.sendSubviewToBack(datesPillView)
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: datesCard.leadingAnchor, constant: .adaptWidth(16)),
            icon.topAnchor.constraint(equalTo: datesCard.topAnchor, constant: .adaptHeight(16)),
            icon.widthAnchor.constraint(equalToConstant: .adaptWidth(20)),
            icon.heightAnchor.constraint(equalToConstant: .adaptWidth(20)),
            datesTitleLabel.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: .adaptWidth(8)),
            datesTitleLabel.centerYAnchor.constraint(equalTo: icon.centerYAnchor),
            datesValueLabel.trailingAnchor.constraint(equalTo: datesCard.trailingAnchor, constant: .adaptWidth(-27)),
            datesValueLabel.centerYAnchor.constraint(equalTo: icon.centerYAnchor),
            datesPillView.leadingAnchor.constraint(equalTo: datesValueLabel.leadingAnchor, constant: .adaptWidth(-11)),
            datesPillView.trailingAnchor.constraint(equalTo: datesValueLabel.trailingAnchor, constant: .adaptWidth(11)),
            datesPillView.topAnchor.constraint(equalTo: datesValueLabel.topAnchor, constant: .adaptHeight(-6)),
            datesPillView.bottomAnchor.constraint(equalTo: datesValueLabel.bottomAnchor, constant: .adaptHeight(6)),
            separatorView.leadingAnchor.constraint(equalTo: datesCard.leadingAnchor),
            separatorView.trailingAnchor.constraint(equalTo: datesCard.trailingAnchor),
            separatorView.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: .adaptHeight(16)),
            separatorView.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),
            calendarView.topAnchor.constraint(equalTo: separatorView.bottomAnchor, constant: .adaptHeight(3)),
            calendarView.leadingAnchor.constraint(equalTo: datesCard.leadingAnchor),
            calendarView.trailingAnchor.constraint(equalTo: datesCard.trailingAnchor),
            calendarView.bottomAnchor.constraint(equalTo: datesCard.bottomAnchor, constant: .adaptHeight(-8))
        ])
    }

    // MARK: - Contents

    private func publishDates(_ selection: UICalendarSelectionMultiDate) {
        selectedDates = selection.selectedDates.compactMap { calendar.date(from: $0) }.sorted()
        renderDates()
    }

    private func renderDates() {
        datesValueLabel.text = MealPlanDatesText.summary(for: selectedDates)
        addButton.isEnabled = !selectedDates.isEmpty
        addButton.alpha = selectedDates.isEmpty ? 0.5 : 1
    }

    // MARK: - Actions

    @objc private func addTapped() {
        guard !selectedDates.isEmpty else { return }
        onAdd?(selectedDates)
    }

    @objc private func closeTapped() {
        onClose?()
    }
}

/// "Сьогодні, 24 жовт." for one day, "24–26 жовт." for a run of them.
enum MealPlanDatesText {
    static func summary(for dates: [Date]) -> String {
        let sorted = dates.sorted()
        guard let first = sorted.first else { return L10n.tr("recipes.create.selectDates") }
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("dMMM")
        guard sorted.count > 1, let last = sorted.last else {
            if Calendar.current.isDateInToday(first) {
                return L10n.format("recipes.mealPlan.datesToday", formatter.string(from: first))
            }
            return formatter.string(from: first)
        }
        let interval = DateIntervalFormatter()
        interval.locale = .autoupdatingCurrent
        interval.dateTemplate = "dMMM"
        return interval.string(from: first, to: last)
    }
}
