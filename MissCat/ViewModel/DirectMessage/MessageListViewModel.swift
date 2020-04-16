//
//  MessageListViewModel.swift
//  MissCat
//
//  Created by Yuiga Wada on 2020/04/16.
//  Copyright © 2020 Yuiga Wada. All rights reserved.
//

import RxCocoa
import RxSwift
import SwiftLinkPreview

class MessageListViewModel: ViewModelType {
    // MARK: I/O
    
    struct Input {
        let dataSource: SenderDataSource
    }
    
    struct Output {
        let users: PublishSubject<[SenderCell.Section]> = .init()
    }
    
    struct State {
        var isLoading: Bool
    }
    
    private let input: Input
    let output: Output = .init()
    var state: State {
        return .init(isLoading: _isLoading)
    }
    
    var cellsModel: [SenderCell.Model] = []
    private let model: MessageListModel = .init()
    
    private let disposeBag: DisposeBag
    private var hasSkeltonCell: Bool = false
    private var _isLoading: Bool = false
    
    // MARK: LifeCycle
    
    init(with input: Input, and disposeBag: DisposeBag) {
        self.input = input
        self.disposeBag = disposeBag
    }
    
    func setupInitialCell() {
        loadUsers().subscribe(onError: { error in
            print(error)
        }, onCompleted: {
            DispatchQueue.main.async {
                self.updateUsers(new: self.cellsModel)
                self.removeSkeltonCell()
            }
        }, onDisposed: nil).disposed(by: disposeBag)
    }
    
    func setSkeltonCell() {
        guard !hasSkeltonCell else { return }
        
        for _ in 0 ..< 10 {
            let skeltonCellModel = SenderCell.Model.fakeSkeltonCell()
            cellsModel.append(skeltonCellModel)
        }
        
        updateUsers(new: cellsModel)
        hasSkeltonCell = true
    }
    
    private func removeSkeltonCell() {
        guard hasSkeltonCell else { return }
        let removed = cellsModel.suffix(cellsModel.count - 10)
        cellsModel = Array(removed)
        
        updateUsers(new: cellsModel)
    }
    
    // MARK: Load
    
//    func loadUntilUsers() -> Observable<SenderCell.Model> {
//        guard let untilId = cellsModel[cellsModel.count - 1].userId else {
//            return Observable.create { _ in
//                Disposables.create()
//            }
//        }
//
//        return loadUsers(untilId: untilId).do(onCompleted: {
//            self.updateUsers(new: self.cellsModel)
//        })
//    }
    
    func loadUsers(untilId: String? = nil) -> Observable<SenderCell.Model> {
        _isLoading = true
        return model.loadHistory().do(onNext: { cellModel in
            self.cellsModel.append(cellModel)
        }, onCompleted: {
            self._isLoading = false
        })
    }
    
    // MARK: Rx
    
    private func updateUsers(new: [SenderCell.Model]) {
        updateUsers(new: [SenderCell.Section(items: new)])
    }
    
    private func updateUsers(new: [SenderCell.Section]) {
        output.users.onNext(new)
    }
}
