//
//  PlaceholderTableView.swift
//  MissCat
//
//  Created by Yuiga Wada on 2020/04/18.
//  Copyright © 2020 Yuiga Wada. All rights reserved.
//

import RxSwift
import UIKit

class PlaceholderTableView: UITableView {
    private let disposeBag: DisposeBag = .init()
    
    override func layoutSubviews() {
        super.layoutSubviews()
        showPlaceholder()
    }
    
    private func showPlaceholder() {
        guard numberOfSections > 0 else { return }
        let placeholder = preparePlaceholder()
        
        let num = numberOfRows(inSection: 0)
        if num == 0 {
            guard !contains(placeholder) else { return }
            
            backgroundView = placeholder
            setAutoLayout(to: placeholder)
        } else {
            placeholder.removeFromSuperview()
        }
    }
    
    private func preparePlaceholder() -> UIView {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "placeholder")
        guard let view = viewController.view else { return .init() }
        
        view.frame = frame
        view.translatesAutoresizingMaskIntoConstraints = false
        
        return view
    }
    
    private func setAutoLayout(to view: UIView) {
        addConstraints([
            NSLayoutConstraint(item: self,
                               attribute: .width,
                               relatedBy: .equal,
                               toItem: view,
                               attribute: .width,
                               multiplier: 1.0,
                               constant: 0),
            
            NSLayoutConstraint(item: self,
                               attribute: .height,
                               relatedBy: .equal,
                               toItem: view,
                               attribute: .height,
                               multiplier: 1.0,
                               constant: 0),
            
            NSLayoutConstraint(item: self,
                               attribute: .centerX,
                               relatedBy: .equal,
                               toItem: view,
                               attribute: .centerX,
                               multiplier: 1.0,
                               constant: 0),
            
            NSLayoutConstraint(item: self,
                               attribute: .centerY,
                               relatedBy: .equal,
                               toItem: view,
                               attribute: .centerY,
                               multiplier: 1.0,
                               constant: 0)
        ])
    }
}
