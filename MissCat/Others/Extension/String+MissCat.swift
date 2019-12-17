//
//  String+MissCat.swift
//  MissCat
//
//  Created by Yuiga Wada on 2019/11/13.
//  Copyright © 2019 Yuiga Wada. All rights reserved.
//

import UIKit
import MisskeyKit
import Down

extension String {
    func toAttributedString(family: String?, size: CGFloat) -> NSAttributedString? {
        do {
            let rawHtml = "<style>" +
                " html * {" +
                "font-size: \(size)pt !important;" +
                "font-family: \(family ?? "Helvetica"), Helvetica !important; } " +
                "a:hover, a:visited, a:link, a:active { text-decoration: none!important; -webkit-box-shadow: none!important; box-shadow: none!important; }" +
            "</style> \(self.replacingOccurrences(of: "\n", with: "<br>"))"
            
            guard let html = rawHtml.data(using: String.Encoding.utf8) else {
                return nil
            }
            
            return try NSAttributedString(data: html,
                                          options: [.documentType: NSAttributedString.DocumentType.html,
                                                    .characterEncoding: String.Encoding.utf8.rawValue],
                                          documentAttributes: nil)
        } catch {
            print("html converter error: ", error)
            return nil
        }
    }
    
    
    
    func toUIImage(_ completion: @escaping (UIImage?)->()){
        guard let url = URL(string: self) else { completion(nil); return }
        
        url.toUIImage(completion)
    }
    
    
    func regexMatches(pattern: String) -> [[String]] {
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let nsString = self as NSString
        let results  = regex.matches(in: self, options: [], range: NSMakeRange(0, nsString.length))
        return results.map { result in
            (0..<result.numberOfRanges).map {
                result.range(at: $0).location != NSNotFound
                    ? nsString.substring(with: result.range(at: $0))
                    : ""
            }
        }
    }
    
    
    //Stringの数字をインクリメントする
    func increment()-> String {
        guard let number = Int(self) else { return self }
        
        return String(number + 1)
    }
    
    //Stringの数字が"0"かどうかを判定
    func isZero()-> Bool {
        guard let number = Int(self) else { return false }
        
        return number == 0
    }
    
    //ISO 8601形式のdateを "○m", "◯s" 形式に変換する
    public func calculateAgo()-> String {
        let date = self
        
        let iso8601formatter = ISO8601DateFormatter()
        iso8601formatter.formatOptions.insert(.withFractionalSeconds)
        guard let formatedDate = iso8601formatter.date(from: date) else { return "0s" }
        
        
        let interval = Date().timeIntervalSince(formatedDate)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyy-MM-dd"
        
        return interval.toAgo() ?? formatter.string(from: formatedDate)
    }
    
    // userIdに対して自分かどうかcheck
    public func isMe(completion: @escaping (Bool)->()) {
        Cache.shared.getMe{ me in
            guard let me = me else { return }
            let isMe = me.id == self
            
            completion(isMe)
        }
    }
    
    //HyperLinkを用途ごとに捌く
    public func analyzeHyperLink()-> (linkType: String, value: String) {
        let magicHeaders = ["http://tapevents.misscat/": "User", "http://hashtags.misscat/": "Hashtag"]
        var result = (linkType: "URL", value: self)
        
        magicHeaders.keys.forEach { magicHeader in
            guard let type = magicHeaders[magicHeader], self.count > magicHeader.count else { return }
            
            let header = String(self.prefix(magicHeader.count))
            let value = self.suffix(self.count - magicHeader.count)
            
            //ヘッダーが一致するものをresultに返す
            guard header == magicHeader else { return }
            result = (linkType: type, value: String(value))
        }
        
        // if header != magicHeader
        return result
    }
    
}
