//
//  ProfileSettingsViewController.swift
//  MissCat
//
//  Created by Yuiga Wada on 2020/05/14.
//  Copyright © 2020 Yuiga Wada. All rights reserved.
//

import Eureka
import RxCocoa
import RxSwift
import UIKit

class ProfileSettingsViewController: FormViewController {
    var homeViewController: HomeViewController?
    
    private var catSwitch: SwitchRow?
    private var bioTextArea: TextAreaRow?
    private var nameTextArea: TextRow?
    
    private var disposeBag: DisposeBag = .init()
    
    private lazy var bannerImage: UIImageView = .init()
    private lazy var iconImage: UIImageView = .init()
    private var headerHeight: CGFloat = 150
    
    private var viewModel: ProfileSettingsViewModel?
    
    // MARK: LifeCycle
    
    func setup(banner: UIImage? = nil, bannerUrl: String, icon: UIImage? = nil, iconUrl: String, name: String, description: String, isCat: Bool) {
        bannerImage.image = banner
        iconImage.image = icon
        
        let iconUrl = icon == nil ? iconUrl : nil
        let bannerUrl = banner == nil ? bannerUrl : nil
        
        let input: ProfileSettingsViewModel.Input = .init(iconUrl: iconUrl, bannerUrl: bannerUrl, name: name, description: description, isCat: isCat)
        let viewModel = ProfileSettingsViewModel(with: input, and: disposeBag)
        
        binding(with: viewModel)
        self.viewModel = viewModel
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupComponent()
        setTable()
        setHeader()
        setTheme()
        bindTheme()
        
        viewModel?.transform()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        iconImage.layoutIfNeeded()
        iconImage.layer.cornerRadius = iconImage.frame.height / 2
    }
    
    // MARK: Design
    
    private func bindTheme() {
        let theme = Theme.shared.theme
        
        theme.map { $0.colorPattern.ui }.subscribe(onNext: { colorPattern in
            self.view.backgroundColor = colorPattern.base
        }).disposed(by: disposeBag)
    }
    
    private func setTheme() {
        if let colorPattern = Theme.shared.currentModel?.colorPattern.ui {
            view.backgroundColor = colorPattern.base
            tableView.backgroundColor = colorPattern.base
        }
        
        if let mainColorHex = Theme.shared.currentModel?.mainColorHex {
            catSwitch?.cell.switchControl.onTintColor = UIColor(hex: mainColorHex)
        }
    }
    
    /// ステータスバーの文字色
    override var preferredStatusBarStyle: UIStatusBarStyle {
        let currentColorMode = Theme.shared.currentModel?.colorMode ?? .light
        return currentColorMode == .light ? UIStatusBarStyle.default : UIStatusBarStyle.lightContent
    }
    
    private func getCellBackgroundColor() -> UIColor {
        guard let theme = Theme.shared.currentModel else { return .white }
        return theme.colorMode == .light ? theme.colorPattern.ui.base : theme.colorPattern.ui.sub2
    }
    
    private func changeSeparatorStyle() {
        let currentColorMode = Theme.shared.currentModel?.colorMode ?? .light
        tableView.separatorStyle = currentColorMode == .light ? .singleLine : .none
    }
    
    // MARK: Binding
    
    private func binding(with viewModel: ProfileSettingsViewModel) {
        viewModel.output
            .banner
            .asDriver(onErrorDriveWith: Driver.empty())
            .drive(bannerImage.rx.image)
            .disposed(by: disposeBag)
        
        viewModel.output
            .icon
            .asDriver(onErrorDriveWith: Driver.empty())
            .drive(iconImage.rx.image)
            .disposed(by: disposeBag)
        
        viewModel.output
            .name
            .asDriver(onErrorDriveWith: Driver.empty())
            .drive(onNext: { name in
                self.nameTextArea?.value = name
            }).disposed(by: disposeBag)
        
        viewModel.output
            .description
            .asDriver(onErrorDriveWith: Driver.empty())
            .drive(onNext: { description in
                self.bioTextArea?.value = description
            }).disposed(by: disposeBag)
        
        viewModel.output
            .isCat
            .asDriver(onErrorDriveWith: Driver.empty())
            .drive(onNext: { isCat in
                self.catSwitch?.value = isCat
            }).disposed(by: disposeBag)
    }
    
    // MARK: Setup
    
    private func setupComponent() {
        title = "プロフィールの編集"
        changeSeparatorStyle()
        bannerImage.clipsToBounds = true
        iconImage.clipsToBounds = true
        
        bannerImage.contentMode = .scaleAspectFill
    }
    
    private func setTable() {
        guard let theme = Theme.shared.currentModel else { return }
        
        let nameSection = getNameSection(with: theme)
        let descSection = getDescSection(with: theme)
        let miscSection = getMiscSection(with: theme)
        
        form +++ nameSection +++ descSection +++ miscSection
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.isScrollEnabled = false
    }
    
    private func setHeader() {
        bannerImage.translatesAutoresizingMaskIntoConstraints = false
        iconImage.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(bannerImage)
        view.addSubview(iconImage)
        
        // AutoLayout
        view.addConstraints([
            NSLayoutConstraint(item: bannerImage,
                               attribute: .leading,
                               relatedBy: .equal,
                               toItem: view,
                               attribute: .leading,
                               multiplier: 1.0,
                               constant: 0),
            
            NSLayoutConstraint(item: bannerImage,
                               attribute: .height,
                               relatedBy: .equal,
                               toItem: view,
                               attribute: .height,
                               multiplier: 0,
                               constant: headerHeight),
            
            NSLayoutConstraint(item: bannerImage,
                               attribute: .trailing,
                               relatedBy: .equal,
                               toItem: view,
                               attribute: .trailing,
                               multiplier: 1.0,
                               constant: 0),
            
            NSLayoutConstraint(item: bannerImage,
                               attribute: .top,
                               relatedBy: .equal,
                               toItem: view.safeAreaLayoutGuide,
                               attribute: .top,
                               multiplier: 1.0,
                               constant: 0)
        ])
        
        view.addConstraints([
            NSLayoutConstraint(item: iconImage,
                               attribute: .leading,
                               relatedBy: .equal,
                               toItem: view,
                               attribute: .leading,
                               multiplier: 1.0,
                               constant: 20),
            
            NSLayoutConstraint(item: iconImage,
                               attribute: .height,
                               relatedBy: .equal,
                               toItem: view,
                               attribute: .height,
                               multiplier: 0.08,
                               constant: 0),
            
            NSLayoutConstraint(item: iconImage,
                               attribute: .width,
                               relatedBy: .equal,
                               toItem: view,
                               attribute: .height,
                               multiplier: 0.08,
                               constant: 0),
            
            NSLayoutConstraint(item: iconImage,
                               attribute: .centerY,
                               relatedBy: .equal,
                               toItem: bannerImage,
                               attribute: .centerY,
                               multiplier: 1.0,
                               constant: 0)
        ])
        
        guard let tableView = tableView else { return }
        view.addConstraints([
            NSLayoutConstraint(item: tableView,
                               attribute: .leading,
                               relatedBy: .equal,
                               toItem: view,
                               attribute: .leading,
                               multiplier: 1.0,
                               constant: 0),
            
            NSLayoutConstraint(item: tableView,
                               attribute: .top,
                               relatedBy: .equal,
                               toItem: bannerImage,
                               attribute: .bottom,
                               multiplier: 1.0,
                               constant: 0),
            
            NSLayoutConstraint(item: tableView,
                               attribute: .trailing,
                               relatedBy: .equal,
                               toItem: view,
                               attribute: .trailing,
                               multiplier: 1.0,
                               constant: 0),
            
            NSLayoutConstraint(item: tableView,
                               attribute: .bottom,
                               relatedBy: .equal,
                               toItem: view,
                               attribute: .bottom,
                               multiplier: 1.0,
                               constant: 0)
        ])
        
        iconImage.layoutIfNeeded()
        iconImage.layer.cornerRadius = iconImage.frame.height / 2
    }
    
    private func getNameSection(with theme: Theme.Model) -> Section {
        let nameTextArea = TextRow { row in
            row.tag = "name-text"
            row.title = "名前"
        }.cellUpdate { cell, _ in
            cell.backgroundColor = self.getCellBackgroundColor()
            cell.textLabel?.textColor = theme.colorPattern.ui.text
            cell.textField?.textColor = theme.colorPattern.ui.text
        }
        
        self.nameTextArea = nameTextArea
        return Section("Name") <<< nameTextArea
    }
    
    private func getDescSection(with theme: Theme.Model) -> Section {
        let bioTextArea = TextAreaRow { row in
            row.tag = "bio-text-area"
            row.placeholder = "自分について..."
        }.cellSetup { cell, _ in
            cell.height = { 220 }
        }.cellUpdate { cell, _ in
            cell.backgroundColor = self.getCellBackgroundColor()
            cell.textLabel?.textColor = theme.colorPattern.ui.text
            cell.placeholderLabel?.textColor = .lightGray
            cell.textView?.textColor = theme.colorPattern.ui.text
        }
        
        self.bioTextArea = bioTextArea
        return Section("Bio") <<< bioTextArea
    }
    
    private func getMiscSection(with theme: Theme.Model) -> Section {
        let catSwitch = SwitchRow { row in
            row.tag = "cat-switch"
            row.title = "Catとして設定"
        }.cellUpdate { cell, _ in
            cell.backgroundColor = self.getCellBackgroundColor()
            cell.textLabel?.textColor = theme.colorPattern.ui.text
        }
        
        self.catSwitch = catSwitch
        return Section("Cat") <<< catSwitch
    }
}
