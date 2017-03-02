//
//  SpotifyDelegate.swift
//  MediaStreamer
//
//  Created by Matt Weiss on 2/24/17.
//  Copyright © 2017 Matt Weiss. All rights reserved.
//

import UIKit
import AVFoundation
import MediaPlayer

class SpotifyDelegate: NSObject, SPTAudioStreamingDelegate, SPTAudioStreamingPlaybackDelegate {
    
    private var roomController: RoomController!
    var spotifyPlayer: SpotifyPlayer?
    
    public var info: [String:Any] = [:]
    public let infoCenter = MPNowPlayingInfoCenter.default()
    
    private let commandCenter = MPRemoteCommandCenter.shared()
    
    init(_ roomController: RoomController!) {
        super.init()
        self.roomController = roomController
        
        self.commandCenter.playCommand.addTarget(self, action: #selector(self.play))
        self.commandCenter.pauseCommand.addTarget(self, action: #selector(self.pause))
        self.commandCenter.togglePlayPauseCommand.addTarget(self, action: #selector(self.pausePlay))
        self.commandCenter.nextTrackCommand.addTarget(self, action: #selector(self.next))
    }
    
    @objc private func play() {
        if self.roomController.room?.queue.currentMedia != nil {
            SpotifyApp.player.setIsPlaying(true) { (error) in
                if let error = error {
                    print("Error on setIsPlaying true: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @objc private func pause() {
        if self.roomController.room?.queue.currentMedia != nil {
            SpotifyApp.player.setIsPlaying(false) { (error) in
                if let error = error {
                    print("Error on setIsPlaying false: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @objc private func pausePlay() {
        if self.roomController.room?.queue.currentMedia != nil {
            do {
                SpotifyApp.player.setIsPlaying(!SpotifyApp.player.playbackState.isPlaying) { (error) in
                    if let error = error {
                        print("Error on setIsPlaying toggle: \(error.localizedDescription)")
                    }
                }
            }
            catch let error {
                print("Error on setIsPlaying(!isPlaying)")
            }
        }
    }
    
    @objc private func next() {
        if self.roomController.room?.queue.currentMedia != nil {
            self.roomController.room?.playNextSong()
        }
    }
    
    func audioStreamingDidLogin(_ audioStreaming: SPTAudioStreamingController!) {
        if self.roomController.onLogin != nil {
            self.roomController.onLogin!()
        }
    }
    
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController!, didReceiveError error: Error!) {
        if self.roomController.onError != nil {
            self.roomController.onError!(error)
        }
    }
    
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController!, didStartPlayingTrack trackUri: String!) {
        print("Spotify.didStartPlayingTrack")
        do {
            
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
            try AVAudioSession.sharedInstance().setActive(true)
            
            
        } catch let error {
            print("Error on audioSession.setCategory or setActive: \(error.localizedDescription)")
        }
    }
    
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController!, didStopPlayingTrack trackUri: String!) {
        print("Spotify.didStopPlayingTrack")
    }
    
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController!, didChangePlaybackStatus isPlaying: Bool) {
        print("Spotify.didChangePlaybackStatus: \(isPlaying)")
        
        if let player = self.spotifyPlayer {
            player.pausePlay.setImage(UIImage(named: isPlaying ? "pauseButton" : "playButton"), for: .normal)
        }
        else {
            print("No SpotifyPlayer set")
        }
    }
    
    private var lastImageURI: String?
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController!, didChange metadata: SPTPlaybackMetadata!) {
        if let meta = metadata {
            print("MetaData changed")
            if let currentTrack = meta.currentTrack {
                let songName = currentTrack.name
                let artist = currentTrack.artistName
                
                self.info[MPMediaItemPropertyTitle] = songName
                self.info[MPMediaItemPropertyArtist] = artist
                self.info[MPMediaItemPropertyPlaybackDuration] = metadata.currentTrack?.duration
                self.info[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
                
                let curImageURI = metadata.currentTrack?.albumCoverArtURL
                if self.lastImageURI != curImageURI {
                    self.lastImageURI = curImageURI
                    URLSession.shared.dataTask(with: URL(string: curImageURI!)!) {
                        (data, response, error) in
                        if error != nil {
                            print("Error on dataTask: \(error)")
                            self.lastImageURI = nil
                            return
                        }
                        let image = UIImage(data: data!)
                        print("[2] No error. Setting image!")
                        let artwork = MPMediaItemArtwork.init(boundsSize: image!.size, requestHandler: { (size) -> UIImage in
                            return image!
                        })
                        self.info[MPMediaItemPropertyArtwork] = artwork
                        self.infoCenter.nowPlayingInfo = self.roomController?.spotifyDelegate?.info
                        }.resume()
                    
                }
                
                self.infoCenter.nowPlayingInfo = self.info
                
                
                self.roomController.currentSongName.text = songName
                self.roomController.currentArtistName.text = artist
                
                if let player = self.spotifyPlayer {
                    player.songName.text = songName
                    player.artistName.text = artist
                    player.setImage(currentTrack.albumCoverArtURL)
                }
                else {
                    print("No SpotifyPlayer set")
                }
            }
        }
    }
    
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController!, didChangePosition position: TimeInterval) {
        if self.roomController.room?.queue.currentMedia != nil {
            if let duration = audioStreaming.metadata.currentTrack?.duration {
                self.roomController.currentPlaybackTime.progress = Float(position/duration)
                if let player = self.spotifyPlayer {
                    player.progressSlider.value = Float(position/duration)
                }
            }
        }
    }
    
    
}
