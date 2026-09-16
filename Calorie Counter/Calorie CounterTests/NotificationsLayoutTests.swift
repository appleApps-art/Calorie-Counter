import UIKit
import XCTest
@testable import Calorie_Counter

@MainActor
final class NotificationsLayoutTests: XCTestCase {
    func testBodyUsesFullContentWidthAndIconsStayRound() throws {
        let row = NotificationRowView()
        let item = NotificationInboxRow(id: "one", title: "A long notification title that must wrap",
            body: "Your protein is slightly lower than usual today. Adding almonds or Greek yogurt to your next snack is recommended.",
            timeText: "2h ago", date: Date(), symbolName: "drop.fill", imageName: nil)
        row.configure(item, showsSeparator: true)
        for width: CGFloat in [256, 338, 376] {
            let size = row.systemLayoutSizeFitting(CGSize(width: width, height: 0),
                withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
            row.frame = CGRect(origin: .zero, size: size)
            row.setNeedsLayout()
            row.layoutIfNeeded()
            let labels = descendants(row).compactMap { $0 as? UILabel }
            let body = try XCTUnwrap(labels.first { $0.text == item.body })
            let time = try XCTUnwrap(labels.first { $0.text == item.timeText })
            let title = try XCTUnwrap(labels.first { $0.text == item.title })
            XCTAssertEqual(body.frame.maxX, time.frame.maxX, accuracy: 0.5)
            XCTAssertGreaterThan(body.bounds.width, title.bounds.width)
            XCTAssertEqual(title.numberOfLines, 0)
            let icon = try XCTUnwrap(descendants(row).compactMap { $0 as? UIImageView }.first)
            let well = try XCTUnwrap(icon.superview)
            XCTAssertEqual(well.bounds.width, well.bounds.height, accuracy: 0.5)
            XCTAssertLessThanOrEqual(body.frame.maxY, row.bounds.height)
        }
        XCTAssertEqual(row.accessibilityCustomActions?.count, 1)
    }

    func testStandaloneInboxUsesSafeAreaAndBackNavigation() throws {
        let controller = NotificationsInboxViewController(viewModel: NotificationsInboxViewModel(
            inboxStore: QANotificationInboxStore(filled: false)))
        let navigation = UINavigationController(rootViewController: UIViewController())
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        navigation.pushViewController(controller, animated: false)
        window.layoutIfNeeded()
        controller.view.layoutIfNeeded()
        let table = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? UITableView }.first)
        XCTAssertNil(table.tableHeaderView)
        XCTAssertNil(table.tableFooterView)
        let back = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? UIButton }.first {
            $0.accessibilityLabel == L10n.tr("common.back")
        })
        let frame = back.convert(back.bounds, to: controller.view)
        XCTAssertGreaterThanOrEqual(frame.minY, controller.view.safeAreaInsets.top)
        XCTAssertEqual(frame.width, frame.height, accuracy: 0.5)
        XCTAssertTrue(controller.hidesBottomBarWhenPushed)
        back.sendActions(for: .touchUpInside)
        XCTAssertFalse(navigation.viewControllers.contains(controller))
    }

    func testSettingsUsesSheetAndPermissionHeader() throws {
        let controller = NotificationsInboxViewController(viewModel: NotificationsInboxViewModel(
            inboxStore: QANotificationInboxStore(filled: false)), settingsPresentation: true)
        controller.loadViewIfNeeded()
        let table = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? UITableView }.first)
        XCTAssertNotNil(table.tableHeaderView)
        XCTAssertNil(table.tableFooterView)
        XCTAssertEqual(controller.modalPresentationStyle, .pageSheet)
        XCTAssertEqual(controller.sheetPresentationController?.prefersGrabberVisible, true)
        XCTAssertEqual(controller.sheetPresentationController?.preferredCornerRadius, 38)
    }

    private func descendants(_ view: UIView) -> [UIView] {
        view.subviews.flatMap { [$0] + descendants($0) }
    }
}
