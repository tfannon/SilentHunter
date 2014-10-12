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
    var locationOverride: Bool = false
    var longitude : Double = 0.0
    var latitude : Double = 0.0
    var maxLogMsgs: Int = 100
    
    init() {
        let userDefaults = NSUserDefaults.standardUserDefaults();
        if let result = userDefaults.objectForKey("Prefs") as? Dictionary<String,String> {
            serverOverride = result["serverOverride"] == "true"
            sessionName = result["sessionName"]!
            locationOverride = result["locationOverride"] == "true"
            if let tmp = result["latitude"] {
                latitude = result["latitude"]!.toDouble()!
            }
            if let tmp = result["longitude"] {
                longitude = result["longitude"]!.toDouble()!
            }
        }
    }
    
    func persist() {
        let userDefaults = NSUserDefaults.standardUserDefaults();
        userPrefs["serverOverride"] = serverOverride ? "true" : "false"
        userPrefs["sessionName"] = sessionName
        userPrefs["locationOverride"] = serverOverride ? "true" : "false"
        userPrefs["latitude"] = "\(latitude)"
        userPrefs["longitude"] = "\(longitude)"
        userDefaults.setObject(userPrefs as Dictionary<NSObject,AnyObject>, forKey: "Prefs")
    }
}
