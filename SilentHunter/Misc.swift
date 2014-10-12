//
//  Misc.swift
//  AnyDeck
//
//  Created by Adam Rothberg on 8/3/14.
//  Copyright (c) 2014 Adam Rothberg. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation

class Misc
{
    class func doEvents()
    {
        let now = NSDate()
        let until = now.dateByAddingTimeInterval(0.100)
        let loop = NSRunLoop.currentRunLoop()
        loop.runUntilDate(until)
    }
    
    class var inSimulator : Bool {
        get {
            let device = UIDevice.currentDevice().model
            return NSString(string:device).containsString("Simulator")
        }
    }
    
    class func offsetLocation(startLocation:CLLocation, offsetMeters: Double, bearing: Double) -> CLLocation
    {
        let EARTH_MEAN_RADIUS_METERS = 6372796.99;
        var lat2 =  asin( sin(startLocation.coordinate.latitude) * cos(offsetMeters/EARTH_MEAN_RADIUS_METERS) + cos(startLocation.coordinate.latitude) * sin(offsetMeters/EARTH_MEAN_RADIUS_METERS) * cos(bearing) );
        var lon2 = startLocation.coordinate.longitude + atan2( sin(bearing) * sin(offsetMeters/EARTH_MEAN_RADIUS_METERS) * cos(startLocation.coordinate.latitude), cos(offsetMeters/EARTH_MEAN_RADIUS_METERS) - sin(startLocation.coordinate.latitude) * sin(lat2));
        var tempLocation:CLLocation = CLLocation(latitude: lat2, longitude: lon2)
    
        return tempLocation;
    }
}

extension Array {
    var last: T {
        return self[self.endIndex - 1]
    }
}

extension String {
    var isEmpty : Bool {
        return self.utf16Count == 0
    }
}

