//
//  TimelineViewController.swift
//  MissCat
//
//  Created by Yuiga Wada on 2019/11/07.
//  Copyright © 2019 Yuiga Wada. All rights reserved.
//

import AVKit
import FloatingPanel
import RxCocoa
import RxDataSources
import RxSwift
import UIKit
import XLPagerTabStrip

protocol TimelineDelegate { // For HomeViewController
    func tappedCell(item: NoteCell.Model)
    func move2Profile(userId: String)
    func openUserPage(username: String)
    func openSettings()
    func openPost(item: NoteCell.Model, type: PostViewController.PostType)
    
    func successInitialLoading(_ success: Bool)
    func changedStreamState(success: Bool)
    func showNotificationBanner(icon: NotificationBanner.IconType, notification: String)
}

typealias NotesDataSource = RxTableViewSectionedAnimatedDataSource<NoteCell.Section>
private typealias ViewModel = TimelineViewModel

class TimelineViewController: NoteDisplay, UITableViewDelegate, FooterTabBarDelegate, IndicatorInfoProvider {
    @IBOutlet weak var mainTableView: MissCatTableView!
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
    
    private let disposeBag = DisposeBag()
    private var viewModel: TimelineViewModel?
    
    private lazy var refreshControl = UIRefreshControl()
    
    private var cellHeightCache: [String: CGFloat] = [:] // String → identifier
    private var loadLimit: Int = 40
    
    private var withNavBar: Bool = true
    private var scrollable: Bool = true
    private var streamConnecting: Bool = false
    
    private lazy var dataSource = self.setupDataSource()
    
    var xlTitle: IndicatorInfo? // XLPagerTabStripで用いるtitle
    
    private var loggedIn: Bool = false
    private var hasApiKey: Bool {
        guard let apiKey = Cache.UserDefaults.shared.getCurrentLoginedApiKey() else { return false }
        return !apiKey.isEmpty
    }
    
    // MARK: Life Cycle
    
    /// 外部からTimelineViewContollerのインスタンスを生成する場合、このメソッドを通じて適切なパラメータをセットしていく
    /// - Parameters:
    ///   - type: TimelineType
    ///   - includeReplies: リプライ含めるか
    ///   - onlyFiles: ファイルのみのタイムラインか
    ///   - userId: 注目するユーザーのuserId
    ///   - listId: 注目するリストのlistId
    ///   - withNavBar: NavBarが必要か
    ///   - scrollable: スクロール可能か
    ///   - loadLimit: 一度に読み込むnoteの量
    ///   - xlTitle: タブに表示する名前
    func setup(type: TimelineType,
               includeReplies: Bool? = nil,
               onlyFiles: Bool? = nil,
               userId: String? = nil,
               listId: String? = nil,
               withNavBar: Bool = true,
               scrollable: Bool = true,
               loadLimit: Int = 40,
               xlTitle: IndicatorInfo? = nil) {
        let input = ViewModel.Input(dataSource: dataSource,
                                    type: type,
                                    includeReplies: includeReplies,
                                    onlyFiles: onlyFiles,
                                    userId: userId,
                                    listId: listId,
                                    loadLimit: loadLimit)
        
        viewModel = ViewModel(with: input, and: disposeBag)
        streamConnecting = type.needsStreaming
        
        self.xlTitle = xlTitle
        self.withNavBar = withNavBar
        self.scrollable = scrollable
        self.loadLimit = loadLimit
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupTableView()
        setupPullGesture()
        if viewModel == nil {
            setup(type: .Home)
        }
        
        binding(dataSource: dataSource)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        view.deselectCell(on: mainTableView)
        
        if !loggedIn, hasApiKey {
            loggedIn = true
            viewModel?.setupInitialCell()
        }
        viewModel?.setSkeltonCell()
        
        if let bottomConstraint = bottomConstraint {
            bottomConstraint.isActive = withNavBar
        }
    }
    
    // MARK: Setup TableView
    
    private func setupTableView() {
        mainTableView.register(UINib(nibName: "NoteCell", bundle: nil), forCellReuseIdentifier: "NoteCell")
        mainTableView.register(UINib(nibName: "RenoteeCell", bundle: nil), forCellReuseIdentifier: "RenoteeCell")
        
        mainTableView.rx.setDelegate(self).disposed(by: disposeBag)
        mainTableView.isScrollEnabled = false
    }
    
    private func setupDataSource() -> NotesDataSource {
        let dataSource = NotesDataSource(
            animationConfiguration: AnimationConfiguration(insertAnimation: .fade, reloadAnimation: .none, deleteAnimation: .fade),
            configureCell: { dataSource, _, indexPath, _ in
                self.setupCell(dataSource, self.mainTableView, indexPath)
            }
        )
        
        return dataSource
    }
    
    // MARK: Binding
    
    private func binding(dataSource: NotesDataSource?) {
        guard let viewModel = viewModel, let dataSource = dataSource else { return }
        
        let output = viewModel.output
        output.notes.bind(to: mainTableView.rx.items(dataSource: dataSource)).disposed(by: disposeBag)
        
        output.forceUpdateIndex.subscribe(onNext: updateForcibly).disposed(by: disposeBag)
        
        output.finishedLoading.subscribe(onNext: { success in
            guard let homeViewController = self.homeViewController else { return }
            homeViewController.successInitialLoading(success)
            
            self.mainTableView.isScrollEnabled = self.scrollable
        }).disposed(by: disposeBag)
        
        output.connectedStream.subscribe(onNext: { success in
            guard let homeViewController = self.homeViewController else { return }
            homeViewController.changedStreamState(success: success)
        }).disposed(by: disposeBag)
        
        mainTableView.lockScroll = output.lockTableScroll
    }
    
    // MARK: Gesture
    
    private func setupPullGesture() {
        refreshControl.attributedTitle = NSAttributedString(string: "Refresh...")
        refreshControl.addTarget(self, action: #selector(refreshTableView(_:)), for: UIControl.Event.valueChanged)
        
        if !streamConnecting {
            mainTableView.addSubview(refreshControl) // ストリーミングでないときだけ
        }
    }
    
    @objc func refreshTableView(_ sender: Any) {
        guard let viewModel = viewModel else { return }
        
        //        viewModel.loadUntilNotes {
        //            DispatchQueue.main.async { self.refreshControl.endRefreshing() }
        //        }
    }
    
    // MARK: Setup Cell
    
    private func setupCell(_ dataSource: TableViewSectionedDataSource<NoteCell.Section>, _ tableView: UITableView, _ indexPath: IndexPath) -> UITableViewCell {
        guard let viewModel = viewModel else { fatalError("Internal Error.") }
        
        let index = indexPath.row
        let item = viewModel.cellsModel[index]
        
        if item.identity == viewModel.state.reloadTopModelId { // untilLoadが完了した場合
            viewModel.state.reloadTopModelId = nil
            mainTableView.lockScroll?.accept(true) // スクロールを固定し直す
        }
        
        // View側で NoteCell / RenoteeCellを区別する
        if item.isRenoteeCell {
            guard let renoteeCell = tableView.dequeueReusableCell(withIdentifier: "RenoteeCell", for: indexPath) as? RenoteeCell
            else { return RenoteeCell() }
            
            renoteeCell.selectionStyle = UITableViewCell.SelectionStyle.none
            renoteeCell.setRenotee(item.renotee ?? "")
            
            renoteeCell.setTapGesture(disposeBag) {
                self.openUser(username: item.username)
            }
            
            return renoteeCell
        }
        
        // 通常のcellをつくる
        guard let itemCell = tableView.dequeueReusableCell(withIdentifier: "NoteCell", for: indexPath) as? NoteCell else { fatalError("Internal Error.") }
        
        let shapedCell = itemCell.transform(with: .init(item: item,
                                                        delegate: self))
        
        shapedCell.nameTextView.renderViewStrings()
        shapedCell.noteView.renderViewStrings()
        
        return shapedCell
    }
    
    private func showDetailView(item: NoteCell.Model) {
        guard let homeViewController = self.homeViewController else { return }
        
        let item = item
        homeViewController.tappedCell(item: item) // 画面遷移に関してはすべてHomeViewControllerが受け持つ
    }
    
    // MARK: TableView Delegate
    
    // tableViewの負担を軽減するようキャッシュを活用
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        let index = indexPath.row
        guard let viewModel = viewModel, index < viewModel.cellsModel.count else { return UITableView.automaticDimension }
        
        let id = viewModel.cellsModel[index].identity
        guard let height = cellHeightCache[id] else {
            return viewModel.cellsModel[index].isRenoteeCell ? 25 : UITableView.automaticDimension
        }
        return height
    }
    
    // estimatedHeightForRowAtとheightForRowAtてどっちもいるのか？
    // TODO: リアクションがつくと、高さが更新されずtextViewが潰れる
    //    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    //        guard let viewModel = viewModel else { return UITableView.automaticDimension }
    //
    //        let index = indexPath.row
    //        let id = viewModel.cellsModel[index].identity
    //
    //        guard let height = self.cellHeightCache[id] else {
    //            return viewModel.cellsModel[index].isRenoteeCell ? 25 : UITableView.automaticDimension
    //        }
    //        return height
    //    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let viewModel = viewModel else { return }
        let index = indexPath.row
        showDetailView(item: viewModel.cellsModel[index])
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let viewModel = viewModel else { return }
        
        let index = indexPath.row
        let cellModel = viewModel.cellsModel[index]
        let id = cellModel.identity
        
        // 再計算しないでいいようにセルの高さをキャッシュ
        if cellHeightCache.keys.contains(id) != true {
            cellHeightCache[id] = cellModel.isRenoteeCell ? 25 : cell.frame.height
        }
        
        // 下位4分の1のcellでセル更新
        let state = viewModel.state
        guard !state.isLoading, state.cellCount - indexPath.row < loadLimit / 4 else { return } //  state.cellCompleted,
        
        print("loadUntilNotes...")
        viewModel.loadUntilNotes().subscribe(onError: { error in
            if let error = error as? TimelineModel.NotesLoadingError, error == .NotesEmpty { return }
            self.homeViewController?.showNotificationBanner(icon: .Failed, notification: error.description)
        }).disposed(by: disposeBag)
    }
    
    // MARK: Utilities
    
    // 強制的にセルを更新する
    private func updateForcibly(index: Int) {
        let row = IndexPath(row: index, section: 0)
        DispatchQueue.main.async { self.mainTableView.reloadRows(at: [row], with: .none) }
    }
    
    private func getViewController(name: String) -> UIViewController {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: name)
        
        return viewController
    }
    
    // MARK: FooterTabBar Delegate
    
    func tappedHome() {
        let zeroIndexPath = IndexPath(row: 0, section: 0)
        
        // セルが存在しないと落ちるので制約をつける
        if mainTableView.numberOfSections > zeroIndexPath.section,
            mainTableView.numberOfRows(inSection: zeroIndexPath.section) > zeroIndexPath.row {
            mainTableView.scrollToRow(at: zeroIndexPath, at: .top, animated: true)
        }
    }
    
    func tappedNotifications() {}
    
    func tappedPost() {}
    
    func tappedFav() {}
    
    func tappedProfile() {}
    
    // MARK: NoteCell Delegate
    
    override func tappedReaction(reactioned: Bool, noteId: String, iconUrl: String?, displayName: String, username: String, note: NSAttributedString, hasFile: Bool, hasMarked: Bool, myReaction: String?) {
        if reactioned { // リアクションを取り消す
            guard let myReaction = myReaction else { return }
            viewModel?.updateReaction(targetNoteId: noteId,
                                      reaction: myReaction,
                                      isMyReaction: true,
                                      plus: false,
                                      needReloading: true)
            return
        }
        
        let reactionGen = presentReactionGen(noteId: noteId,
                                             iconUrl: iconUrl,
                                             displayName: displayName,
                                             username: username,
                                             note: note,
                                             hasFile: hasFile,
                                             hasMarked: hasMarked)
        
        reactionGen?.selectedEmoji.subscribe(onNext: { emojiModel in
            guard let raw = emojiModel.isDefault ? emojiModel.defaultEmoji : ":" + emojiModel.rawEmoji + ":" else { return }
            self.viewModel?.updateReaction(targetNoteId: noteId,
                                           reaction: raw,
                                           isMyReaction: true,
                                           plus: true,
                                           needReloading: true)
        }).disposed(by: disposeBag)
    }
    
    override func updateMyReaction(targetNoteId: String, rawReaction: String, plus: Bool) {
        viewModel?.updateReaction(targetNoteId: targetNoteId,
                                  reaction: rawReaction,
                                  isMyReaction: true,
                                  plus: plus,
                                  needReloading: false)
    }
    
    override func tappedOthers(note: NoteCell.Model) {
        // ユーザーをブロック・投稿を通報する
        // 投稿の削除
        note.userId.isMe { isMe in
            if isMe { self.showDeletePanel(note); return }
            self.showReportPanel(note)
        }
    }
    
    private func showReportPanel(_ note: NoteCell.Model) {
        guard let panelMenu = getViewController(name: "panel-menu") as? PanelMenuViewController else { return }
        
        let menuItems: [PanelMenuViewController.MenuItem] = [.init(title: "ユーザーをブロック", awesomeIcon: "angry", order: 0),
                                                             .init(title: "投稿を通報する", awesomeIcon: "ban", order: 1)]
        
        panelMenu.setPanelTitle("その他")
        panelMenu.setupMenu(items: menuItems)
        panelMenu.tapTrigger.asDriver(onErrorDriveWith: Driver.empty()).drive(onNext: { order in // どのメニューがタップされたのか
            guard order >= 0 else { return }
            panelMenu.dismiss(animated: true, completion: nil)
            
            switch order {
            case 0: // Block
                self.showBlockAlert(note)
            case 1: // Report
                self.showReportAlert(note)
            default:
                break
            }
        }).disposed(by: disposeBag)
        
        presentWithSemiModal(panelMenu, animated: true, completion: nil)
    }
    
    private func showDeletePanel(_ note: NoteCell.Model) {
        guard let panelMenu = getViewController(name: "panel-menu") as? PanelMenuViewController else { return }
        
        let menuItems: [PanelMenuViewController.MenuItem] = [.init(title: "投稿を削除する", awesomeIcon: "trash-alt", order: 0)]
        
        panelMenu.setPanelTitle("その他")
        panelMenu.setupMenu(items: menuItems)
        panelMenu.tapTrigger.asDriver(onErrorDriveWith: Driver.empty()).drive(onNext: { order in // どのメニューがタップされたのか
            guard order >= 0 else { return }
            panelMenu.dismiss(animated: true, completion: nil)
            
            switch order {
            case 0:
                self.showDeleteAlert(note)
            default:
                break
            }
        }).disposed(by: disposeBag)
        
        presentWithSemiModal(panelMenu, animated: true, completion: nil)
    }
    
    private func showBlockAlert(_ note: NoteCell.Model) {
        showAlert(title: "ブロック", message: "本当にこのユーザーをブロックしますか？", yesOption: "ブロック") { yes in
            guard yes else { return }
            self.viewModel?.block(userId: note.userId)
        }
    }
    
    private func showReportAlert(_ note: NoteCell.Model) {
        // 投稿を削除する
        // ユーザーをブロック
        showTextAlert(title: "迷惑行為の詳細を記述してください", placeholder: "例: 著作権侵害/不適切な投稿など") { message in
            self.showAlert(title: "通報", message: "本当にこの投稿を通報しますか？", yesOption: "通報") { yes in
                guard yes else { return }
                self.viewModel?.report(message: message, userId: note.userId)
            }
        }
    }
    
    private func showDeleteAlert(_ note: NoteCell.Model) {
        showAlert(title: "削除", message: "本当にこの投稿を削除しますか？", yesOption: "削除") { _ in
            guard let noteId = note.noteId else { return }
            self.viewModel?.deleteMyNote(noteId: noteId)
        }
    }
    
    private func showAlert(title: String, message: String, yesOption: String? = nil, action: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        let cancelAction: UIAlertAction = UIAlertAction(title: "閉じる", style: UIAlertAction.Style.cancel, handler: {
            (_: UIAlertAction!) -> Void in
            action(yesOption == nil)
        })
        
        alert.addAction(cancelAction)
        
        if let yesOption = yesOption {
            let defaultAction: UIAlertAction = UIAlertAction(title: yesOption, style: UIAlertAction.Style.destructive, handler: {
                (_: UIAlertAction!) -> Void in
                action(true)
            })
            alert.addAction(defaultAction)
        }
        
        present(alert, animated: true, completion: nil)
    }
    
    private func showTextAlert(title: String, placeholder: String, handler: @escaping (String) -> Void) {
        let alert = UIAlertController(title: title, message: "", preferredStyle: .alert)
        let okAction = UIAlertAction(title: "決定", style: .default) { (_: UIAlertAction) in
            guard let textFields = alert.textFields, textFields.count == 1, let text = textFields[0].text else { return }
            if text.isEmpty {
                self.showAlert(title: "エラー", message: "必ず入力してください") { _ in
                    self.showTextAlert(title: title, placeholder: placeholder, handler: handler)
                }
                return
            }
            
            handler(text)
        }
        let cancelAction = UIAlertAction(title: "閉じる", style: .cancel, handler: nil)
        
        alert.addAction(okAction)
        alert.addAction(cancelAction)
        
        alert.addTextField { text in
            text.placeholder = placeholder
        }
        
        present(alert, animated: true, completion: nil)
    }
    
    // MARK: XLPagerTabStrip delegate
    
    func indicatorInfo(for pagerTabStripController: PagerTabStripViewController) -> IndicatorInfo {
        return xlTitle ?? "Home"
    }
}
