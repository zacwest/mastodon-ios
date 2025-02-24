//
//  SuggestionAccountCollectionViewCell.swift
//  Mastodon
//
//  Created by sxiaojian on 2021/4/22.
//

import CoreDataStack
import Foundation
import UIKit

class SuggestionAccountCollectionViewCell: UICollectionViewCell {
    let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.tintColor = Asset.Colors.Label.tertiary.color
        imageView.layer.cornerRadius = 4
        imageView.clipsToBounds = true
        imageView.image = UIImage.placeholder(color: .systemFill)
        return imageView
    }()

    func configAsPlaceHolder() {
        imageView.tintColor = Asset.Colors.Label.tertiary.color
        imageView.image = UIImage.placeholder(color: .systemFill)
    }

    func config(with mastodonUser: MastodonUser) {
        imageView.af.setImage(
            withURL: URL(string: mastodonUser.avatar)!,
            placeholderImage: UIImage.placeholder(color: .systemFill),
            imageTransition: .crossDissolve(0.2)
        )
    }

    override func prepareForReuse() {
        super.prepareForReuse()
    }

    override init(frame: CGRect) {
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }
}

extension SuggestionAccountCollectionViewCell {
    private func configure() {
        contentView.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }
}
