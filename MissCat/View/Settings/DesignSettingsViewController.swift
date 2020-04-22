//
//  DesignSettingsViewController.swift
//  MissCat
//
//  Created by Yuiga Wada on 2020/04/22.
//  Copyright © 2020 Yuiga Wada. All rights reserved.
//

import Eureka
import UIKit

class DesignSettingsViewController: FormViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "デザイン"
        
        let tabSettingsSection = getTabSettingsSection()
        form +++ tabSettingsSection
        
        tableView.backgroundColor = .white
    }
    
    private func getTabSettingsSection() -> MultivaluedSection {
        return MultivaluedSection(multivaluedOptions: [.Reorder, .Insert, .Delete],
                                  header: "上タブ",
                                  footer: "タップで表示名を変更することができます") {
            $0.tag = "textfields"
            
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
            
            $0 <<< TabSettingsRow {
                $0.tabKind = .home
            }
            $0 <<< TabSettingsRow {
                $0.tabKind = .local
            }
        }
    }
}
