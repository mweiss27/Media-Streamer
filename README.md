Barebones functionality from Matt's perspective:

    Users should be required to make an account using minimal information:
        Username
        Password

    Allow a user to create or join a group via invite
        Invite can be by phone number or username

    Groups have a few properties
        Display Name
        User List
            From the list, we can display icons showing what sort of activity the user is up to
            You can expand a certain user to view more details about this activity
                --Song name/artist, Video name, etc...
                Option to "watch with" or "listen with"
                    --Send a notification to the user that a user is "watching/listening with them"? 
                      Option that could be disabled by default?

    From an API standpoint, we know that Spotify's iOS SDK exposes information about current playing information. We need to get this setup to see if this pulls the information locally from the device, requiring no login, or if it makes web API calls, which would require us to sign-in to Spotify from within the app. My guess is that it pulls it from the device.

    I would say a user would have to hit a button to begin acting as a "broadcaster"
        By broadcaster, I mean that they are going to appear as someone who can be synced with
        A broadcaster can only broadcast one media channel at a time.
        A broadcaster can have many "followers"
            By follower, I mean someone who wants to sync up with a broadcaster

    When a user opts to "broadcast" their activity, we need to store a few bits of information
        Remote ip address
        Remote port

    The same goes for a "client" (someone who wants to sync up with another user)
    

    The app should, for a broadcaster, check periodically for a change in media status
        This goes for a song, video, play/pause status, or the playback time

    To sync people up, a broadcaster will publish to the server some information:
        App id (e.g. 1=Spotify, 2=YouTube)
        Media id (As provided by the respective API)
        Playback time (As provided by the API)
        Snapshot time (local timestamp, ideally in milliseconds that the Playback time was taken)

    Now the follower can view this information
        Let PlaybackTime be 46819 (46.819s)
        Let SnapshotTime be 50000000 (some timestamp to milliseconds precision)
        
        The follower will have a different local time from the broadcasters SnapshotTime
        dt = SnapshotTime - localTime
        set followerPlayback to Playback + dt
            Ensure units are all the same, seconds vs millis
        
        
