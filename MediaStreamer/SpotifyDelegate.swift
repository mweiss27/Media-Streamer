//
//  SpotifyDelegate.swift
//  MediaStreamer
//
//  Created by Matt Weiss on 2/24/17.
//  Copyright © 2017 Matt Weiss. All rights reserved.
//

import UIKit
import AVFoundation
import AudioToolbox

class SpotifyDelegate: NSObject, SPTAudioStreamingDelegate, SPTAudioStreamingPlaybackDelegate {
    
    private var roomController: RoomController!
    var spotifyPlayer: SpotifyPlayer?
    
    init(_ roomController: RoomController!) {
        self.roomController = roomController
    }
    
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController!, didStartPlayingTrack trackUri: String!) {
        print("Spotify.didStartPlayingTrack")
        do {
            try self.roomController.audioSession.setCategory(AVAudioSessionCategoryPlayback)
            try self.roomController.audioSession.setActive(true)
            UIApplication.shared.beginReceivingRemoteControlEvents()
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
    
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController!, didChange metadata: SPTPlaybackMetadata!) {
        if let meta = metadata {
            print("MetaData changed")
            if let currentTrack = meta.currentTrack {
                let songName = currentTrack.name
                let artist = currentTrack.artistName
                
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
        if let duration = audioStreaming.metadata.currentTrack?.duration {
            self.roomController.currentPlaybackTime.progress = Float(position/duration)
            if let player = self.spotifyPlayer {
                player.progressSlider.value = Float(position/duration)
            }
        }
    }
    
    
}
