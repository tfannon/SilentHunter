//
//  Misc.swift
//  AnyDeck
//
//  Created by Adam Rothberg on 8/3/14.
//  Copyright (c) 2014 Adam Rothberg. All rights reserved.
//

import Foundation

class Misc
{
    class func doEvents()
    {
        let now = NSDate()
        let until = now.dateByAddingTimeInterval(0.100)
        let loop = NSRunLoop.currentRunLoop()
        loop.runUntilDate(until)
    }
}


extension Array {
    var last: T {
        return self[self.endIndex - 1]
    }
}
