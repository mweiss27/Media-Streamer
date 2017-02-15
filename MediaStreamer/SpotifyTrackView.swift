//
//  SpotifyTrackView.swift
//  MediaStreamer
//
//  Created by Matt Weiss on 2/7/17.
//  Copyright © 2017 Matt Weiss. All rights reserved.
//

import UIKit

class SpotifyTrackView: UIView {
    
    var owner: UIView?
    var song: SPTPartialTrack?
    
    private var songName: String?
    private var artistName: String?
    
    private var addView: UIImageView?
    private var nameView: UILabel?
    private var artistView: UILabel?
    
    static func initWith(owner: UIView, song: SPTPartialTrack) -> SpotifyTrackView {
        //print("initWith(\(owner), \(song)")
        let view = SpotifyTrackView()
        view.song = song
        view.owner = owner
        view.songName = song.name
        view.artistName = SpotifyApp.getArtist(artists: song.artists)
        
        view.build()
        
        return view
    }
    
    private func build() {
        let width = Int((self.owner?.frame.width)!)
        let gap = 3
        
        self.frame = CGRect(x: 0, y: 0, width: width, height: 0)
        /*self.layer.borderColor = UIColor.yellow.cgColor
         self.layer.borderWidth = 1*/
        
        self.addView = UIImageView(frame: CGRect(x: 0, y: 0, width: 16, height: 16))
        self.addView?.image = UIImage(named: "plusButton_black")
        
        self.nameView = UILabel(frame: CGRect(x: 24, y: 0, width: width - 40 - 5, height: 20))
        //Helper.setBorder(self.nameView!, UIColor.yellow, 1)
        
        self.nameView?.textColor = UIColor.black
        self.nameView?.font = UIFont.boldSystemFont(ofSize: CGFloat(15))
        self.nameView?.text = self.songName!
        self.nameView?.frame.size = CGSize(width: CGFloat(width-40-5), height: (self.nameView?.font.ascender)! + 3)
        
        self.artistView = UILabel(frame: CGRect(x: 24, y: Int((self.nameView?.frame.height)!), width: width - 40 - 5, height: 20))
        //Helper.setBorder(self.artistView!, UIColor.gray, 1)
        
        self.artistView?.textColor = UIColor.darkGray
        self.artistView?.font = UIFont.systemFont(ofSize: CGFloat(13.5))
        self.artistView?.text = self.artistName!
        self.artistView?.frame.size = CGSize(width: CGFloat(width - 40 - 5), height: (self.artistView?.font.ascender)! + 3)
        
        self.frame.size = CGSize(width: width, height: Int((self.nameView?.frame.height)! + (self.artistView?.frame.height)!) + gap)
        
        self.addView?.frame.origin = CGPoint(x: 0, y: 8)
        //print("Setting addView origin to \(self.addView?.frame)")
        
        self.addSubview(self.addView!)
        self.addSubview(self.nameView!)
        self.addSubview(self.artistView!)
    }
    
}
