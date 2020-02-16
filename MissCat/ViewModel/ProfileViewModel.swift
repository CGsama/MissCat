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
import YanagiText

class ProfileViewModel: ViewModelType {
    struct Input {
        let yanagi: YanagiText
    }
    
    struct Output {
        let bannerImage: PublishRelay<UIImage> = .init()
        let displayName: PublishRelay<String> = .init()
        let username: PublishRelay<String> = .init()
        let iconImage: PublishRelay<UIImage> = .init()
        let intro: PublishRelay<NSAttributedString> = .init()
        
        var isMe: Bool = false
    }
    
    struct State {}
    
    private var input: Input
    public lazy var output: Output = .init()
    
    private lazy var model = ProfileModel()
    
    public init(with input: Input, and disposeBag: DisposeBag) {
        self.input = input
    }
    
    public func setUserId(_ userId: String, isMe: Bool) {
        model.getUser(userId: userId, completion: handleUserInfo)
        
        output.isMe = isMe
    }
    
    private func handleUserInfo(_ user: UserModel?) {
        guard let user = user else { return }
        
        // Icon Image
        if let username = user.username, let cachediconImage = Cache.shared.getIcon(username: username) {
            output.iconImage.accept(cachediconImage)
        } else if let iconImageUrl = user.avatarUrl {
            iconImageUrl.toUIImage { image in
                guard let image = image else { return }
                self.output.iconImage.accept(image)
            }
        }
        
        // Description
        if let description = user.description {
            DispatchQueue.main.async {
                let shaped = description.mfmPreTransform().mfmTransform(yanagi: self.input.yanagi)
                self.output.intro.accept(shaped ?? .init())
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
            output.username.accept("@" + username)
            output.displayName.accept(user.name ?? username)
        }
    }
}
