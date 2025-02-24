//
//  ProfileFieldView.swift
//  Mastodon
//
//  Created by MainasuK Cirno on 2021-3-30.
//

import UIKit
import Combine
import MetaTextKit

final class ProfileFieldView: UIView {
    
    var disposeBag = Set<AnyCancellable>()
    
    // output
    let name = PassthroughSubject<String, Never>()
    let value = PassthroughSubject<String, Never>()
    
    // for custom emoji display
    let titleMetaLabel = MetaLabel(style: .profileFieldName)
    
    // for editing
    let titleTextField: UITextField = {
        let textField = UITextField()
        textField.font = UIFontMetrics(forTextStyle: .headline).scaledFont(for: .systemFont(ofSize: 17, weight: .semibold), maximumPointSize: 20)
        textField.textColor = Asset.Colors.Label.primary.color
        textField.placeholder = L10n.Scene.Profile.Fields.Placeholder.label
        return textField
    }()
    
    // for custom emoji display
    let valueMetaLabel = MetaLabel(style: .profileFieldValue)
    
    // for editing
    let valueTextField: UITextField = {
        let textField = UITextField()
        textField.font = UIFontMetrics(forTextStyle: .headline).scaledFont(for: .systemFont(ofSize: 17, weight: .regular), maximumPointSize: 20)
        textField.textColor = Asset.Colors.Label.primary.color
        textField.placeholder = L10n.Scene.Profile.Fields.Placeholder.content
        textField.textAlignment = .right
        return textField
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        _init()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        _init()
    }
    
}

extension ProfileFieldView {
    private func _init() {
        
        let containerStackView = UIStackView()
        containerStackView.axis = .horizontal
        containerStackView.alignment = .center
        
        // note:
        // do not use readable layout guide to workaround SDK issue
        // otherwise, the `ProfileFieldCollectionViewCell` cannot display edit button and reorder icon
        containerStackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerStackView)
        NSLayoutConstraint.activate([
            containerStackView.topAnchor.constraint(equalTo: topAnchor),
            containerStackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerStackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerStackView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        titleMetaLabel.translatesAutoresizingMaskIntoConstraints = false
        containerStackView.addArrangedSubview(titleMetaLabel)
        NSLayoutConstraint.activate([
            titleMetaLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).priority(.defaultHigh),
        ])
        titleTextField.setContentHuggingPriority(.defaultLow - 1, for: .horizontal)
        titleTextField.translatesAutoresizingMaskIntoConstraints = false
        containerStackView.addArrangedSubview(titleTextField)
        NSLayoutConstraint.activate([
            titleTextField.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).priority(.defaultHigh),
        ])
        titleTextField.setContentHuggingPriority(.defaultLow - 1, for: .horizontal)
        
        valueMetaLabel.translatesAutoresizingMaskIntoConstraints = false
        containerStackView.addArrangedSubview(valueMetaLabel)
        NSLayoutConstraint.activate([
            valueMetaLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).priority(.defaultHigh),
        ])
        valueMetaLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        valueTextField.translatesAutoresizingMaskIntoConstraints = false
        containerStackView.addArrangedSubview(valueTextField)
        NSLayoutConstraint.activate([
            valueTextField.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).priority(.defaultHigh),
        ])
        
        titleTextField.isHidden = true
        valueTextField.isHidden = true
        
        NotificationCenter.default
            .publisher(for: UITextField.textDidChangeNotification, object: titleTextField)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.name.send(self.titleTextField.text ?? "")
            }
            .store(in: &disposeBag)
        
        NotificationCenter.default
            .publisher(for: UITextField.textDidChangeNotification, object: valueTextField)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.value.send(self.valueTextField.text ?? "")
            }
            .store(in: &disposeBag)
    }
}

#if canImport(SwiftUI) && DEBUG
import SwiftUI

struct ProfileFieldView_Previews: PreviewProvider {
    
    static var previews: some View {
        UIViewPreview(width: 375) {
            let filedView = ProfileFieldView()
            let content = PlaintextMetaContent(string: "https://mastodon.online")
            filedView.valueMetaLabel.configure(content: content)
            return filedView
        }
        .previewLayout(.fixed(width: 375, height: 100))
    }
    
}

#endif

