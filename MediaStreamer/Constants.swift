//
//  Constants.swift
//  MediaStreamer
//
//  Created by Matt Weiss on 1/29/17.
//  Copyright © 2017 Matt Weiss. All rights reserved.
//

import Foundation

class Constants {
    
    static let clientID = "2da635f7c6224a24b10cd8c2566b4e8b"
    static let redirectURL = "mediastreamerspotifyauth://callback"
    static let requestedScopes = [
        SPTAuthStreamingScope,
        SPTAuthPlaylistReadPrivateScope,
        SPTAuthPlaylistReadCollaborativeScope,
        SPTAuthUserReadPrivateScope,
        SPTAuthUserReadTopScope ]
    
    static let tokenSwapURL = "https://spotify-refresh-token.herokuapp.com/swap"
    static let tokenRefreshServiceURL = "https://spotify-refresh-token.herokuapp.com/refresh"
    
    /*
     static let tokenSwapURL = "http://localhost:1234/swap"
     static let tokenRefreshServiceURL = "http://localhost:1234/refresh"
     */
    
    static let RoomToSpotify: String = "room_to_spotify"
    static let LogintoPlaylists: String = "login_to_playlists"
    static let PlaylistToSongs: String = "playlist_to_songs"
    static let SongsToPlayer: String = "songs_to_player"
    
    
    static let BrowseSpotifyLibrary: String = "Search the Spotify library"
    static let ShowingResults = "Showing %d results"
    
    static let ENTER_ROOM = "enterRoom"
    static let ERROR_TIMEOUT = "timeout"
    
}
