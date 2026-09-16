import UIKit

final class VoiceMicButtonChrome {
    private weak var button: UIButton?
    private var pulseWaves: [UIView] = []
    private var canConfirm = false

    func attach(_ button: UIButton) {
        self.button = button
    }

    func apply(isRecording: Bool, canConfirm: Bool) {
        guard let button else { return }
        self.canConfirm = canConfirm
        stopListeningAnimation()
        button.clipsToBounds = false
        button.layer.masksToBounds = false
        if canConfirm {
            styleConfirm(button)
            return
        }
        OnboardingStyle.stylePlainSymbolButton(
            button,
            systemName: "microphone",
            foregroundColor: isRecording ? AppColor.teal : AppColor.iconSecondary
        )
        button.imageView?.tintColor = isRecording ? AppColor.teal : AppColor.iconSecondary
        button.clipsToBounds = false
        button.layer.masksToBounds = false
        if isRecording {
            startListeningAnimation()
        }
    }

    func layoutIfNeeded() {
        guard canConfirm, let button, button.bounds.height > 1 else { return }
        button.layer.cornerRadius = button.bounds.height / 2
    }

    private func styleConfirm(_ button: UIButton) {
        let check = UIImage(
            systemName: "checkmark",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        )?.withTintColor(AppColor.onAccent, renderingMode: .alwaysOriginal)
        button.configuration = nil
        button.setTitle(nil, for: .normal)
        button.setImage(check, for: .normal)
        button.tintColor = AppColor.onAccent
        button.backgroundColor = AppColor.teal
        button.clipsToBounds = true
        button.layer.masksToBounds = true
        button.imageView?.contentMode = .center
        button.imageView?.clipsToBounds = false
        button.imageView?.tintColor = AppColor.onAccent
        button.layer.cornerCurve = .continuous
        button.layer.shadowOpacity = 0
        button.layer.cornerRadius = button.bounds.height / 2
        if button.bounds.height < 1 {
            button.layer.cornerRadius = .adaptWidth(14)
        }
        button.controlHaptic = .medium
        OnboardingStyle.applyPressFeedback(button)
    }

    private func startListeningAnimation() {
        guard let button else { return }
        installPulseWavesIfNeeded()
        pulseWaves.forEach { $0.isHidden = false }
        button.layoutIfNeeded()
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1
        pulse.toValue = 1.14
        pulse.duration = 0.72
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        if let imageView = button.imageView {
            imageView.layer.add(pulse, forKey: "micPulse")
        } else {
            button.layer.add(pulse, forKey: "micPulse")
        }
        pulseWaves.enumerated().forEach { index, wave in
            wave.layer.cornerRadius = wave.bounds.height / 2
            wave.layer.cornerCurve = .continuous
            let group = CAAnimationGroup()
            let scale = CABasicAnimation(keyPath: "transform.scale")
            scale.fromValue = 0.72
            scale.toValue = 1.55
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0.4
            fade.toValue = 0
            group.animations = [scale, fade]
            group.duration = 1.15
            group.repeatCount = .infinity
            group.beginTime = CACurrentMediaTime() + Double(index) * 0.38
            wave.layer.add(group, forKey: "wave")
        }
    }

    private func stopListeningAnimation() {
        guard let button else { return }
        button.imageView?.layer.removeAnimation(forKey: "micPulse")
        button.layer.removeAnimation(forKey: "micPulse")
        button.imageView?.transform = .identity
        button.transform = .identity
        pulseWaves.forEach { wave in
            wave.layer.removeAllAnimations()
            wave.removeFromSuperview()
        }
        pulseWaves.removeAll()
    }

    private func installPulseWavesIfNeeded() {
        guard pulseWaves.isEmpty, let button else { return }
        (0..<2).forEach { _ in
            let wave = UIView()
            wave.isUserInteractionEnabled = false
            wave.backgroundColor = .clear
            wave.layer.borderWidth = 1.5
            wave.layer.borderColor = AppColor.teal.withAlphaComponent(0.5).cgColor
            wave.translatesAutoresizingMaskIntoConstraints = false
            wave.isHidden = true
            button.insertSubview(wave, at: 0)
            NSLayoutConstraint.activate([
                wave.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                wave.centerYAnchor.constraint(equalTo: button.centerYAnchor),
                wave.widthAnchor.constraint(equalTo: button.widthAnchor),
                wave.heightAnchor.constraint(equalTo: button.heightAnchor)
            ])
            pulseWaves.append(wave)
        }
    }
}
