//
//  AccountsListViewModel.swift
//  MissCat
//
//  Created by Yuiga Wada on 2020/06/08.
//  Copyright © 2020 Yuiga Wada. All rights reserved.
//

import MisskeyKit
import RxCocoa
import RxSwift
import UIKit

class AccountsListViewModel: ViewModelType {
    struct Input {
        let loginTrigger: Observable<Void>
        let editTrigger: Observable<Void>
    }
    
    struct Output {
        let accounts: PublishRelay<[AccountCell.Section]> = .init()
        let showLoginViewTrigger: PublishRelay<Void> = .init()
        let changeEditableTrigger: PublishRelay<Void> = .init()
    }
    
    struct State {
        var hasPrepared: Bool = false
        var hasAccounts: Bool {
            return Cache.UserDefaults.shared.getUsers().count > 0
        }
    }
    
    private let input: Input
    var output: Output = .init()
    var state: State = .init()
    var dataSource: AccountsListDataSource?
    
    var accounts: [AccountCell.Section] = []
    private let disposeBag: DisposeBag
    private lazy var model = AccountsListModel()
    
    init(with input: Input, and disposeBag: DisposeBag) {
        self.input = input
        self.disposeBag = disposeBag
        transform()
    }
    
    func load() {
        let users = model.getUsers()
        
        state.hasPrepared = true
        users.forEach { user in
            let account = AccountCell.Model(owner: user)
            let accountSection = AccountCell.Section(items: [account])
            
            accounts.append(accountSection)
        }
        
        update(accounts)
    }
    
    private func transform() {
        input.editTrigger.subscribe(onNext: {
            self.output.changeEditableTrigger.accept(())
        }).disposed(by: disposeBag)
        
        input.loginTrigger.subscribe(onNext: {
            self.output.showLoginViewTrigger.accept(())
        }).disposed(by: disposeBag)
    }
    
    private func update(_ accounts: [AccountCell.Section]) {
        output.accounts.accept(accounts)
    }
}
