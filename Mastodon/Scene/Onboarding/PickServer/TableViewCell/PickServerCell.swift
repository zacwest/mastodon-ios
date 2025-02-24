//
//  PickServerCell.swift
//  Mastodon
//
//  Created by BradGao on 2021/2/24.
//

import os.log
import UIKit
import Combine
import MastodonSDK
import AlamofireImage
import Kanna

protocol PickServerCellDelegate: AnyObject {
    func pickServerCell(_ cell: PickServerCell, expandButtonPressed button: UIButton)
}

class PickServerCell: UITableViewCell {
    
    weak var delegate: PickServerCellDelegate?
    
    var disposeBag = Set<AnyCancellable>()
    
    let expandMode = CurrentValueSubject<ExpandMode, Never>(.collapse)
    
    let containerView: UIView = {
        let view = UIView()
        view.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 10, right: 16)
        view.backgroundColor = Asset.Theme.Mastodon.secondaryGroupedSystemBackground.color
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    let domainLabel: UILabel = {
        let label = UILabel()
        label.font = UIFontMetrics(forTextStyle: .headline).scaledFont(for: .systemFont(ofSize: 17, weight: .semibold), maximumPointSize: 22)
        label.textColor = Asset.Colors.Label.primary.color
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let checkbox: UIImageView = {
        let imageView = UIImageView()
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .body)
        imageView.tintColor = Asset.Colors.Label.secondary.color
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: 15, weight: .regular))
        label.numberOfLines = 0
        label.textColor = Asset.Colors.Label.primary.color
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let thumbnailActivityIndicator = UIActivityIndicatorView(style: .medium)
    
    let thumbnailImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    let infoStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    let expandBox: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    let expandButton: UIButton = {
        let button = HitTestExpandedButton(type: .custom)
        button.setImage(UIImage(systemName: "chevron.down", withConfiguration: UIImage.SymbolConfiguration(pointSize: 13)), for: .normal)
        button.setTitle(L10n.Scene.ServerPicker.Button.seeMore, for: .normal)
        button.setTitleColor(Asset.Colors.brandBlue.color, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 13, weight: .regular)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.imageView?.transform = CGAffineTransform(scaleX: -1, y: 1)
        button.titleLabel?.transform = CGAffineTransform(scaleX: -1, y: 1)
        button.transform = CGAffineTransform(scaleX: -1, y: 1)
        return button
    }()
    
    let separator: UIView = {
        let view = UIView()
        view.backgroundColor = Asset.Theme.Mastodon.systemGroupedBackground.color
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    let langValueLabel: UILabel = {
        let label = UILabel()
        label.textColor = Asset.Colors.Label.primary.color
        label.font = UIFontMetrics(forTextStyle: .headline).scaledFont(for: .systemFont(ofSize: 22, weight: .semibold), maximumPointSize: 27)
        label.textAlignment = .center
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let usersValueLabel: UILabel = {
        let label = UILabel()
        label.textColor = Asset.Colors.Label.primary.color
        label.font = UIFontMetrics(forTextStyle: .headline).scaledFont(for: .systemFont(ofSize: 22, weight: .semibold), maximumPointSize: 27)
        label.textAlignment = .center
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let categoryValueLabel: UILabel = {
        let label = UILabel()
        label.textColor = Asset.Colors.Label.primary.color
        label.font = UIFontMetrics(forTextStyle: .headline).scaledFont(for: .systemFont(ofSize: 22, weight: .semibold), maximumPointSize: 27)
        label.textAlignment = .center
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let langTitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = Asset.Colors.Label.primary.color
        label.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: .systemFont(ofSize: 11, weight: .regular), maximumPointSize: 16)
        label.text = L10n.Scene.ServerPicker.Label.language
        label.textAlignment = .center
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let usersTitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = Asset.Colors.Label.primary.color
        label.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: .systemFont(ofSize: 11, weight: .regular), maximumPointSize: 16)
        label.text = L10n.Scene.ServerPicker.Label.users
        label.textAlignment = .center
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let categoryTitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = Asset.Colors.Label.primary.color
        label.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: .systemFont(ofSize: 11, weight: .regular), maximumPointSize: 16)
        label.text = L10n.Scene.ServerPicker.Label.category
        label.textAlignment = .center
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private var collapseConstraints: [NSLayoutConstraint] = []
    private var expandConstraints: [NSLayoutConstraint] = []
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        thumbnailImageView.isHidden = false
        thumbnailImageView.af.cancelImageRequest()
        thumbnailActivityIndicator.stopAnimating()
        disposeBag.removeAll()
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        _init()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        _init()
    }
    
}

// MARK: - Methods to configure appearance
extension PickServerCell {
    private func _init() {
        selectionStyle = .none
        backgroundColor = .clear
        configureMargin()
        
        contentView.addSubview(containerView)
        containerView.addSubview(domainLabel)
        containerView.addSubview(checkbox)
        containerView.addSubview(descriptionLabel)
        containerView.addSubview(separator)
        
        containerView.addSubview(expandButton)
        
        // Always add the expandbox which contains elements only visible in expand mode
        containerView.addSubview(expandBox)
        expandBox.addSubview(thumbnailImageView)
        expandBox.addSubview(infoStackView)
        expandBox.isHidden = true
        
        let verticalInfoStackViewLang = makeVerticalInfoStackView(arrangedView: langValueLabel, langTitleLabel)
        let verticalInfoStackViewUsers = makeVerticalInfoStackView(arrangedView: usersValueLabel, usersTitleLabel)
        let verticalInfoStackViewCategory = makeVerticalInfoStackView(arrangedView: categoryValueLabel, categoryTitleLabel)
        infoStackView.addArrangedSubview(verticalInfoStackViewLang)
        infoStackView.addArrangedSubview(verticalInfoStackViewUsers)
        infoStackView.addArrangedSubview(verticalInfoStackViewCategory)
        
        let expandButtonTopConstraintInCollapse = expandButton.topAnchor.constraint(equalTo: descriptionLabel.lastBaselineAnchor, constant: 12).priority(.required - 1)
        collapseConstraints.append(expandButtonTopConstraintInCollapse)
        
        let expandButtonTopConstraintInExpand = expandButton.topAnchor.constraint(equalTo: expandBox.bottomAnchor, constant: 8).priority(.defaultHigh)
        expandConstraints.append(expandButtonTopConstraintInExpand)
        
        NSLayoutConstraint.activate([
            // Set background view
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            contentView.layoutMarginsGuide.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            // Set bottom separator
            separator.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: separator.trailingAnchor),
            containerView.topAnchor.constraint(equalTo: separator.topAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1).priority(.defaultHigh),
            
            domainLabel.topAnchor.constraint(equalTo: containerView.layoutMarginsGuide.topAnchor),
            domainLabel.leadingAnchor.constraint(equalTo: containerView.layoutMarginsGuide.leadingAnchor),
            
            checkbox.widthAnchor.constraint(equalToConstant: 23),
            checkbox.heightAnchor.constraint(equalToConstant: 22),
            containerView.layoutMarginsGuide.trailingAnchor.constraint(equalTo: checkbox.trailingAnchor),
            checkbox.leadingAnchor.constraint(equalTo: domainLabel.trailingAnchor, constant: 16),
            checkbox.centerYAnchor.constraint(equalTo: domainLabel.centerYAnchor),
            
            descriptionLabel.leadingAnchor.constraint(equalTo: containerView.layoutMarginsGuide.leadingAnchor),
            descriptionLabel.topAnchor.constraint(equalTo: domainLabel.bottomAnchor, constant: 8),
            containerView.layoutMarginsGuide.trailingAnchor.constraint(equalTo: descriptionLabel.trailingAnchor),
            
            // Set expandBox constraints
            expandBox.leadingAnchor.constraint(equalTo: containerView.layoutMarginsGuide.leadingAnchor),
            containerView.layoutMarginsGuide.trailingAnchor.constraint(equalTo: expandBox.trailingAnchor),
            expandBox.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 8),
            expandBox.bottomAnchor.constraint(equalTo: infoStackView.bottomAnchor).priority(.defaultHigh),
            
            thumbnailImageView.topAnchor.constraint(equalTo: expandBox.topAnchor),
            thumbnailImageView.leadingAnchor.constraint(equalTo: expandBox.leadingAnchor),
            expandBox.trailingAnchor.constraint(equalTo: thumbnailImageView.trailingAnchor),
            thumbnailImageView.heightAnchor.constraint(equalTo: thumbnailImageView.widthAnchor, multiplier: 151.0 / 303.0).priority(.defaultHigh),
            
            infoStackView.leadingAnchor.constraint(equalTo: expandBox.leadingAnchor),
            expandBox.trailingAnchor.constraint(equalTo: infoStackView.trailingAnchor),
            infoStackView.topAnchor.constraint(equalTo: thumbnailImageView.bottomAnchor, constant: 16),
            
            expandButton.leadingAnchor.constraint(equalTo: containerView.layoutMarginsGuide.leadingAnchor),
            containerView.layoutMarginsGuide.trailingAnchor.constraint(equalTo: expandButton.trailingAnchor),
            containerView.layoutMarginsGuide.bottomAnchor.constraint(equalTo: expandButton.bottomAnchor),
        ])
        
        thumbnailActivityIndicator.translatesAutoresizingMaskIntoConstraints = false
        thumbnailImageView.addSubview(thumbnailActivityIndicator)
        NSLayoutConstraint.activate([
            thumbnailActivityIndicator.centerXAnchor.constraint(equalTo: thumbnailImageView.centerXAnchor),
            thumbnailActivityIndicator.centerYAnchor.constraint(equalTo: thumbnailImageView.centerYAnchor),
        ])
        thumbnailActivityIndicator.hidesWhenStopped = true
        thumbnailActivityIndicator.stopAnimating()
        
        NSLayoutConstraint.activate(collapseConstraints)
        
        domainLabel.setContentHuggingPriority(.required - 1, for: .vertical)
        domainLabel.setContentCompressionResistancePriority(.required - 1, for: .vertical)
        descriptionLabel.setContentHuggingPriority(.required - 2, for: .vertical)
        descriptionLabel.setContentCompressionResistancePriority(.required - 2, for: .vertical)
        
        expandButton.addTarget(self, action: #selector(expandButtonDidPressed(_:)), for: .touchUpInside)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        configureMargin()
    }
    
    private func makeVerticalInfoStackView(arrangedView: UIView...) -> UIStackView {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.distribution = .equalCentering
        stackView.spacing = 2
        arrangedView.forEach { stackView.addArrangedSubview($0) }
        return stackView
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        if selected {
            checkbox.image = UIImage(systemName: "checkmark.circle.fill")
        } else {
            checkbox.image = UIImage(systemName: "circle")
        }
    }
    
    @objc
    private func expandButtonDidPressed(_ sender: UIButton) {
        os_log(.info, log: .debug, "%{public}s[%{public}ld], %{public}s", ((#file as NSString).lastPathComponent), #line, #function)
        delegate?.pickServerCell(self, expandButtonPressed: sender)
    }
}

extension PickServerCell {
    private func configureMargin() {
        switch traitCollection.horizontalSizeClass {
        case .regular:
            let margin = MastodonPickServerViewController.viewEdgeMargin
            contentView.layoutMargins = UIEdgeInsets(top: 0, left: margin, bottom: 0, right: margin)
        default:
            contentView.layoutMargins = .zero
        }
    }
}

extension PickServerCell {
    
    enum ExpandMode {
        case collapse
        case expand
    }
    
    func updateExpandMode(mode: ExpandMode) {
        switch mode {
        case .collapse:
            expandButton.setImage(UIImage(systemName: "chevron.down", withConfiguration: UIImage.SymbolConfiguration(pointSize: 13)), for: .normal)
            expandButton.setTitle(L10n.Scene.ServerPicker.Button.seeMore, for: .normal)
            expandBox.isHidden = true
            expandButton.isSelected = false
            NSLayoutConstraint.deactivate(expandConstraints)
            NSLayoutConstraint.activate(collapseConstraints)
        case .expand:
            expandButton.setImage(UIImage(systemName: "chevron.up", withConfiguration: UIImage.SymbolConfiguration(pointSize: 13)), for: .normal)
            expandButton.setTitle(L10n.Scene.ServerPicker.Button.seeLess, for: .normal)
            expandBox.isHidden = false
            expandButton.isSelected = true
            NSLayoutConstraint.activate(expandConstraints)
            NSLayoutConstraint.deactivate(collapseConstraints)
        }
        
        expandMode.value = mode
    }
    
}
