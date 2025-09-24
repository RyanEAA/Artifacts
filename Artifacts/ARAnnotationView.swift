import UIKit

final class ARAnnotationView: UIView, UITextFieldDelegate {
	// Callbacks
	var onCommit: ((String) -> Void)?
	var onRequestEdit: (() -> Void)?

	private let label = UILabel()
	private let textField = UITextField()
	private var currentText: String

	init(text: String) {
		self.currentText = text
		let size = CGSize(width: 160, height: 36)
		super.init(frame: CGRect(origin: .zero, size: size))
		commonInit()
		label.text = text
	}
	required init?(coder: NSCoder) { fatalError("init(coder:)") }

	private func commonInit() {
		layer.cornerRadius = 8
		layer.masksToBounds = true

		// blurred background
		let blur = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
		blur.frame = bounds
		blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		addSubview(blur)

		label.frame = bounds
		label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		label.textAlignment = .center
		label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
		label.textColor = .white
		addSubview(label)

		textField.frame = bounds.insetBy(dx: 8, dy: 4)
		textField.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		textField.font = label.font
		textField.textColor = label.textColor
		textField.backgroundColor = UIColor.clear
		textField.delegate = self
		textField.isHidden = true
		addSubview(textField)

		// add border
		layer.borderWidth = 0.5
		layer.borderColor = UIColor(white: 1, alpha: 0.15).cgColor
	}

	@objc func handleTap(_ recognizer: UITapGestureRecognizer) {
		// request to edit
		onRequestEdit?()
		beginEditing()
	}

	func beginEditing() {
		textField.text = currentText
		textField.isHidden = false
		label.isHidden = true
		textField.becomeFirstResponder()
	}

	func endEditingAndCommit() {
		let newText = (textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
		currentText = newText.isEmpty ? currentText : newText
		label.text = currentText
		textField.resignFirstResponder()
		textField.isHidden = true
		label.isHidden = false
		onCommit?(currentText)
	}

	// UITextFieldDelegate
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		endEditingAndCommit()
		return true
	}

	func textFieldDidEndEditing(_ textField: UITextField) {
		endEditingAndCommit()
	}
}
