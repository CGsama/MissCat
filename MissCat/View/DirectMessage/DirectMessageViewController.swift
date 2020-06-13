//
//  DirectMessageViewController.swift
//  MissCat
//
//  Created by Yuiga Wada on 2020/04/16.
//  Copyright © 2020 Yuiga Wada. All rights reserved.
//

import RxCocoa
import RxSwift
import UIKit

class DirectMessageViewController: ChatViewController {
    var homeViewController: HomeViewController?
    private var viewModel: DirectMessageViewModel?
    private let disposeBag = DisposeBag()
    
    func setup(userId: String? = nil, groupId: String? = nil, owner: SecureUser) {
        let viewModel: DirectMessageViewModel = .init(with: .init(owner: owner,
                                                                  userId: userId ?? "",
                                                                  sendTrigger: sendTrigger),
                                                      and: disposeBag)
        
        binding(with: viewModel)
        viewModel.load()
        self.viewModel = viewModel
    }
    
    private func binding(with viewModel: DirectMessageViewModel) {
        let output = viewModel.output
        output.messages.bind(to: messages).disposed(by: disposeBag)
        output.sendCompleted.bind(to: sendCompleted).disposed(by: disposeBag)
        
        tapTrigger.subscribe(onNext: { link in
            switch link.type {
            case .url:
                self.homeViewController?.openLink(url: link.value)
            case .hashtag:
                self.navigationController?.popViewController(animated: true)
                self.homeViewController?.emulateFooterTabTap(tab: .home)
                self.homeViewController?.searchHashtag(tag: link.value)
            case .mention:
                self.homeViewController?.openUserPage(username: link.value, owner: viewModel.state.owner)
            }
        }).disposed(by: disposeBag)
        
        loadTrigger.subscribe(onNext: {
            viewModel.load {
                self.endRefreshing()
            }
        }).disposed(by: disposeBag)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setTheme()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    private func setTheme() {
        if let colorPattern = Theme.shared.currentModel?.colorPattern.ui {
            view.backgroundColor = colorPattern.base
        }
    }
}
