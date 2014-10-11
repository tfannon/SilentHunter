//
//  Misc.swift
//  AnyDeck
//
//  Created by Adam Rothberg on 8/3/14.
//  Copyright (c) 2014 Adam Rothberg. All rights reserved.
//

import Foundation
import UIKit


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
    
    
}

extension Array {
    var last: T {
        return self[self.endIndex - 1]
    }
}
