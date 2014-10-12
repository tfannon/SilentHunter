//
//  AudioHelper.swift
//  AnyDeck
//
//  Created by Adam Rothberg on 8/2/14.
//  Copyright (c) 2014 Adam Rothberg. All rights reserved.
//

import Foundation
import AVFoundation

class AudioPlayer : NSObject, AVAudioPlayerDelegate
{
    private var player : AVAudioPlayer!
    private var filename : String!
    
    init(filename : String)
    {
        
        super.init()
        self.filename = filename
        let url = NSBundle.mainBundle().URLForResource(filename, withExtension: "mp3")
        var error:NSError? = nil
        self.player = AVAudioPlayer(contentsOfURL: url, error: &error)
        self.player.delegate = self
        if self.player == nil {
            println("Error loading \(url): \(error?.localizedDescription)")
        } else {
            self.player.prepareToPlay()
        }
    }
    
    func play(synchronous : Bool = false)
    {
        player.play()
        
        if (synchronous)
        {
            waitTillFinished()
        }
    }
    
    func waitTillFinished()
    {
        while (player.playing)
        {
            // process UI while this is looping
            // we only want to block application flow
            Misc.doEvents()
        }
    }
    
    func playing() -> Bool
    {
        return player.playing
    }
    
    class func vibrate()
    {
        var vibrateSound:SystemSoundID = 1352
        AudioServicesPlaySystemSound(vibrateSound)
    }
}