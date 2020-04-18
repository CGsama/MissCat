//
//  NotificationsViewModel.swift
//  MissCat
//
//  Created by Yuiga Wada on 2019/11/24.
//  Copyright © 2019 Yuiga Wada. All rights reserved.
//

import MisskeyKit
import RxSwift

class NotificationsViewModel {
    let notes: PublishSubject<[NotificationCell.Section]> = .init()
    var dataSource: NotificationDataSource?
    var cellCount: Int { return cellsModel.count }
    
    private var hasReactionGenCell: Bool = false
    var cellsModel: [NotificationCell.Model] = []
    
    private lazy var model = NotificationsModel()
    
    init(disposeBag: DisposeBag) {}
    
    func initialLoad() {
        loadNotification {
            // 読み込み完了後、Viewに伝達 & Streamingに接続
            self.update(new: self.cellsModel)
            self.connectStream()
        }
    }
    
    func loadUntilNotification(completion: (() -> Void)? = nil) {
        let untilId = cellsModel[cellsModel.count - 1].notificationId
        
        loadNotification(untilId: untilId) {
            self.update(new: self.cellsModel)
            if let completion = completion { completion() }
        }
    }
    
    func loadNotification(untilId: String? = nil, completion: (() -> Void)? = nil) {
        model.loadNotification(untilId: untilId) { results in
            guard let results = results else { return }
            
            results.forEach { notification in
                guard let cellModel = self.model.getModel(notification: notification) else { return }
                
                self.shapeModel(cellModel)
                self.removeDuplicated(cellModel)
                self.cellsModel.append(cellModel)
            }
            
            if let completion = completion { completion() }
        }
    }
    
    private func connectStream() {
        guard let apiKey = MisskeyKit.auth.getAPIKey() else { return }
        
        let streaming = MisskeyKit.Streaming()
        _ = streaming.connect(apiKey: apiKey, channels: [.main], response: handleStream)
    }
    
    private func handleStream(response: Any?, channel: SentStreamModel.Channel?, type: String?, error: MisskeyKitError?) {
        if let error = error {
            print(error)
            if error == .CannotConnectStream || error == .NoStreamConnection { connectStream() }
            return
        }
        
        guard let channel = channel, channel == .main, let cellModel = model.getModel(type: type, target: response) else { return }
        
        shapeModel(cellModel)
        
        removeDuplicated(cellModel)
        cellsModel.insert(cellModel, at: 0)
        
        update(new: cellsModel)
    }
    
    private func shapeModel(_ cellModel: NotificationCell.Model) {
        if cellModel.type == .mention || cellModel.type == .reply || cellModel.type == .quote,
            let replyNote = cellModel.replyNote {
            MFMEngine.shapeModel(replyNote)
        } else {
            MFMEngine.shapeModel(cellModel)
        }
    }
    
    /// 何らかの理由で重複しておくられてくるモデルを炙り出してremoveする
    private func removeDuplicated(_ cellModel: NotificationCell.Model) {
        // 例えば、何度もリアクションを変更されたりすると重複して送られてくる
        let duplicated = cellsModel.filter {
            guard let fromUserId = $0.fromUser?.id, let myNoteId = $0.myNote?.noteId else { return false }
            return fromUserId == cellModel.fromUser?.id && myNoteId == cellModel.myNote?.noteId
        }
        
        // 新しいバージョンの通知のみ表示する
        duplicated
            .compactMap { cellsModel.firstIndex(of: $0) }
            .forEach { cellsModel.remove(at: $0) }
    }
    
    private func update(new: [NotificationCell.Model]) {
        update(new: [NotificationCell.Section(items: new)])
    }
    
    private func update(new: [NotificationCell.Section]) {
        notes.onNext(new)
    }
}
