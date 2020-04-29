//
//  DesignSettingsViewController.swift
//  MissCat
//
//  Created by Yuiga Wada on 2020/04/22.
//  Copyright © 2020 Yuiga Wada. All rights reserved.
//

import Eureka
import RxSwift
import UIKit

class DesignSettingsViewController: FormViewController {
    private var disposeBag: DisposeBag = .init()
    
    // MARK: LifeCycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupComponent()
        setTable()
        bindTheme()
        setTheme()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        saveSettings()
    }
    
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
    }
    
    // MARK: Setup
    
    private func setupComponent() {
        title = "デザイン"
    }
    
    private func setTable() {
        guard let theme = Theme.shared.currentModel else { return }
        
        let tabSettingsSection = getTabSettingsSection(with: theme)
        let themeSettingsSection = getThemeSettingsSection(with: theme)
        
        form +++ tabSettingsSection +++ themeSettingsSection
    }
    
    private func getTabSettingsSection(with theme: Theme.Model) -> MultivaluedSection {
        var section = MultivaluedSection(multivaluedOptions: [.Reorder, .Insert, .Delete],
                                         header: "上タブ設定",
                                         footer: "タップで表示名を変更することができます") {
            $0.tag = "tab-settings"
            $0.addButtonProvider = { _ in
                ButtonRow {
                    $0.title = "タブを追加"
                }.cellUpdate { cell, _ in
                    cell.textLabel?.textAlignment = .left
                }
            }
            
            $0.multivaluedRowToInsertAt = { _ in
                TabSettingsRow()
            }
        }
        
        theme.tab.reversed().forEach { tab in
            let row = TabSettingsRow {
                $0.cell?.setName(tab.name)
                $0.cell?.setKind(tab.kind)
            }
            section.insert(row, at: 0)
        }
        
        return section
    }
    
    private func getThemeSettingsSection(with theme: Theme.Model) -> Section {
        let currentColor = UIColor(hex: theme.mainColorHex)
        return Section("テーマ設定")
            <<< SegmentedRow<String>() { $0.tag = "color-mode"; $0.options = ["Light", "Dark"]; $0.value = theme.colorMode == .light ? "Light" : "Dark" }
            <<< ColorPickerRow { $0.tag = "main-color"; $0.cell.setColor(currentColor) }
    }
    
    // MARK: Update / Save
    
    private func saveSettings() {
        let tab = getTabSettings()
        let mainColorHex = getMainColorSettings()
        let colorMode = getColorModeSettings()
        
        let newModel = Theme.Model(tab: tab, mainColorHex: mainColorHex, colorMode: colorMode)
        Theme.shared.save(with: newModel)
    }
    
    private func getTabSettings() -> [Theme.Tab] {
        guard let tabSection = form.sectionBy(tag: "tab-settings") as? MultivaluedSection else { return [] }
        
        var tabs: [Theme.Tab] = []
        tabSection.allRows.forEach { // なぜかcompactMapできない...
            guard let row = $0 as? TabSettingsRow else { return }
            tabs.append(row.tab)
        }
        
        return tabs
    }
    
    private func getColorModeSettings() -> Theme.ColerMode {
        guard let colorModeRow = form.rowBy(tag: "color-mode") as? SegmentedRow<String>,
            let colorMode = colorModeRow.value else { return .light }
        
        return colorMode == "Light" ? .light : .dark
    }
    
    private func getMainColorSettings() -> String {
        guard let colorRow = form.rowBy(tag: "main-color") as? ColorPickerRow else { return "2F7CF6" }
        return colorRow.currentColorHex
    }
}
