//
//  SpotifySearchController.swift
//  MediaStreamer
//
//  Created by Matt Weiss on 2/6/17.
//  Copyright © 2017 Matt Weiss. All rights reserved.
//

import UIKit

class SpotifySearchController: UIViewController, UIScrollViewDelegate {
    
    @IBOutlet weak var searchResultsHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var searchResults: UIView!
    @IBOutlet weak var searchHeader: UILabel!
    @IBOutlet weak var searchField: UITextField!
    
    private var playlists: [SPTPartialPlaylist]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        (self.searchResults.superview as! UIScrollView).delegate = self
        self.searchField.addTarget(self, action: #selector(self.textFieldDidChange(textField:)), for: .editingChanged)
        
        print("SpotifySearchController is displayed")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.initPlaylists()
        
    }
    
    private var searchAt: Int64? = nil
    private var searchWaiting: Bool = false
    private var updateLock = DispatchQueue(label: "updateLock")
    private var background = DispatchQueue(label: "background")
    private var searchResult: SPTListPage?
    
    @IBOutlet weak var returnToPlaylists: UIButton!
    func textFieldDidChange(textField: UITextField) {
        let now = self.currentTimeMillis()
        if self.searchWaiting {
            searchAt = now + 1000
        }
        else {
            self.searchAt = self.currentTimeMillis() + 1000
            self.updateLock.sync {
                self.searchWaiting = true
            }
            
            self.background.async {
                while self.currentTimeMillis() < self.searchAt! {
                    usleep(useconds_t(UInt(0.1E6)))
                }
                
                print("Running search for \(textField.text)")
                
                //DispatchQueue.main.sync {
                    
                    Helper.removeAllSubviews(view: self.searchResults)
                    
                    self.searchResultsHeightConstraint.constant = 0
                    self.searchHeader.text = Constants.BrowseSpotifyLibrary
                //}
                
                if let text = textField.text {
                    if text.characters.count > 0 {
                        SPTSearch.perform(withQuery: text, queryType: SPTSearchQueryType.queryTypeTrack, accessToken: SPTAuth.defaultInstance().session.accessToken, callback: { (error, obj) in
                            if error != nil {
                                print("Error on SPTSearch.perform: \(error?.localizedDescription)")
                                return
                            }
                            
                            if let result = obj as? SPTListPage {
                                self.searchResult = result
                                print("... \(result.totalListLength) items total")
                                
                                self.loadMoreResults()
                            }
                            else {
                                //DispatchQueue.main.sync {
                                    self.searchHeader.text = "No results found"
                                //}
                            }
                        })
                    }
                    else {
                        self.searchResult = nil
                        //DispatchQueue.main.sync {
                            self.buildPlaylists()
                        //}
                    }
                }
                
                self.updateLock.sync {
                    self.searchWaiting = false
                }
            }
        }
        
    }
    
    func initPlaylists() {
        print("PlaylistController.initPlaylists")
        SPTUser.requestCurrentUser(withAccessToken: SPTAuth.defaultInstance().session.accessToken) { (error, obj) in
            if error != nil {
                print("Error on requesetCurrentUser: \(error?.localizedDescription)")
                return
            }
            
            if obj != nil {
                if obj is SPTUser {
                    print("Got an SPTUser object")
                    let user = obj as! SPTUser
                    let accessToken = SPTAuth.defaultInstance().session.accessToken
                    
                    print("Currently logged in as: \(user.displayName)")
                    
                    SPTPlaylistList.playlists(forUser: user.canonicalUserName, withAccessToken: accessToken, callback: { (error, playlists) in
                        if error != nil {
                            print("Error on .playlists: \(error?.localizedDescription)")
                            return
                        }
                        
                        print("\(Mirror(reflecting: playlists!).subjectType)")
                        if playlists is SPTPlaylistList {
                            let listlist = playlists as! SPTPlaylistList
                            let items = listlist.items
                            
                            if items != nil {
                                self.playlists = []
                                for item in items! {
                                    if item is SPTPartialPlaylist {
                                        let partial = item as! SPTPartialPlaylist
                                        self.playlists?.append(partial)
                                    }
                                }
                                
                                if let text = self.searchField.text {
                                    if text.characters.count == 0 {
                                        self.buildPlaylists()
                                    }
                                }
                                
                            }
                        }
                    })
                }
            }
        }
        
    }
    
    private func buildPlaylists() {
        print("PlaylistsController.buildPlaylists")
        Helper.removeAllSubviews(view: self.searchResults)
        
        self.searchResultsHeightConstraint.constant = 0
        self.searchHeader.text = Constants.BrowseSpotifyLibrary
        
        self.searchField.endEditing(true)
        if self.playlists != nil {
            
            var y = 0
            
            self.searchHeader.text = "Playlists"
            for partial in self.playlists! {
                let view = SpotifyPlaylistView.initWith(owner: self.searchResults, playlist: partial)
                view.frame.origin.y = CGFloat(y)
                
                let gesture = UITapGestureRecognizer.init(target: self, action: #selector(self.playlistTapped(_:)))
                view.addGestureRecognizer(gesture)
                
                self.searchResults.addSubview(view)
                y += Int(view.frame.height + 3)
            }
            self.searchResultsHeightConstraint.constant = CGFloat(y)
        }
    }
    
    func playlistTapped(_ sender: UITapGestureRecognizer) {
        
        if let source = sender.view as? SpotifyPlaylistView {
            print("Playlist Tapped: \(source.playlistName!)")
            
            if let partial = source.partialPlaylist {
                self.background.async {
                    self.enterPlaylist(partial: partial)
                }
            }
            else {
                print("nil partial")
            }
            
        }
        else {
            print("Bad source")
        }
        
    }
    
    private func enterPlaylist(partial: SPTPartialPlaylist!) {
        SPTPlaylistSnapshot.playlist(withURI: partial.playableUri, accessToken: SPTAuth.defaultInstance().session.accessToken, callback: { (error, obj) in
            if error != nil {
                print("Error on SPTPlaylistSnapshot.playlist: \(error?.localizedDescription)")
                return
            }
            if let snapshot = obj as? SPTPlaylistSnapshot {
                self.searchResult = snapshot.firstTrackPage
                
                print("Wiping all subviews")
                //DispatchQueue.main.sync {
                    Helper.removeAllSubviews(view: self.searchResults)
                    
                    self.searchResultsHeightConstraint.constant = 0
                    self.searchHeader.text = Constants.BrowseSpotifyLibrary
                    
                    self.returnToPlaylists.isHidden = false
                    self.searchField.isHidden = true
                    
                //}
                print("Continuing to load results")
                self.loadMoreResults()
            }
            else {
                print("Invalid result obj: \(obj)")
            }
        })
    }
    
    private var busy: Bool = false
    private func loadMoreResults() {
        self.busy = true
        if self.searchResult?.items != nil {
            
            //+1 because our last task is to load the next page
            
            for item in (self.searchResult?.items)! {
                if let track = item as? SPTPartialTrack {
                    
                    SPTPlaylistTrack.track(withURI: track.playableUri, accessToken: SPTAuth.defaultInstance().session.accessToken, market: nil, callback: { (error, obj) in
                        if error != nil {
                            print("Error on SPTPlaylistTrack.track: \(error?.localizedDescription)")
                            return
                        }
                        if let track = obj as? SPTTrack {
                            if track.name != nil && track.artists != nil {
                                //DispatchQueue.main.sync {
                                    
                                    let view = SpotifyTrackView.initWith(owner: self.searchResults, song: track)
                                    
                                    let y = Int(view.frame.height + 2) * self.searchResults.subviews.count
                                    view.frame.origin = CGPoint(x: 0, y: y)
                                    
                                    let gest = UITapGestureRecognizer.init(target: self, action: #selector(self.songClicked(_:)))
                                    view.addGestureRecognizer(gest)
                                    
                                    self.searchResults.addSubview(view)
                                    self.searchResultsHeightConstraint.constant = CGFloat(self.searchResults.subviews.count) * (view.frame.height + 2)
                                    
                                    self.searchHeader.text = String(format: Constants.ShowingResults, self.searchResults.subviews.count)
                                //}
                            }
                        }
                    })
                    
                }
            }
            if (self.searchResult?.hasNextPage)! {
                
                self.searchResult?.requestNextPage(withAccessToken: SPTAuth.defaultInstance().session.accessToken, callback: {
                    (err, obj) in
                    if err != nil {
                        print("Error on requestNextPage: \(err?.localizedDescription)")
                        self.busy = false
                        return
                    }
                    
                    print("Got our next page")
                    if obj != nil {
                        print("Type of obj: \(Mirror(reflecting: obj!).subjectType)")
                        
                        if let nextPage = obj as? SPTListPage {
                            self.searchResult = nextPage
                        }
                    }
                    else {
                        print("obj is nil??")
                    }
                    self.busy = false
                    
                })
            }
            else {
                self.searchResult = nil
                self.busy = false
            }
        }
    }
    
    func songClicked(_ sender: UITapGestureRecognizer) {
        if let source = sender.view as? SpotifyTrackView {
            print("songClicked: \(source.song!)")
        }
        else {
            print("[ERROR] source is nil or not SpotifyTrackView: \(sender.view)")
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.searchField.endEditing(true)
        let percent = (scrollView.frame.height + scrollView.contentOffset.y) / scrollView.contentSize.height
        if !self.busy {
            if percent > 0.9 {
                self.loadMoreResults()
            }
        }
    }
    
    @IBAction func returnToPlaylistsClicked(_ sender: Any) {
        print("returnToPlaylistsClicked")
        self.returnToPlaylists.isHidden = true
        self.searchField.isHidden = false
        
        self.buildPlaylists()
        
    }
    
    private func currentTimeMillis() -> Int64 {
        let nowDouble = NSDate().timeIntervalSince1970
        return Int64(nowDouble*1000)
    }
    
}
