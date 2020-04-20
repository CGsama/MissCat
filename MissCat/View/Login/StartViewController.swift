//
//  StartViewController.swift
//  MissCat
//
//  Created by Yuiga Wada on 2020/03/02.
//  Copyright © 2020 Yuiga Wada. All rights reserved.
//

import MisskeyKit
import RxCocoa
import RxSwift
import UIKit

class StartViewController: UIViewController {
    @IBOutlet weak var logoImageView: UIImageView!
    @IBOutlet weak var phraseLabel: UILabel!
    
    @IBOutlet weak var instanceLabel: UILabel!
    
    @IBOutlet weak var signupButton: UIButton!
    @IBOutlet weak var loginButton: UIButton!
    
    @IBOutlet weak var changeInstanceButton: UIButton!
    
    private var appSecret: String?
    private var ioAppSecret: String = "0fRSNkKKl9hcZTGrUSyZOb19n8UUVkxw" // misskey.ioの場合はappSecret固定
    private var misskeyInstance: String = "misskey.io" {
        didSet {
            MisskeyKit.changeInstance(instance: misskeyInstance) // インスタンスを変更
        }
    }
    
    private let appPermissions = ["read:account",
                                  "write:account",
                                  "read:blocks",
                                  "write:blocks",
                                  "read:drive",
                                  "write:drive",
                                  "read:favorites",
                                  "write:favorites",
                                  "read:following",
                                  "write:following",
                                  "read:messaging",
                                  "write:messaging",
                                  "read:mutes",
                                  "write:mutes",
                                  "write:notes",
                                  "read:notifications",
                                  "write:notifications",
                                  "read:reactions",
                                  "write:reactions",
                                  "write:votes",
                                  "read:pages",
                                  "write:pages",
                                  "write:page-likes",
                                  "read:page-likes",
                                  "read:user-groups",
                                  "write:user-groups"]
    
    private let disposeBag = DisposeBag()
    private lazy var components = [phraseLabel, instanceLabel, signupButton, loginButton, changeInstanceButton]
    
    // MARK: LifeCycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setGradientLayer()
        binding()
        
        MisskeyKit.changeInstance(instance: misskeyInstance) // インスタンスを変更
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.setNavigationBarHidden(true, animated: animated)
        hideComponents()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        summon(after: false)
        super.viewDidAppear(animated)
        
        UIView.animate(withDuration: 0.7, delay: 0, options: .curveEaseInOut, animations: {
            self.summon(after: true)
        }, completion: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    // MARK: Privates
    
    // MARK: Binding
    
    private func binding() {
        signupButton.rx.tap.subscribe(onNext: { _ in
            guard let tos = self.getViewController(name: "tos") as? TosViewController else { return }
            tos.agreed = self.signup
            self.navigationController?.pushViewController(tos, animated: true)
        }).disposed(by: disposeBag)
        
        loginButton.rx.tap.subscribe(onNext: { _ in
            guard let tos = self.getViewController(name: "tos") as? TosViewController else { return }
            tos.agreed = self.login
            self.navigationController?.pushViewController(tos, animated: true)
        }).disposed(by: disposeBag)
        
        changeInstanceButton.rx.tap.subscribe(onNext: { _ in
            self.showInstanceTextFiled()
        }).disposed(by: disposeBag)
    }
    
    private func signup() {
        generateAppSecret { appSecret in
            guard let authViewController = self.getAuthViewController(type: .Signup, appSecret: appSecret) else { return }
            self.presentOnFullScreen(authViewController, animated: true, completion: nil)
        }
    }
    
    private func login() {
        generateAppSecret { appSecret in
            guard let authViewController = self.getAuthViewController(type: .Login, appSecret: appSecret) else { return }
            self.presentOnFullScreen(authViewController, animated: true, completion: nil)
        }
    }
    
    // MARK: App
    
    /// Appを登録してappSecretを取得(misskey.ioの場合はappSecret固定)
    /// - Parameter completion: completion
    private func generateAppSecret(completion: @escaping (String) -> Void) {
        guard misskeyInstance != "misskey.io" else { // misskey.ioの場合はappSecret固定
            completion(ioAppSecret); return
        }
        
        MisskeyKit.app.create(name: "MissCat", description: "MissCat is an flexible Misskey client for iOS!", permission: appPermissions, callbackUrl: "https://misscat.dev") { data, error in
            guard let data = data, error == nil, let secret = data.secret else {
                if error == .some(.FailedToCommunicateWithServer) {
                    self.invalidUrlError()
                }
                return
            }
            
            self.appSecret = secret
            DispatchQueue.main.async {
                completion(secret)
            }
        }
    }
    
    // MARK: Login
    
    private func getAuthViewController(type: AuthWebViewController.AuthType, appSecret: String) -> UIViewController? {
        guard let authViewController = getViewController(name: "auth") as? AuthWebViewController else { return nil }
        authViewController.completion.subscribe(onNext: { apiKey in // ログイン処理が完了
            self.loginCompleted(apiKey)
        }).disposed(by: disposeBag)
        
        if type == .Signup {
            authViewController.setupSignup(misskeyInstance: misskeyInstance, appSecret: appSecret)
        } else {
            authViewController.setupLogin(misskeyInstance: misskeyInstance, appSecret: appSecret)
        }
        
        return authViewController
    }
    
    private func getViewController(name: String) -> UIViewController {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: name)
        
        return viewController
    }
    
    private func loginCompleted(_ apiKey: String) {
        Cache.UserDefaults.shared.setCurrentLoginedApiKey(apiKey)
        Cache.UserDefaults.shared.setCurrentLoginedInstance(misskeyInstance)
        
        _ = EmojiHandler.handler // カスタム絵文字を読み込む
        
        DispatchQueue.main.async {
            self.navigationController?.popViewController(animated: true)
        }
    }
    
    private func changeInstance(_ instance: String) {
        let shaped = shapeInstance(instance)
        
        misskeyInstance = shaped
        instanceLabel.text = shaped
    }
    
    private func shapeInstance(_ instance: String) -> String {
        var shaped = instance
        var removeList = [" ", "　"] // 空白を削除
        if instance.contains("http") {
            removeList.append("http://")
            removeList.append("https://")
        }
        
        removeList.forEach { shaped = shaped.remove(of: $0) }
        
        return shaped
    }
    
    // MARK: Alert
    
    private func showInstanceTextFiled() {
        let alert = UIAlertController(title: "インスタンスの変更", message: "", preferredStyle: .alert)
        let okAction = UIAlertAction(title: "変更", style: .default) { (_: UIAlertAction) in
            guard let textFields = alert.textFields, textFields.count == 1, let instance = textFields[0].text else { return }
            self.changeInstance(instance.isEmpty ? "misskey.io" : instance)
        }
        let cancelAction = UIAlertAction(title: "閉じる", style: .cancel, handler: nil)
        
        alert.addAction(okAction)
        alert.addAction(cancelAction)
        
        alert.addTextField { text in
            text.placeholder = "misskey.io"
        }
        
        present(alert, animated: true, completion: nil)
    }
    
    private func invalidUrlError() {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "エラー", message: "インスタンスに接続できません", preferredStyle: UIAlertController.Style.alert)
            let cancelAction: UIAlertAction = UIAlertAction(title: "閉じる", style: UIAlertAction.Style.destructive, handler: nil)
            
            alert.addAction(cancelAction)
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    // MARK: Design
    
    private func setGradientLayer() {
        let gradientLayer: CAGradientLayer = CAGradientLayer()
        
        gradientLayer.colors = [UIColor(hex: "4691a3").cgColor,
                                UIColor(hex: "5AB0C5").cgColor,
                                UIColor(hex: "89d5e8").cgColor]
        gradientLayer.frame = view.bounds
        gradientLayer.startPoint = CGPoint(x: 0, y: 1)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0)
        
        view.layer.insertSublayer(gradientLayer, at: 0)
    }
    
    private func hideComponents() {
        components.forEach { $0?.alpha = 0 }
    }
    
    /// Label, Buttton, Image等をすべて上からフェードインさせる処理
    /// - Parameter after: フェードイン前かフェードイン後か
    private func summon(after: Bool = false) {
        let sign = after ? 1 : -1
        components.forEach {
            guard let comp = $0 else { return }
            comp.alpha = after ? 1 : 0
            let originalFrame = comp.frame
            
            comp.frame = CGRect(x: originalFrame.origin.x,
                                y: originalFrame.origin.y + CGFloat(30 * sign),
                                width: originalFrame.width,
                                height: originalFrame.height)
        }
    }
}