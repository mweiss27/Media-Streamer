//
//  SpotifyPlaylistView.swift
//  MediaStreamer
//
//  Created by Matt Weiss on 2/7/17.
//  Copyright © 2017 Matt Weiss. All rights reserved.
//

import UIKit

class SpotifyPlaylistView: UIView {
    
    var owner: UIView?
    
    var partialPlaylist: SPTPartialPlaylist?
    var playlistImage: SPTImage?
    var playlistName: String?
    var playlistAuthor: String?
    
    var imageView: UIImageView?
    private var nameView: UILabel?
    private var ownerView: UILabel?
    
    static func initWith(owner: UIView, playlist: SPTPartialPlaylist) -> SpotifyPlaylistView {
        let view = SpotifyPlaylistView()
        view.owner = owner
        view.partialPlaylist = playlist
        view.playlistImage = playlist.largestImage
        view.playlistName = playlist.name
        
        view.build()
        
        SPTUser.request(playlist.owner.canonicalUserName, withAccessToken: SPTAuth.defaultInstance().session.accessToken, callback: { (error, obj) in
            if error != nil {
                print("Error on request user: \(error?.localizedDescription)")
                return
            }
            if let user = obj as? SPTUser {
                if let owner = user.displayName {
                    //print("Setting playlistAuthor=\(owner)")
                    view.playlistAuthor = owner
                    view.ownerView?.text = "\(owner) - \((view.partialPlaylist?.trackCount)!) songs"
                }
                else if let canon = user.canonicalUserName {
                    //print("Setting playlistAuthor=\(owner)")
                    view.playlistAuthor = canon
                    view.ownerView?.text = "\(canon) - \((view.partialPlaylist?.trackCount)!) songs"
                }
                else {
                    print("nil owner: \(user.displayName) - \(user.canonicalUserName)")
                }
            }
            else {
                print("What we got back isn't an SPTUser: \(obj)")
            }
        })
        
        return view
    }
    
    private func build() {
        let width = Int((self.owner?.frame.width)!)
        let height = 55
        
        self.frame = CGRect(x: 0, y: 0, width: width, height: height)
        
        self.imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: height, height: height))
        self.nameView = UILabel(frame: CGRect(x: height+10, y: 3, width: width-40-5, height: 20))
        self.ownerView = UILabel(frame: CGRect(x: height+10, y: 5+20, width: width-40-5, height: 20))
        
        self.loadImage()
        
        
        self.nameView = UILabel(frame: CGRect(x: height+2, y: 0, width: width - 40 - 5, height: 20))
        //Helper.setBorder(self.nameView!, UIColor.yellow, 1)
        self.nameView?.textColor = UIColor.black
        self.nameView?.font = UIFont.boldSystemFont(ofSize: CGFloat(16))
        self.nameView?.text = self.playlistName!
        self.nameView?.frame.size = CGSize(width: CGFloat(width-height-5), height: (self.nameView?.font.ascender)! + 3)
        
        self.ownerView = UILabel(frame: CGRect(x: height+2, y: Int((self.nameView?.frame.height)!), width: width - 40 - 5, height: 20))
        //Helper.setBorder(self.artistView!, UIColor.gray, 1)
        
        self.ownerView?.textColor = UIColor.darkGray
        self.ownerView?.font = UIFont.systemFont(ofSize: CGFloat(14.5))
        self.ownerView?.text = ""
        self.ownerView?.frame.size = CGSize(width: CGFloat(width - height - 5), height: (self.ownerView?.font.ascender)! + 3)
        
        self.addSubview(self.imageView!)
        self.addSubview(self.nameView!)
        self.addSubview(self.ownerView!)
    }
    
    private func loadImage() {
        if self.playlistImage != nil {
            URLSession.shared.dataTask(with: (self.playlistImage?.imageURL)!) {
                (data, response, error) in
                if error != nil {
                    print("Error on dataTask: \(error)")
                    return
                }
                DispatchQueue.main.async {
                    self.imageView?.image = UIImage(data: data!)
                }
                }.resume()
        }
        else {
            self.imageView?.image = UIImage(named: "playlistsIcon_black")
        }
    }
    
}
