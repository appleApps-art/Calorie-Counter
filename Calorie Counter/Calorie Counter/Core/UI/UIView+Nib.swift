import UIKit

extension UIView {
    func embedNibContent() {
        let name = String(describing: type(of: self))
        let nib = UINib(nibName: name, bundle: Bundle(for: type(of: self)))
        guard let content = nib.instantiate(withOwner: self, options: nil).first as? UIView else { return }
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: topAnchor),
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
            content.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}
