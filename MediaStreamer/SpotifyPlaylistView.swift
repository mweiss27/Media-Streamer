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
    private var artistView: UILabel?
    
    static func initWith(owner: UIView, playlist: SPTPartialPlaylist) -> SpotifyPlaylistView {
        let view = SpotifyPlaylistView()
        view.owner = owner
        view.partialPlaylist = playlist
        view.playlistImage = playlist.largestImage
        view.playlistName = playlist.name
        view.playlistAuthor = playlist.owner.displayName
        print("Building a SpotifyPlaylistView: \(view.playlistName) - \(view.playlistAuthor)")
        view.build()
        
        return view
    }
    
    private func build() {
        let width = Int((self.owner?.frame.width)!)
        let height = 40
        
        self.frame = CGRect(x: 0, y: 0, width: width, height: height)
        
        self.imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: height, height: height))
        self.nameView = UILabel(frame: CGRect(x: height+5, y: 3, width: width-40-5, height: 20))
        self.artistView = UILabel(frame: CGRect(x: height+5, y: 5+20, width: width-40-5, height: 20))
        
        self.loadImage()
        
        self.nameView?.textColor = UIColor.black
        self.nameView?.text = self.playlistName
        
        self.artistView?.textColor = UIColor.darkGray
        self.artistView?.text = self.playlistAuthor
        
        self.addSubview(self.imageView!)
        self.addSubview(self.nameView!)
        self.addSubview(self.artistView!)
    }
    
    private func loadImage() {
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
    
}
