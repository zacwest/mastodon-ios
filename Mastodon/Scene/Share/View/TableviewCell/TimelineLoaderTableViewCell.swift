//
//  TimelineLoaderTableViewCell.swift
//  Mastodon
//
//  Created by sxiaojian on 2021/2/3.
//

import UIKit
import Combine

class TimelineLoaderTableViewCell: UITableViewCell {
    
    static let buttonHeight: CGFloat = 44
    static let buttonMargin: CGFloat = 12
    static let cellHeight: CGFloat = buttonHeight + 2 * buttonMargin
    static let labelFont = UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: 17, weight: .medium))
    
    var disposeBag = Set<AnyCancellable>()

    private var _disposeBag = Set<AnyCancellable>()
        
    let stackView = UIStackView()

    let loadMoreButton: UIButton = {
        let button = HighlightDimmableButton()
        button.titleLabel?.font = TimelineLoaderTableViewCell.labelFont
        button.setTitleColor(ThemeService.tintColor, for: .normal)
        button.setTitle(L10n.Common.Controls.Timeline.Loader.loadMissingPosts, for: .normal)
        button.setTitle("", for: .disabled)
        return button
    }()
    
    let loadMoreLabel: UILabel = {
        let label = UILabel()
        label.font = TimelineLoaderTableViewCell.labelFont
        return label
    }()
    
    let activityIndicatorView: UIActivityIndicatorView = {
        let activityIndicatorView = UIActivityIndicatorView(style: .medium)
        activityIndicatorView.tintColor = Asset.Colors.Label.secondary.color
        activityIndicatorView.hidesWhenStopped = true
        return activityIndicatorView
    }()
    
    override func prepareForReuse() {
        super.prepareForReuse()
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
    
    func startAnimating() {
        activityIndicatorView.startAnimating()
        self.loadMoreButton.isEnabled = false
        self.loadMoreLabel.textColor = Asset.Colors.Label.secondary.color
        self.loadMoreLabel.text = L10n.Common.Controls.Timeline.Loader.loadingMissingPosts
    }
    
    func stopAnimating() {
        activityIndicatorView.stopAnimating()
        self.loadMoreButton.isEnabled = true
        self.loadMoreLabel.textColor = ThemeService.tintColor
        self.loadMoreLabel.text = ""
    }
    
    func _init() {
        selectionStyle = .none
        backgroundColor = .clear
        
        loadMoreButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(loadMoreButton)
        NSLayoutConstraint.activate([
            loadMoreButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: TimelineLoaderTableViewCell.buttonMargin),
            loadMoreButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: loadMoreButton.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: loadMoreButton.bottomAnchor, constant: TimelineLoaderTableViewCell.buttonMargin),
            loadMoreButton.heightAnchor.constraint(equalToConstant: TimelineLoaderTableViewCell.buttonHeight).priority(.required - 1),
        ])
        
        // use stack view to alignment content center
        stackView.spacing = 4
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.isUserInteractionEnabled = false
        contentView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: loadMoreButton.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: loadMoreButton.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: loadMoreButton.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: loadMoreButton.bottomAnchor),
        ])
        let leftPaddingView = UIView()
        leftPaddingView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(leftPaddingView)
        stackView.addArrangedSubview(activityIndicatorView)
        stackView.addArrangedSubview(loadMoreLabel)
        let rightPaddingView = UIView()
        rightPaddingView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(rightPaddingView)
        NSLayoutConstraint.activate([
            leftPaddingView.widthAnchor.constraint(equalTo: rightPaddingView.widthAnchor, multiplier: 1.0),
        ])
        
        // default set hidden and let subclass override it
        loadMoreButton.isHidden = true
        loadMoreLabel.isHidden = true
        activityIndicatorView.isHidden = true

        setupBackgroundColor(theme: ThemeService.shared.currentTheme.value)
        ThemeService.shared.currentTheme
            .receive(on: RunLoop.main)
            .sink { [weak self] theme in
                guard let self = self else { return }
                self.setupBackgroundColor(theme: theme)
            }
            .store(in: &_disposeBag)
    }

    private func setupBackgroundColor(theme: Theme) {
        loadMoreButton.backgroundColor = theme.tableViewCellBackgroundColor
    }
    
}
