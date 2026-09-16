import UIKit
import XCTest
@testable import Calorie_Counter

@MainActor
final class SettingsRowAdaptiveTests: XCTestCase {
    func testLongToggleTitleWrapsBeforeTheSwitchOnSmallPhones() throws {
        let title = "Нагадувати щодня про заплановані прийоми їжі"
        for width: CGFloat in [320, 375] {
            let (controller, row) = makeRow(width: width)
            row.configure(title: title, accessory: .none, showsSeparator: false)
            row.configureToggle(isOn: true)
            fit(row, in: controller)

            let label = try XCTUnwrap(descendants(of: row).compactMap { $0 as? UILabel }.first { $0.text == title })
            let toggle = try XCTUnwrap(descendants(of: row).compactMap { $0 as? UISwitch }.first { !$0.isHidden })
            let textFrame = label.convert(label.bounds, to: row)
            let controlFrame = toggle.convert(toggle.bounds, to: row)
            XCTAssertLessThanOrEqual(textFrame.maxX + 7, controlFrame.minX, "width \(width)")
            assertFullyVisible(label, in: row)
            XCTAssertGreaterThan(row.bounds.height, 52)
        }
    }

    func testUnitsControlRetainsItsSpaceBesideLongTitle() throws {
        let title = "Одиниці вимірювання показників"
        for width: CGFloat in [320, 375] {
            let (controller, row) = makeRow(width: width)
            row.configure(title: title, accessory: .none, showsSeparator: false)
            row.configureUnits(isMetric: true)
            fit(row, in: controller)

            let label = try XCTUnwrap(descendants(of: row).compactMap { $0 as? UILabel }.first { $0.text == title })
            let control = try XCTUnwrap(descendants(of: row).compactMap { $0 as? UISegmentedControl }.first { !$0.isHidden })
            XCTAssertLessThanOrEqual(label.convert(label.bounds, to: row).maxX + 7, control.convert(control.bounds, to: row).minX)
            assertFullyVisible(label, in: row)
        }
    }

    func testOrdinaryRowHasReadableTitleDetailAndFortyFourPointMinimum() throws {
        let title = "Поточна вага"
        let detail = "Немає записів за останні 30 днів"
        for width: CGFloat in [320, 375, 744] {
            let (controller, row) = makeRow(width: width)
            row.configure(title: title, detail: detail, accessory: .disclosure, showsSeparator: true)
            fit(row, in: controller)
            XCTAssertGreaterThanOrEqual(row.bounds.height, 44)
            for text in [title, detail] {
                let label = try XCTUnwrap(descendants(of: row).compactMap { $0 as? UILabel }.first { $0.text == text })
                XCTAssertGreaterThan(label.bounds.width, 60)
                assertFullyVisible(label, in: row)
            }
        }
    }

    func testReconfiguredRowReleasesSpaceReservedForHiddenControl() throws {
        let title = "Довга назва звичайного пункту налаштувань"
        let (controller, row) = makeRow(width: 375)
        row.configure(title: title, accessory: .none, showsSeparator: false)
        row.configureUnits(isMetric: true)
        fit(row, in: controller)
        let label = try XCTUnwrap(descendants(of: row).compactMap { $0 as? UILabel }.first { $0.text == title })
        let unitsTitleWidth = label.bounds.width
        row.configure(title: title, accessory: .disclosure, showsSeparator: false)
        fit(row, in: controller)
        XCTAssertGreaterThan(label.bounds.width, unitsTitleWidth + 80)
        assertFullyVisible(label, in: row)
    }

    func testAccountRowsTruncateWithoutGrowingAndCopyShowsConfirmation() throws {
        for width: CGFloat in [320, 375] {
            let (controller, row) = makeRow(width: width)
            let identifier = "C460D96B-0DD5-427B-84BA-9E19708D7CA1"
            row.configure(title: "ID користувача", detail: identifier, accessory: .copy, showsSeparator: true)
            row.useSingleLineLayout()
            fit(row, in: controller)
            XCTAssertLessThanOrEqual(row.bounds.height, 53)
            let labels = descendants(of: row).compactMap { $0 as? UILabel }
            XCTAssertTrue(labels.allSatisfy { $0.numberOfLines == 1 })
            var copied = false
            row.onCopy = { copied = true }
            let button = try XCTUnwrap(descendants(of: row).compactMap { $0 as? UIButton }.first { !$0.isHidden })
            button.sendActions(for: .touchUpInside)
            XCTAssertTrue(copied)
            XCTAssertTrue(labels.contains { $0.text == L10n.tr("settings.userIDCopied") })
            row.configure(title: "Синхронізація Apple Health", detail: "Відключено", accessory: .disclosure, showsSeparator: false)
            row.useSingleLineLayout()
            fit(row, in: controller)
            XCTAssertLessThanOrEqual(row.bounds.height, 53)
            XCTAssertTrue(labels.allSatisfy { $0.numberOfLines == 1 })
        }
    }

    func testPickerSelectionKeepsRowsAndTheirGeometryInBothThemes() {
        for style: UIUserInterfaceStyle in [.light, .dark] {
            for titles in [["Схуднути", "Підтримувати вагу", "Набрати вагу"], ["Системна", "Світла", "Темна"]] {
                let controller = SettingsOptionPickerViewController(
                    title: "Налаштування",
                    options: titles.enumerated().map { .init(title: $0.element, isSelected: $0.offset == 0) },
                    analyticsScreen: .settingsTheme,
                    onSave: { _ in }
                )
                controller.overrideUserInterfaceStyle = style
                controller.loadViewIfNeeded()
                controller.view.frame = CGRect(x: 0, y: 0, width: 402, height: 813)
                controller.view.refreshAdaptiveLayout()
                controller.view.layoutIfNeeded()
                let rows = descendants(of: controller.view).compactMap { $0 as? SettingsRowView }
                XCTAssertEqual(rows.count, 3)
                let frames = rows.map { $0.frame }
                for selected in [1, 2, 0, 2, 1] {
                    rows[selected].onTap?()
                    controller.view.setNeedsLayout()
                    controller.view.layoutIfNeeded()
                    let current = descendants(of: controller.view).compactMap { $0 as? SettingsRowView }
                    XCTAssertEqual(current.map(ObjectIdentifier.init), rows.map(ObjectIdentifier.init))
                    XCTAssertEqual(current.map { $0.frame }, frames)
                    for (index, row) in current.enumerated() {
                        XCTAssertEqual(row.bounds.height, 52, accuracy: 0.1)
                        XCTAssertEqual(row.accessibilityTraits.contains(.selected), index == selected)
                    }
                }
            }
        }
    }

    private func makeRow(width: CGFloat) -> (UIViewController, SettingsRowView) {
        let controller = UIViewController()
        controller.view.frame = CGRect(x: 0, y: 0, width: width, height: 667)
        let row = SettingsRowView(frame: CGRect(x: 0, y: 0, width: width, height: 52))
        controller.view.addSubview(row)
        return (controller, row)
    }

    private func fit(_ row: SettingsRowView, in controller: UIViewController) {
        controller.view.refreshAdaptiveLayout()
        let size = row.systemLayoutSizeFitting(
            CGSize(width: controller.view.bounds.width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        row.frame.size = size
        row.setNeedsLayout()
        row.layoutIfNeeded()
    }

    private func assertFullyVisible(_ label: UILabel, in row: UIView, file: StaticString = #filePath, line: UInt = #line) {
        let neededHeight = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)).height
        XCTAssertGreaterThanOrEqual(label.bounds.height + 1, neededHeight, file: file, line: line)
        let frame = label.convert(label.bounds, to: row)
        XCTAssertGreaterThanOrEqual(frame.minY, 9, file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxY, row.bounds.height - 9, file: file, line: line)
    }

    private func descendants(of view: UIView) -> [UIView] {
        view.subviews.flatMap { [$0] + descendants(of: $0) }
    }
}
