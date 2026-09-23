import UIKit

final class ChangeDateSheetViewController: BaseViewController {
    override var analyticsScreen: AnalyticsScreen? { .changeDate }

    @IBOutlet private weak var closeButton: UIButton!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var calendarHost: UIView!
    @IBOutlet private weak var selectButton: UIButton!

    var onClose: (() -> Void)?
    var onSelect: ((Date) -> Void)?
    var onSelectDates: (([Date]) -> Void)?

    private let maximumDate: Date?
    private let initialDates: [Date]
    private let allowsMultipleSelection: Bool
    private var selectedDates: [Date]
    private var calendarView: UICalendarView?
    private var didInstallCalendar = false

    convenience init(date: Date, maximumDate: Date? = nil) {
        self.init(dates: [date], allowsMultipleSelection: false, maximumDate: maximumDate)
    }

    init(dates: [Date], allowsMultipleSelection: Bool, maximumDate: Date? = nil) {
        let lastDay = maximumDate.map { Calendar.current.startOfDay(for: $0) }
        self.maximumDate = lastDay
        let normalized = Self.normalizedDates(dates.map { date in
            lastDay.map { min(date, $0) } ?? date
        })
        initialDates = normalized
        selectedDates = normalized
        self.allowsMultipleSelection = allowsMultipleSelection
        super.init(nibName: "ChangeDateSheetViewController")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        applySheetBackground(AppColor.sheetGlassTint)
        titleLabel.text = L10n.tr("product.entry.changeDateTitle")
        titleLabel.textAlignment = .center
        OnboardingStyle.lockFigmaFont(titleLabel, size: 17, weight: .semibold, color: AppColor.labelVibrantPrimary, kern: -0.43)
        OnboardingStyle.styleGlassSymbolButton(closeButton, systemName: "xmark", foregroundColor: AppColor.iconSecondary)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        OnboardingStyle.stylePrimaryButton(selectButton, title: L10n.tr("product.entry.selectDate"))
        selectButton.addTarget(self, action: #selector(selectTapped), for: .touchUpInside)
        calendarHost.backgroundColor = AppColor.backgroundsPrimary
        calendarHost.layer.cornerRadius = 13
        calendarHost.layer.cornerCurve = .continuous
        calendarHost.clipsToBounds = true
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        installCalendarIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        installCalendarIfNeeded()
    }

    @objc private func closeTapped() {
        onClose?()
    }

    @objc private func selectTapped() {
        let dates = selectedDates.isEmpty ? initialDates : selectedDates
        guard dates.allSatisfy(isAllowedDate) else { return }
        if allowsMultipleSelection {
            onSelectDates?(dates)
        } else if let date = dates.first {
            onSelect?(date)
        }
    }

    private func installCalendarIfNeeded() {
        guard !didInstallCalendar else { return }
        guard view.window != nil else { return }
        guard calendarHost.bounds.width > 1, calendarHost.bounds.height > 1 else { return }
        didInstallCalendar = true

        let calendarView = UICalendarView()
        calendarView.calendar = .current
        calendarView.locale = .current
        if let maximumDate, let day = Calendar.current.dateInterval(of: .day, for: maximumDate) {
            calendarView.availableDateRange = DateInterval(
                start: calendarView.availableDateRange.start,
                end: day.end.addingTimeInterval(-1)
            )
        }
        calendarView.tintColor = AppColor.teal
        calendarView.backgroundColor = .clear
        calendarView.translatesAutoresizingMaskIntoConstraints = false
        calendarHost.addSubview(calendarView)
        NSLayoutConstraint.activate([
            calendarView.topAnchor.constraint(equalTo: calendarHost.topAnchor),
            calendarView.bottomAnchor.constraint(equalTo: calendarHost.bottomAnchor)
        ] + calendarView.horizontalConstraints(in: calendarHost, inset: 0))
        if allowsMultipleSelection {
            calendarView.selectionBehavior = UICalendarSelectionMultiDate(delegate: self)
        } else {
            calendarView.selectionBehavior = UICalendarSelectionSingleDate(delegate: self)
        }
        self.calendarView = calendarView
        DispatchQueue.main.async { [weak self] in
            self?.applyInitialSelection()
        }
    }

    private func applyInitialSelection() {
        guard let calendarView else { return }
        let components = selectedDates.map(Self.dayComponents(from:))
        if let first = components.first {
            calendarView.setVisibleDateComponents(first, animated: false)
        }
        if let selection = calendarView.selectionBehavior as? UICalendarSelectionMultiDate {
            selection.selectedDates = components
        } else if let selection = calendarView.selectionBehavior as? UICalendarSelectionSingleDate {
            selection.selectedDate = components.first
        }
    }

    private func isAllowedDate(_ date: Date) -> Bool {
        guard let maximumDate else { return true }
        return Calendar.current.startOfDay(for: date) <= maximumDate
    }

    private static func normalizedDates(_ dates: [Date]) -> [Date] {
        let unique = Array(Set(dates.map { Calendar.current.startOfDay(for: $0) })).sorted()
        return unique.isEmpty ? [Calendar.current.startOfDay(for: Date())] : unique
    }

    private static func dayComponents(from date: Date) -> DateComponents {
        var components = Calendar.current.dateComponents([.calendar, .era, .year, .month, .day], from: date)
        components.calendar = Calendar.current
        return components
    }

    private static func dates(from components: [DateComponents]) -> [Date] {
        let calendar = Calendar.current
        return Array(Set(components.compactMap { calendar.date(from: $0) }.map { calendar.startOfDay(for: $0) })).sorted()
    }
}

extension ChangeDateSheetViewController: UICalendarSelectionSingleDateDelegate {
    func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
        guard let dateComponents, let date = Calendar.current.date(from: dateComponents), isAllowedDate(date) else { return }
        selectedDates = [Calendar.current.startOfDay(for: date)]
    }
}

extension ChangeDateSheetViewController: UICalendarSelectionMultiDateDelegate {
    func multiDateSelection(_ selection: UICalendarSelectionMultiDate, didSelectDate dateComponents: DateComponents) {
        selectedDates = Self.dates(from: selection.selectedDates)
    }

    func multiDateSelection(_ selection: UICalendarSelectionMultiDate, didDeselectDate dateComponents: DateComponents) {
        selectedDates = Self.dates(from: selection.selectedDates)
    }

    func multiDateSelection(_ selection: UICalendarSelectionMultiDate, canDeselectDate dateComponents: DateComponents) -> Bool {
        selection.selectedDates.count > 1
    }
}
