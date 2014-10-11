//
//  Game.swift
//  steve
//
//  Created by Steven Calise on 10/10/14.
//  Copyright (c) 2014 Steven Calise. All rights reserved.
//

import Foundation
import MultipeerConnectivity
import CoreLocation

extension String {
    func toDouble() -> Double? {
        return NSNumberFormatter().numberFromString(self)!.doubleValue
    }
}

@objc protocol GameDelegate
{
    optional func inRange(playerID : MCPeerID!) -> Bool
    optional func notify(message : NSString!);
}

class Game {
    
    var network: NetworkDelegate?
    
    struct Messages {
        static let MsgTypePlayerLocation = 1
        static let MsgTypeChat = 2
        static let MsgFiredTorpedo = 3
    }
    
    
    
    internal func ProcessMessage(fromPeer: MCPeerID!, msgType: Int!, data:[String])
    {
        switch (msgType)
            {
        case Messages.MsgTypeChat:
            /* Do nothing...chat messages are handled by the lower level framework */
            break;
        case Messages.MsgTypePlayerLocation:
            var lat = data[0].toDouble()
            var lng = data[1].toDouble()
            
            var loc = CLLocation(latitude: lat!, longitude: lng!)
            self.playerUpdate(fromPeer, location: loc)
            
            break;
        default:
            break;
            
        }
    }
    
    //Sends a message through the peer network
    private func sendMessage(msgType: Int, msgData: [String], toPeer:MCPeerID?){
        network?.sendMessage!(msgType, msgData: msgData, toPeer: toPeer)
    }
    private func sendMyLocationMessage(location: CLLocation)
    {
        var lat = String(format: "%f", location.coordinate.latitude)
        var lng = String(format: "%f", location.coordinate.longitude)
        
        var locData = [ lat, lng ]
        sendMessage(Game.Messages.MsgTypePlayerLocation, msgData: locData, toPeer: nil)
    }
    private func sendMyFireTorpedoMessage(peer: MCPeerID)
    {
        sendMessage(Messages.MsgFiredTorpedo, msgData: [], toPeer: peer)
    }
    
    private var players = [MCPeerID: PlayerInfo]()
    private var meId : MCPeerID!
    var delegate: GameDelegate?
    let MAX_DISTANCE = 10.0;
    
    init(id : MCPeerID)
    {
        self.meId = id;
    }
    
    func playerUpdate(id : MCPeerID!, location: CLLocation!)
    {
        var prevPlayerInfo = players[id]
        
        var info = PlayerInfo(playerID: id, location: location)
        players[id] = info
        
        var prevLat = prevPlayerInfo?.location.coordinate.latitude
        var prevLng = prevPlayerInfo?.location.coordinate.longitude
        var currLat = location.coordinate.latitude
        var currLng = location.coordinate.longitude
        var positionSame = (prevLat == currLat && prevLng == currLng)
        
        // Display other connected players GPS coordinates when they change
        if (id != meId && !positionSame) {
            println("\(id.displayName): \(location.coordinate.latitude),\(location.coordinate.longitude)")
        }
        
        var meInfo = players[meId]
        var displayName = id.displayName
        if (meInfo != nil)
        {
            for (id, info) in players
            {
                if (id != meId)
                {
                    var distanceInMeters = info.location.distanceFromLocation(meInfo!.location)
                    if (distanceInMeters > 0 && distanceInMeters < MAX_DISTANCE)
                    {
                        var result = delegate?.inRange!(id)
                        if (result == true) {
                            sendMyFireTorpedoMessage(id)
                        }
                    }
                }
                else{
                    sendMyLocationMessage(meInfo!.location)
                    
                }
            }
        }
    }
    
    func fire(playerID: MCPeerID!)
    {
        var meInfo = players[meId]
        var target = players[playerID];
        if (target != nil)
        {
            var distanceInMeters = target!.location.distanceFromLocation(meInfo!.location)
            if (distanceInMeters > 0 && distanceInMeters < MAX_DISTANCE)
            {
                delegate?.notify?("HIT")
            }
        }
    }
    
    func hit(playerID: MCPeerID!)
    {
    }
    
    func firedUpon(playerID: MCPeerID!)
    {
    }
    
    func evade()
    {
    }
    
    func move()
    {
    }
    
    func playerDestroyed(playerID : MCPeerID!)
    {
        var info = players[playerID];
        if (info != nil)
        {
            info!.isAlive = false;
        }
    }
}

class PlayerInfo {
    private var playerID : MCPeerID!;
    private var location : CLLocation!
    private var isAlive : Bool! = true
    private var hits : Int16! = 0
    init(playerID: MCPeerID, location: CLLocation)
    {
        self.playerID = playerID
        self.location = location
    }
}