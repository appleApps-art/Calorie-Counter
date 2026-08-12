import UIKit

final class AIAssistantViewController: BaseViewController {
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var conversationTextView: UITextView!
    @IBOutlet private weak var inputTextField: UITextField!
    @IBOutlet private weak var sendButton: UIButton!
    @IBOutlet private weak var statusLabel: UILabel!

    private let viewModel: AIAssistantViewModel

    init(viewModel: AIAssistantViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "AIAssistantViewController")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        inputTextField.placeholder = L10n.tr("ai.placeholder")
        sendButton.setTitle(L10n.tr("common.send"), for: .normal)
        inputTextField.addTarget(self, action: #selector(inputChanged), for: .editingChanged)
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
    }

    override func bindViewModel() {
        viewModel.titleText.bind { [weak self] value in
            self?.titleLabel.text = value
        }
        viewModel.conversationText.bind { [weak self] value in
            self?.conversationTextView.text = value
            self?.scrollConversationToBottom()
        }
        viewModel.inputText.bind { [weak self] value in
            guard self?.inputTextField.text != value else { return }
            self?.inputTextField.text = value
        }
        viewModel.statusText.bind { [weak self] value in
            self?.statusLabel.text = value
        }
        viewModel.isSending.bind { [weak self] isSending in
            self?.sendButton.isEnabled = !isSending
            self?.inputTextField.isEnabled = !isSending
        }
        viewModel.pendingWaterConfirmText.bind { [weak self] message in
            guard let self, let message else { return }
            self.presentWaterConfirmAlert(message: message)
        }
    }

    @objc
    private func inputChanged() {
        viewModel.updateInput(inputTextField.text ?? "")
    }

    @objc
    private func sendTapped() {
        view.endEditing(true)
        viewModel.sendTapped()
    }

    private func presentWaterConfirmAlert(message: String) {
        let alert = UIAlertController(title: L10n.tr("ai.alert.waterTitle"), message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.tr("common.cancel"), style: .cancel) { [weak self] _ in
            self?.viewModel.rejectPendingWaterLog()
        })
        alert.addAction(UIAlertAction(title: L10n.tr("common.confirm"), style: .default) { [weak self] _ in
            self?.viewModel.confirmPendingWaterLog()
        })
        present(alert, animated: true)
    }

    private func scrollConversationToBottom() {
        guard conversationTextView.text.isEmpty == false else { return }
        let bottom = NSRange(location: conversationTextView.text.count - 1, length: 1)
        conversationTextView.scrollRangeToVisible(bottom)
    }
}
