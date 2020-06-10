//
//  ProgressView.swift
//  SimpleTwoWayBindingExample
//
//  Created by Alin Radut on 10/06/2020.
//  Copyright © 2020 Ryan Forsythe. All rights reserved.
//

import Foundation
import SimpleTwoWayBinding
import UIKit

class ProgressViewCell: UITableViewCell {
    lazy var progressView: UIProgressView = {
        let s = UIProgressView()
        s.translatesAutoresizingMaskIntoConstraints = false
        s.accessibilityIdentifier = "progressView"
        return s
    }()
    
    lazy var info: UILabel = {
        let l = label("This is a progress view which observes the slider", testID: "progressViewInformation")
        l.font = .preferredFont(forTextStyle: .footnote)
        return l
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        let stack = vstackOf([progressView, info])
        contentView.addSubview(stack)
        constrain(stack, toEdgesOf: contentView)
        NSLayoutConstraint.activate([
            progressView.leftAnchor.constraint(equalToSystemSpacingAfter: contentView.leftAnchor, multiplier: 1),
            contentView.rightAnchor.constraint(equalToSystemSpacingAfter: progressView.rightAnchor, multiplier: 1)
        ])
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension ProgressViewCell: CellInformation {
    static var reuseIdentifier: String { "progressView" }
    static var cellHeight: CGFloat { 90 }
}

extension ProgressViewCell: ViewModelBindable {
    func bind(to viewModel: S2WBExampleViewModel) {
        progressView.bind(with: viewModel.sliderPosition)
    }
}
