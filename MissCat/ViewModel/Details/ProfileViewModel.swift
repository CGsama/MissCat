//
//  ProfileViewModel.swift
//  MissCat
//
//  Created by Yuiga Wada on 2019/12/07.
//  Copyright © 2019 Yuiga Wada. All rights reserved.
//

import MisskeyKit
import RxCocoa
import RxSwift
import UIKit

class ProfileViewModel: ViewModelType {
    struct Input {
        let nameYanagi: YanagiText
        let introYanagi: YanagiText
        
        let followButtonTapped: ControlEvent<Void>
        let backButtonTapped: ControlEvent<Void>
        let settingsButtonTapped: ControlEvent<Void>
    }
    
    struct Output {
        let bannerImage: PublishRelay<UIImage> = .init()
        let displayName: PublishRelay<NSAttributedString> = .init()
        let iconImage: PublishRelay<UIImage> = .init()
        let intro: PublishRelay<NSAttributedString> = .init()
        let isCat: PublishRelay<Bool> = .init()
        
        let notesCount: PublishRelay<String> = .init()
        let followCount: PublishRelay<String> = .init()
        let followerCount: PublishRelay<String> = .init()
        let relation: PublishRelay<UserRelationship> = .init()
        
        let showUnfollowAlertTrigger: PublishRelay<Void> = .init()
        let showProfileSettingsTrigger: PublishRelay<Void> = .init()
        let openSettingsTrigger: PublishRelay<Void> = .init()
        let popViewControllerTrigger: PublishRelay<Void> = .init()
        
        var isMe: Bool = false
    }
    
    struct State {
        var isFollowing: Bool?
    }
    
    private var input: Input
    lazy var output: Output = .init()
    lazy var state: State = .init()
    
    private var userId: String?
    private var relation: UserRelationship?
    private var disposeBag: DisposeBag
    private lazy var model = ProfileModel()
    
    init(with input: Input, and disposeBag: DisposeBag) {
        self.input = input
        self.disposeBag = disposeBag
    }
    
    func setUserId(_ userId: String, isMe: Bool) {
        model.getUser(userId: userId, completion: handleUserInfo)
        
        output.isMe = isMe
        self.userId = userId
    }
    
    func follow() {
        guard let userId = userId else { return }
        model.follow(userId: userId) { success in
            guard success else { return }
            if self.relation != nil {
                self.relation?.isFollowing = true
                self.state.isFollowing = true
                self.output.relation.accept(self.relation!)
            }
        }
    }
    
    func unfollow() {
        guard let userId = userId else { return }
        model.unfollow(userId: userId) { success in
            guard success else { return }
            if self.relation != nil {
                self.relation?.isFollowing = false
                self.state.isFollowing = false
                self.output.relation.accept(self.relation!)
            }
        }
    }
    
    private func handleUserInfo(_ user: UserModel?) {
        guard let user = user else { return }
        
        // Notes || FF
        output.notesCount.accept(user.notesCount?.description ?? "0")
        output.followCount.accept(user.followingCount?.description ?? "0")
        output.followerCount.accept(user.followersCount?.description ?? "0")
        
        setRelation(targetUserId: user.id)
        
        // Icon Image
        let host = user.host ?? ""
        if let username = user.username, let cachediconImage = Cache.shared.getIcon(username: "\(username)@\(host)") {
            output.iconImage.accept(cachediconImage)
        } else if let iconImageUrl = user.avatarUrl {
            iconImageUrl.toUIImage { image in
                guard let image = image else { return }
                self.output.iconImage.accept(image)
            }
        }
        
        // Description
        if let description = user.description {
            let textHex = Theme.shared.currentModel?.colorPattern.hex.text
            DispatchQueue.main.async {
                let shaped = description.mfmPreTransform().mfmTransform(font: UIFont(name: "Helvetica", size: 11.0) ?? .systemFont(ofSize: 11.0),
                                                                        externalEmojis: user.emojis,
                                                                        textHex: textHex)
                
                self.output.intro.accept(shaped.attributed ?? .init())
                shaped.mfmEngine.renderCustomEmojis(on: self.input.introYanagi)
            }
        } else {
            output.intro.accept("自己紹介はありません".toAttributedString(family: "Helvetica", size: 11.0) ?? .init())
        }
        
        // Banner Image
        if let bannerUrl = user.bannerUrl {
            bannerUrl.toUIImage { image in
                guard let image = image else { return }
                self.output.bannerImage.accept(image)
            }
        }
        
        // username / displayName
        if let username = user.username {
            let shaped = MFMEngine.shapeDisplayName(name: user.name ?? username,
                                                    username: username,
                                                    emojis: user.emojis,
                                                    nameFont: UIFont(name: "Helvetica", size: 13.0),
                                                    usernameFont: UIFont(name: "Helvetica", size: 12.0),
                                                    nameHex: "#ffffff",
                                                    usernameColor: .white)
            
            output.displayName.accept(shaped.attributed ?? .init())
            DispatchQueue.main.async {
                shaped.mfmEngine.renderCustomEmojis(on: self.input.nameYanagi)
            }
        }
        
        output.isCat.accept(user.isCat ?? false)
        
        // tapped event
        input.followButtonTapped.subscribe(onNext: { _ in
            if !self.output.isMe {
                if self.state.isFollowing ?? true { // try フォロー解除
                    self.output.showUnfollowAlertTrigger.accept(())
                } else {
                    self.follow()
                }
            } else { // 自分のプロフィールの場合
                self.output.showProfileSettingsTrigger.accept(())
            }
        }).disposed(by: disposeBag)
        
        input.backButtonTapped.subscribe(onNext: { _ in
            self.output.popViewControllerTrigger.accept(())
        }).disposed(by: disposeBag)
        
        input.settingsButtonTapped.subscribe(onNext: { _ in
            self.output.openSettingsTrigger.accept(())
        }).disposed(by: disposeBag)
    }
    
    private func setRelation(targetUserId: String) {
        MisskeyKit.users.getUserRelationship(userId: targetUserId) { relation, error in
            guard let relation = relation, error == nil else { return }
            self.output.relation.accept(relation)
            self.state.isFollowing = relation.isFollowing
            self.relation = relation
        }
    }
}
