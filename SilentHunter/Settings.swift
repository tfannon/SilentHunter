//
//  Settings.swift
//  SilentHunter
//
//  Created by Tommy Fannon on 10/11/14.
//  Copyright (c) 2014 Crazy8Dev. All rights reserved.
//

import Foundation
import CoreLocation

let gSettings = Settings()

enum SettingType {
    case Location
    case Session
    case LocationOffset
    //mainViewController!.setLocation(gSettings.getFakeLocation())
}

protocol SettingsListener {
    func settingDidChange(settingType : SettingType)
}

class Settings {
    private var userPrefs = Dictionary<String,String>()
    private var listeners = [SettingsListener]()

    //when some of these settings change, we need to notify anyone who cares
    //notify from here, NOT the individual view controllers
    var sessionOverride : Bool = false {
        didSet {
            for y in listeners {
                y.settingDidChange(.Session)
            }
        }
    }
    
    var locationOffset : Double = 0.0 {
        didSet {
            for y in listeners {
                y.settingDidChange(.LocationOffset)
            }
        }
    }

    var sessionName : String = ""
    var locationOverride: Bool = false
    var longitude : Double = 0.0
    var latitude : Double = 0.0
    var maxLogMsgs: Int = 100
    
    
    
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
                    if let tmp = result["locationOffset"] {
                        locationOffset = result["locationOffset"]!.toDouble()!
                    }
                }
            }
            
            var strMaxLogMsgs  = result["maxLogMsgs"]
            if (strMaxLogMsgs != nil) {
                maxLogMsgs = strMaxLogMsgs!.toInt()!
            }
        }
    }
    
    func getFakeLocation () -> CLLocation
    {
        var loc = CLLocation(latitude: self.latitude, longitude: self.longitude)
        var loc2 = Misc.offsetLocation(loc, offsetMeters: self.locationOffset, bearing: 270.0)
        return loc2
    }
    
    func registerListener(listener : SettingsListener) {
        listeners.append(listener)
    }
    
    func persist() {
        let userDefaults = NSUserDefaults.standardUserDefaults();
        userPrefs["sessionOverride"] = sessionOverride ? "true" : "false"
        userPrefs["sessionName"] = sessionName
        userPrefs["locationOverride"] = locationOverride ? "true" : "false"
        userPrefs["latitude"] = "\(latitude)"
        userPrefs["longitude"] = "\(longitude)"
        userPrefs["locationOffset"] = "\(locationOffset)"

        var strMaxLogMsgs = String(maxLogMsgs)
        userPrefs["maxLogMsgs"] = strMaxLogMsgs
        userDefaults.setObject(userPrefs as Dictionary<NSObject,AnyObject>, forKey: "Prefs")
    }
}
