//
//  Settings.swift
//  SilentHunter
//
//  Created by Tommy Fannon on 10/11/14.
//  Copyright (c) 2014 Crazy8Dev. All rights reserved.
//

import Foundation

let gSettings = Settings()

class Settings {
    private var userPrefs = Dictionary<String,String>()

    var serverOverride : Bool = false
    var sessionName : String = ""
    var longitude : Double = 0.0
    var latitude : Double = 0.0
    
    init() {
        let userDefaults = NSUserDefaults.standardUserDefaults();
        if let result = userDefaults.objectForKey("Prefs") as? Dictionary<String,String> {
            serverOverride = result["serverOverride"] == "true"
            sessionName = result["sessionName"]!
        }

    }
    
    func persist() {
        let userDefaults = NSUserDefaults.standardUserDefaults();
        userPrefs["sessionName"] = sessionName
        userPrefs["serverOverride"] = serverOverride ? "true" : "false"
        userDefaults.setObject(userPrefs as Dictionary<NSObject,AnyObject>, forKey: "Prefs")
    }
}
