//
//  SpotifySearchController.swift
//  MediaStreamer
//
//  Created by Matt Weiss on 2/6/17.
//  Copyright © 2017 Matt Weiss. All rights reserved.
//

import UIKit

class SpotifySearchController: UIViewController, UIScrollViewDelegate {
    
    var roomController: RoomController?
    
    private var searchAt: Int64? = nil
    private var searchWaiting: Bool = false
    private var updateLock = DispatchQueue(label: "updateLock")
    private var background = DispatchQueue(label: "background")
    private var searchResult: SPTListPage?
    
    @IBOutlet weak var searchResultsHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var searchResults: UIView!
    @IBOutlet weak var searchHeader: UILabel!
    @IBOutlet weak var searchField: UITextField!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    
    @IBOutlet weak var searchScroll: UIScrollView!
    private var playlists: [SPTPartialPlaylist]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        (self.searchResults.superview as! UIScrollView).delegate = self
        self.searchField.addTarget(self, action: #selector(self.textFieldDidChange(textField:)), for: .editingChanged)
        
        let button = self.createLogoutButton()
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem.init(customView: button)
        
        self.loadingIndicator.isHidden = true
        
        self.initPlaylists()
        print("SpotifySearchController is displayed")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if self.isMovingToParentViewController {
            self.roomController?.resignFirstResponder()
            self.becomeFirstResponder()
        }
        print("viewDidAppear")
        
        /*
         Import ALToastView.h and call static toastInView:withText: for every new toast message you want to show, e.g in your UIViewController subclass call [ALToastView toastInView:self.view withText:@"Hello ALToastView"];
         */
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        if self.isMovingFromParentViewController {
            
            self.resignFirstResponder()
            self.roomController?.becomeFirstResponder()
        }
    }
    
    
    override var canBecomeFirstResponder: Bool {
        get {
            return true
        }
    }
    
    override func motionEnded(_ motion: UIEventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            if let state = SpotifyApp.player.playbackState {
                if state.isPlaying {
                    self.roomController?.requestPause()
                }
                else {
                    self.roomController?.requestResume()
                }
            }
        }
    }
    
    private func createLogoutButton() -> UIButton {
        let button = UIButton.init(frame: CGRect.init(x: 0, y: 0, width: 26, height: 22))
        button.setImage(UIImage.init(named: "logoutButton"), for: .normal)
        button.addTarget(self, action: #selector(self.logout), for: .touchUpInside)
        
        return button
    }
    
    @objc private func logout() {
        let alert = UIAlertController(title: "Logout", message: "Are you sure you want to logout of Spotify?", preferredStyle: UIAlertControllerStyle.alert)
        
        alert.addAction(UIAlertAction(title: "Logout", style: UIAlertActionStyle.default, handler: { action in
            
            if let playbackState = SpotifyApp.player.playbackState {
                SpotifyApp.player.setIsPlaying(false, callback: { error in
                    if error != nil {
                        Helper.alert(title: "Error", message: "An error occurred while attempting to logout.")
                        return
                    }
                    
                    self.callLogout()
                })
            }
            else {
                self.callLogout()
            }
            
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: nil))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    private func callLogout() {
        self.roomController?.onLogout = {
            
            self.navigationController?.popViewController(animated: true)
            SpotifyApp.saveSession(session: nil)
            self.roomController?.spotifyButton.removeTarget(nil, action: nil, for: .allEvents)
            self.roomController?.spotifyButton.addTarget(self.roomController!, action: #selector(self.roomController?.spotifyButtonClickedNotAuthed(_:)), for: .touchUpInside)
            
            self.roomController?.room?.currentSong = nil
            
            self.roomController?.currentSongName.text = ""
            self.roomController?.currentArtistName.text = ""
            self.roomController?.currentPlaybackTime.progress = 0.0
            
            self.roomController?.onLogout = nil
        }
        
        self.roomController?.onError = { error in
            Helper.alert(title: "Error", message: "An error occurred while attempting to logout.")
            self.roomController?.onError = nil
        }
        
        SpotifyApp.player.logout()
    }
    
    @IBOutlet weak var returnToPlaylists: UIButton!
    func textFieldDidChange(textField: UITextField) {
        let now = Helper.currentTimeMillis()
        
        Helper.removeAllSubviews(view: self.searchResults)
        self.searchScroll.scrollRectToVisible(CGRect(x: 0, y: 0, width: 1, height: 1), animated: false)
        
        self.searchResultsHeightConstraint.constant = 0
        self.loadingIndicator.isHidden = false
        
        if self.searchWaiting {
            searchAt = now + 1000
        }
        else {
            self.searchAt = Helper.currentTimeMillis() + 1000
            
            self.updateLock.sync {
                self.searchWaiting = true
            }
            
            self.background.async {
                while Helper.currentTimeMillis() < self.searchAt! {
                    usleep(useconds_t(UInt(0.1E6)))
                }
                
                print("Running search for \(textField.text)")
                
                self.searchHeader.text = Constants.BrowseSpotifyLibrary
                
                if let text = textField.text {
                    if text.characters.count > 0 {
                        SPTSearch.perform(withQuery: text, queryType: SPTSearchQueryType.queryTypeTrack, accessToken: SPTAuth.defaultInstance().session.accessToken, callback: { (error, obj) in
                            self.loadingIndicator.isHidden = true
                            if error != nil {
                                print("Error on SPTSearch.perform: \(error?.localizedDescription)")
                                if ((error?.localizedDescription.contains("offline"))! || (error?.localizedDescription.contains("104"))!) {
                                    Helper.networkFail(self.navigationController!)
                                }
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
                        DispatchQueue.main.sync {
                            self.loadingIndicator.isHidden = true
                            self.buildPlaylists()
                        }
                    }
                }
                else {
                    DispatchQueue.main.sync {
                        self.loadingIndicator.isHidden = true
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
        
        self.loadingIndicator.isHidden = false
        SPTUser.requestCurrentUser(withAccessToken: SPTAuth.defaultInstance().session.accessToken) { (error, obj) in
            self.loadingIndicator.isHidden = true
            if error != nil {
                print("Error on requestCurrentUser: \(error?.localizedDescription)")
                
                if (error?.localizedDescription.contains("offline"))! {
                    Helper.networkFail(self.navigationController!)
                }
                
                return
            }
            
            if obj != nil {
                if obj is SPTUser {
                    print("Got an SPTUser object")
                    let user = obj as! SPTUser
                    let accessToken = SPTAuth.defaultInstance().session.accessToken
                    
                    print("Currently logged in as: \(user.displayName)")
                    
                    print("Requesting user playlists")
                    self.loadingIndicator.isHidden = false
                    SPTPlaylistList.playlists(forUser: user.canonicalUserName, withAccessToken: accessToken, callback: { (error, playlists) in
                        self.loadingIndicator.isHidden = true
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
        self.searchScroll.scrollRectToVisible(CGRect(x: 0, y: 0, width: 1, height: 1), animated: false)
        
        self.searchResultsHeightConstraint.constant = 0
        self.searchHeader.text = Constants.BrowseSpotifyLibrary
        
        if self.searchField.isEditing {
            self.searchField.endEditing(true)
        }
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
                print(">>enterPlaylist")
                self.enterPlaylist(partial: partial)
                print("<<enterPlaylist")
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
                if (error?.localizedDescription.contains("offline"))! {
                    if (error?.localizedDescription.contains("offline"))! {
                        Helper.networkFail(self.navigationController!)
                    }
                }
                return
            }
            if let snapshot = obj as? SPTPlaylistSnapshot {
                self.searchResult = snapshot.firstTrackPage
                
                print("Wiping all subviews")
                Helper.removeAllSubviews(view: self.searchResults)
                self.searchScroll.scrollRectToVisible(CGRect(x: 0, y: 0, width: 1, height: 1), animated: false)
                
                self.searchResultsHeightConstraint.constant = 0
                self.searchHeader.text = Constants.BrowseSpotifyLibrary
                
                self.returnToPlaylists.isHidden = false
                self.searchField.isHidden = true
                
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
        if self.searchResult?.items != nil {
            print("Loading \(self.searchResult?.items.count) more items")
            let items = (self.searchResult?.items)!
            
            let now = Helper.currentTimeMillis()
            for item in items {
                
                if let track = item as? SPTPartialTrack {
                    
                    let view = SpotifyTrackView.initWith(owner: self.searchResults, song: track)
                    
                    let y = Int(view.frame.height + 2) * self.searchResults.subviews.count
                    view.frame.origin = CGPoint(x: 0, y: y)
                    
                    let gest = UITapGestureRecognizer.init(target: self, action: #selector(self.songClicked(_:)))
                    view.addGestureRecognizer(gest)
                    
                    self.searchResults.addSubview(view)
                    self.searchResultsHeightConstraint.constant = CGFloat(self.searchResults.subviews.count) * (view.frame.height + 2)
                    
                    self.searchHeader.text = String(format: Constants.ShowingResults, self.searchResults.subviews.count)
                    
                }
            }
            print("Added subviews in \(Helper.currentTimeMillis() - now)ms")
        }
        else {
            print("items is nil")
        }
    }
    
    func songClicked(_ sender: UITapGestureRecognizer) {
        if let source = sender.view as? SpotifyTrackView {
            print("songClicked: \(source.song!)")
            let time = Helper.currentTimeMillis()
            SocketIOManager.emit("request_add",
                                 [
                                    (source.song?.playableUri.absoluteString)!,
                                    (source.song?.name)!,
                                    SpotifyApp.getArtist(artists: source.song?.artists),
                                    Int(time)
                ], true, nil)
        }
        else {
            print("[ERROR] source is nil or not SpotifyTrackView: \(sender.view)")
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.searchField.endEditing(true)
        let percent = (scrollView.frame.height + scrollView.contentOffset.y) / scrollView.contentSize.height
        if percent > 0.75 {
            let now = Helper.currentTimeMillis()
            if self.searchResult != nil {
                if !self.busy {
                    self.busy = true
                    if (self.searchResult?.hasNextPage)! {
                        self.searchResult?.requestNextPage(withAccessToken: SPTAuth.defaultInstance().session.accessToken, callback: { (error, obj) in
                            defer {
                                self.busy = false
                            }
                            
                            if error != nil {
                                print("Error on requestNextPage: \(error!.localizedDescription)")
                                return
                            }
                            
                            if let page = obj as? SPTListPage {
                                self.searchResult = page
                                self.loadMoreResults()
                            }
                            
                        })
                    }
                    else {
                        self.searchResult = nil
                        self.busy = false
                    }
                    print("Processed >0.75 scroll in \(Helper.currentTimeMillis() - now)ms")
                }
            }
        }
    }
    
    @IBAction func returnToPlaylistsClicked(_ sender: Any) {
        print("returnToPlaylistsClicked")
        self.searchResult = nil
        self.returnToPlaylists.isHidden = true
        self.searchField.isHidden = false
        
        self.buildPlaylists()
        
    }
    
}
