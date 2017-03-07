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
        self.roomController.room?.resume(true)
    }
    
    @objc private func pause() {
        self.roomController.room?.pause(true)
    }
    
    @objc private func pausePlay() {
        if SpotifyApp.player.playbackState.isPlaying {
            pause()
        }
        else {
            play()
        }
    }
    
    @objc private func next() {
        if self.roomController.room?.queue.currentMedia != nil {
            self.roomController.room?.playNextSong(startTime: 0.0, true)
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
        print("Spotify.didStartPlayingTrack: \(trackUri)")
        if let meta = audioStreaming.metadata {
            if let track = meta.currentTrack {
                print("Current track: \(track.name)")
            }
            else {
                print("nil track")
            }
        }
        else {
            print("nil meta")
        }
        
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
    
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController!, didReceive event: SpPlaybackEvent) {
        //This event is called when the current playlist reaches the end.
        //We always have 1 song in our actual Spotify Queue -- the current song
        if event == SPPlaybackNotifyAudioDeliveryDone {
            if self.roomController.room?.queue.front != nil {
                if (self.roomController.room?.canInvokePlay())! {
                    self.roomController.room?.playNextSong(startTime: 0.0, true)
                }
                
            }
        }
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
        if self.roomController.room?.queue.currentMedia != nil {
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
                            
                            if self.roomController.room?.queue.currentMedia != nil {
                                let image = UIImage(data: data!)
                                print("[2] No error. Setting image!")
                                let artwork = MPMediaItemArtwork.init(boundsSize: image!.size, requestHandler: { (size) -> UIImage in
                                    return image!
                                })
                                self.info[MPMediaItemPropertyArtwork] = artwork
                                self.infoCenter.nowPlayingInfo = self.roomController?.spotifyDelegate?.info
                            }
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
    }
    
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController!, didChangePosition position: TimeInterval) {
        if self.roomController.room?.queue.currentMedia != nil {
            if let duration = audioStreaming.metadata.currentTrack?.duration {
                let val = Float(position/duration)
                self.roomController.currentPlaybackTime.progress = val
                if let player = self.spotifyPlayer {
                    if !player.dragging {
                        player.progressSlider.value = val
                    }
                }
            }
        }
    }
    
    
}
