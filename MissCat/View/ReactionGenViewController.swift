//
//  ReactionGenCell.swift
//  MissCat
//
//  Created by Yuiga Wada on 2019/11/17.
//  Copyright © 2019 Yuiga Wada. All rights reserved.
//

import UIKit
import RxSwift
import RxDataSources


public protocol ReactionGenViewControllerDelegate {
    func scrollUp() //半モーダルviewを上まで引き上げる
}

fileprivate typealias ViewModel = ReactionGenViewModel
public typealias EmojisDataSource = RxCollectionViewSectionedReloadDataSource<ReactionGenViewController.EmojisSection>
public class ReactionGenViewController: UIViewController, UISearchBarDelegate, UIScrollViewDelegate, UICollectionViewDelegate {
    
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var displayNameLabel: UILabel!
    @IBOutlet weak var targetNoteTextView: UITextView!
    
    
    @IBOutlet weak var settingsButton: UIButton!
    @IBOutlet weak var emojiCollectionView: UICollectionView!
    
    
    public var delegate: ReactionGenViewControllerDelegate?
    
    private var viewModel: ReactionGenViewModel?
    private let disposeBag = DisposeBag()
    
    private var viewDidAppeared: Bool = false
    
    //MARK: Life Cycle
    public override func viewDidLoad() {
        super.viewDidLoad()
        self.setupComponents()
        self.setupCollectionViewLayout()
        
        self.setupViewModel()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.iconImageView.layer.cornerRadius =  self.iconImageView.frame.width / 2
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        self.setNextEmojis()
        super.viewDidAppear(animated)
        
        self.viewDidAppeared = true
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.viewDidAppeared = false
    }
    
    //MARK: Setup
    
    private func setupViewModel() {
        self.viewModel = .init(and: disposeBag)
        
        let dataSource = self.setupDataSource()
        self.binding(dataSource: dataSource, viewModel: self.viewModel!)
    }
    
    private func setupDataSource()-> EmojisDataSource {
        let dataSource = EmojisDataSource(
            configureCell: { dataSource, tableView, indexPath, item in
                return self.setupCell(dataSource, self.emojiCollectionView, indexPath)
        })
        
        return dataSource
    }
    
    private func binding(dataSource: EmojisDataSource?, viewModel: ViewModel) {
        guard let dataSource = dataSource else { return }
        
        let output = viewModel.output
        
        Observable.just(viewModel.output.favorites)
            .bind(to: self.emojiCollectionView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)
        
        output.otherEmojis.bind(to: self.emojiCollectionView.rx.items(dataSource: dataSource)).disposed(by: disposeBag)
    }
    
    
    private func setupComponents() {
        self.emojiCollectionView.register(UINib(nibName: "EmojiViewCell", bundle: nil), forCellWithReuseIdentifier: "EmojiCell")
        self.emojiCollectionView.rx.setDelegate(self).disposed(by: disposeBag)
        self.searchBar.delegate = self
        
        
        self.targetNoteTextView.textContainer.lineBreakMode = .byTruncatingTail
        self.targetNoteTextView.textContainer.maximumNumberOfLines = 2
        
        self.settingsButton.titleLabel?.font = .awesomeSolid(fontSize: 15.0)
    }
    
    private func setupCollectionViewLayout() {
        let flowLayout = UICollectionViewFlowLayout()
        let size = self.view.frame.width / 7
        
        flowLayout.itemSize = CGSize(width: size, height: size)
        flowLayout.minimumInteritemSpacing = 0
        flowLayout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        self.emojiCollectionView.collectionViewLayout = flowLayout
    }
    
    
    private func setupTapGesture(to view: EmojiViewCell, emoji: String) {
        
        let tapGesture = UITapGestureRecognizer()
        
        //各々のEmojiViewに対してtap gestureを付加する
        tapGesture.rx.event.bind{ _ in
            guard let targetNoteId = self.viewModel!.targetNoteId else { return }
            
            if self.viewModel!.hasMarked {
                self.viewModel!.cancelReaction(noteId: targetNoteId)
            }
            else {
                self.viewModel!.registerReaction(noteId: targetNoteId, reaction: emoji)
            }
            
            self.dismiss(animated: true, completion: nil) // 半モーダルを消す
        }.disposed(by: disposeBag)
        
        view.addGestureRecognizer(tapGesture)
    }
    
    
    
    //MARK: Setup Cell
    private func setupCell(_ dataSource: CollectionViewSectionedDataSource<ReactionGenViewController.EmojisSection>, _ collectionView: UICollectionView, _ indexPath: IndexPath)-> UICollectionViewCell {
        let index = indexPath.row
        let item = dataSource.sectionModels[0].items[index]
        
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EmojiCell", for: indexPath) as? EmojiViewCell else {fatalError("Internal Error.")}
        
        cell.mainView.emoji = item.defaultEmoji ?? "👍"
        //        cell.frame = CGRect(x: cell.frame.origin.x,
        //                            y: cell.frame.origin.y,
        //                            width: self.view.frame.width / 7,
        //                            height: self.view.frame.width / 7)
        setupTapGesture(to: cell, emoji: item.defaultEmoji ?? "👍")
        
        
        return cell
    }
    
    
    //MARK: Set Methods
    private func setNextEmojis() {
        guard let viewModel = viewModel else { return }
        viewModel.getNextEmojis()
    }
    
    private func setTargetNoteId(_ id: String?) {
        viewModel!.targetNoteId = id
    }

    
    //MARK: CollectionView Delegate
    public func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
//        guard let viewModel = viewModel else { return }
        let index = indexPath.row
        
        //下位10cellsでセル更新
        guard self.viewDidAppeared,
            collectionView.visibleCells.count > 0,
            collectionView.visibleCells.count / 6 - index < 10 else { return }
        
//        viewModel.getNextEmojis()
    }
    
    //MARK: Public Methods
    public func setTargetNote(noteId: String, iconUrl: String?, displayName: String, username: String, note: NSAttributedString, hasFile: Bool, hasMarked: Bool) {
        
        // noteId
        self.setTargetNoteId(noteId)
        
        // icon image
        if let image = Cache.shared.getIcon(username: username) {
            self.iconImageView.image = image
        }
        else if let iconUrl = iconUrl, let url = URL(string: iconUrl) {
            url.toUIImage{ [weak self] image in
                guard let self = self, let image = image else { return }
                
                DispatchQueue.main.async {
                    Cache.shared.saveIcon(username: username, image: image) // CHACHE!
                    self.iconImageView.image = image
                }
            }
        }
        
        // displayName
        self.displayNameLabel.text = displayName
        
        // note
        self.targetNoteTextView.attributedText = note //.changeColor(to: .lightGray)
        self.targetNoteTextView.alpha = 0.5
    }
    
    //MARK: TextField Delegate
    public func textFieldDidBeginEditing(_ textField: UITextField) {
        guard let delegate = delegate else { return }
        
        delegate.scrollUp()
    }
    
}


