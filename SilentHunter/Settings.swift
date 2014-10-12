//
//  Settings.swift
//  SilentHunter
//
//  Created by Tommy Fannon on 10/11/14.
//  Copyright (c) 2014 Crazy8Dev. All rights reserved.
//

import Foundation

let gSettings = Settings()

enum SettingType {
    case Location
    case Session
}

protocol SettingsListener {
    func settingDidChange(settingType : SettingType)
}

class Settings {
    private var userPrefs = Dictionary<String,String>()

    var sessionOverride : Bool = false {
        didSet {
            for y in listeners {
                y.settingDidChange(.Session)
            }
        }
    }
    
    var sessionName : String = ""
    var locationOverride: Bool = false
    var longitude : Double = 0.0
    var latitude : Double = 0.0
    var maxLogMsgs: Int = 100
    var listeners = [SettingsListener]()
    
    init() {
        let userDefaults = NSUserDefaults.standardUserDefaults();
        if let result = userDefaults.objectForKey("Prefs") as? Dictionary<String,String> {
            sessionOverride = result["sessionOverride"] == "true"
            sessionName = result["sessionName"]!
            
            locationOverride = result["locationOverride"] == "true"
            if let tmp = result["latitude"] {
                latitude = result["latitude"]!.toDouble()!
                if let tmp = result["longitude"] {
                    longitude = result["longitude"]!.toDouble()!
                }
            }
            
            var strMaxLogMsgs  = result["maxLogMsgs"]
            if (strMaxLogMsgs != nil) {
                maxLogMsgs = strMaxLogMsgs!.toInt()!
            }
        }
    }
    
    func registerListener(listener : SettingsListener) {
        listeners.append(listener)
    }
    
    func persist() {
        let userDefaults = NSUserDefaults.standardUserDefaults();
        userPrefs["sessionOverride"] = sessionOverride ? "true" : "false"
        userPrefs["sessionName"] = sessionName
        userPrefs["locationOverride"] = sessionOverride ? "true" : "false"
        userPrefs["latitude"] = "\(latitude)"
        userPrefs["longitude"] = "\(longitude)"

        var strMaxLogMsgs = String(maxLogMsgs)
        userPrefs["maxLogMsgs"] = strMaxLogMsgs
        userDefaults.setObject(userPrefs as Dictionary<NSObject,AnyObject>, forKey: "Prefs")
    }
}
