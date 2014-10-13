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
    
    class func offsetLocation(startLocation:CLLocation, offsetMeters: Double) -> CLLocation
    {
        var movementLatitude = offsetMeters / 111111.0;
        var loc = CLLocation(latitude: startLocation.coordinate.latitude + movementLatitude, longitude: startLocation.coordinate.longitude)
        var delta = loc.distanceFromLocation(startLocation)
        return loc
    }
/*
    class func offsetLocation(startLocation:CLLocation, offsetMeters: Double, bearing: Double) -> CLLocation
    {
        let EARTH_MEAN_RADIUS_METERS = 6372796.99;
        var lat2 =  asin( sin(startLocation.coordinate.latitude) * cos(offsetMeters/EARTH_MEAN_RADIUS_METERS) + cos(startLocation.coordinate.latitude) * sin(offsetMeters/EARTH_MEAN_RADIUS_METERS) * cos(bearing) );
        var lon2 = startLocation.coordinate.longitude + atan2( sin(bearing) * sin(offsetMeters/EARTH_MEAN_RADIUS_METERS) * cos(startLocation.coordinate.latitude), cos(offsetMeters/EARTH_MEAN_RADIUS_METERS) - sin(startLocation.coordinate.latitude) * sin(lat2));
        var tempLocation:CLLocation = CLLocation(latitude: lat2, longitude: lon2)
    
        return tempLocation;
    }
*/
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
    func toDouble() -> Double? {
        return NSNumberFormatter().numberFromString(self)!.doubleValue
    }
}

@objc protocol TimerDelegate
{
    optional func timerIncrement(identifier: NSString!, elaspedSeconds : Double, totalSeconds : Double)
    optional func timerFinished(identifier: NSString!)
    optional func timerStopped(identifier: NSString!)
    optional func timerStarted(identifier: NSString!)
}
class Timer : NSObject
{
    private var timer : NSTimer? = nil
    private var delegate : TimerDelegate!
    private var identifier : NSString!
    private var increment : Double!
    private var totalSeconds : Double!
    private var repeats : Bool
    private var currentSeconds : Double! = 0
    
    init(identifier : NSString!, delegate : TimerDelegate!, increment : Double!, totalSeconds : Double!, repeats : Bool)
    {
        self.identifier = identifier
        self.delegate = delegate
        self.increment = increment
        self.totalSeconds = totalSeconds
        self.repeats = repeats
    }
    
    func isRunning() -> Bool
    {
        return timer != nil
    }
    
    func start()
    {
        var id = self.identifier
        stopImpl(false)
        currentSeconds = 0
        timer = NSTimer.scheduledTimerWithTimeInterval(
            increment, target: self, selector:"mySelector", userInfo: nil, repeats: true)
        delegate.timerStarted?(identifier)
        delegate.timerIncrement?(identifier, elaspedSeconds: 0, totalSeconds: totalSeconds)
    }
    
    func stop()
    {
        stopImpl(true)
    }
    
    private func stopImpl(alertDelegate : Bool)
    {
        if (timer != nil)
        {
            timer!.invalidate()
            timer = nil
            if (alertDelegate)
            {
                delegate.timerStopped?(identifier)
            }
        }
    }
    
    func mySelector()
    {
        currentSeconds = currentSeconds + increment
        delegate.timerIncrement?(identifier, elaspedSeconds: currentSeconds, totalSeconds: totalSeconds)
        if (currentSeconds >= totalSeconds)
        {
            currentSeconds = 0
            delegate.timerFinished?(identifier)
            if (!self.repeats)
            {
                stopImpl(false)
            }
        }
    }
}
    