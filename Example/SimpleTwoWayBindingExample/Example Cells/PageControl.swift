//
//  PageControl.swift
//  SimpleTwoWayBindingExample
//
//  Created by Alin Radut on 12/06/2020.
//  Copyright © 2020 Ryan Forsythe. All rights reserved.
//

import Foundation
import SimpleTwoWayBinding
import UIKit

class PageControlCell: UITableViewCell {
    lazy var pageControl: UIPageControl = {
        let s = UIPageControl()
        s.translatesAutoresizingMaskIntoConstraints = false
        s.accessibilityIdentifier = "pageControl"
        s.numberOfPages = 5
        s.tintColor = .darkGray
        s.pageIndicatorTintColor = .lightGray
        s.currentPageIndicatorTintColor = .blue
        return s
    }()
    
    lazy var info: UILabel = {
        let l = label("This is a page control", testID: "pageControlInformation")
        l.font = .preferredFont(forTextStyle: .footnote)
        return l
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        let stack = vstackOf([pageControl, info])
        contentView.addSubview(stack)
        constrain(stack, toEdgesOf: contentView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension PageControlCell: CellInformation {
    static var reuseIdentifier: String { "pageControlCell" }
    static var cellHeight: CGFloat { 80 }
}

extension PageControlCell: ViewModelBindable {
    func bind(to viewModel: S2WBExampleViewModel) {
        pageControl.bind(with: viewModel.pageControlIndex)
        info.bind(with: viewModel.pageControlDescription)
    }
}
