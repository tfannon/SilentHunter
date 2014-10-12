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


protocol IProcessMessages
{
    func ProcessMessage(fromPeer: MCPeerID!, msgType: Int!, data:[String])
    func HandleDisconnect(peer: MCPeerID)
}

protocol GameDelegate
{
    func logit(msg: String)
    func inRange(playerID : MCPeerID!, distance:Double)
    func outOfRange(playerID : MCPeerID!, distance:Double)
    func notify(message : NSString!)
    func firedUpon(playerID : MCPeerID!)
    func hit(playerID: MCPeerID!)
    func handlePlayerDisconnect(playerID: MCPeerID)
}

class Game : NSObject, IProcessMessages {
    
    struct Messages {
        static let MsgTypePlayerLocation = 1
        static let MsgTypeChat = 2
        static let MsgFiredTorpedo = 3
        static let MsgPlayerEvadedTorpedo = 4
        static let MsgPlayerHit = 5
    }
    
    private var players = [MCPeerID: PlayerInfo]()
    private var meId : MCPeerID!
    var delegate: GameDelegate!
    let MAX_DISTANCE = 10.0;
    var network: Networking?
    var hackOtherPlayerCount : Int = 0
    var hackOtherPlayerID : MCPeerID! = MCPeerID(displayName: "Breakthrough")
    var timeLastPlayerUpdateSent : NSDate?
    var checkingForTargets = false
    var timerCheckForTargets : NSTimer!
    
    init(network : Networking)
    {
        super.init()
        self.network = network
        self.meId = network.peerID
        timerCheckForTargets = NSTimer.scheduledTimerWithTimeInterval(
            1.0, target: self, selector:"checkForTargetsTimer", userInfo: nil, repeats: true)
    }

    
    // Receiving messages to be processed
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
            //self.delegate.logit("RECV: PlayerLoc: \(fromPeer.displayName) :: \(lat!),\(lng!)")
            
            var loc = CLLocation(latitude: lat!, longitude: lng!)
            self.playerLocationUpdate(fromPeer, location: loc)
            
            break;
        case Messages.MsgFiredTorpedo:
            self.delegate.logit("RECV: Torpedo Fired at me by: \(fromPeer.displayName)")
            firedUpon(fromPeer)
            break;
        case Messages.MsgPlayerHit: // response from player that torpedo was fired at
            self.delegate.logit("RECV: I HIT player: \(fromPeer.displayName)")
            hitSuccess(fromPeer)
            break;
        case Messages.MsgPlayerEvadedTorpedo:
            self.delegate.logit("RECV: Player \(fromPeer.displayName) EVADED by torpedo")
            evade()
            break;
        default:
            break;
            
        }
    }
    
    //Sends a message through the peer network
    private func sendMessage(msgType: Int, msgData: [String], toPeer:MCPeerID?){
        network?.sendMessage(msgType, msgData: msgData, toPeer: toPeer)
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
    // indicates "I" have been hit
    private func sendPlayerHitMessage(peer: MCPeerID) {
        sendMessage(Messages.MsgPlayerHit, msgData: [], toPeer: peer)
    }
    // idnicates "I" have evaded the torpedo fired at me
    private func sendPlayerEvadedTorpedoMessage(peer: MCPeerID) {
        sendMessage(Messages.MsgPlayerEvadedTorpedo, msgData: [], toPeer: peer)
    }
    
    internal func getPlayerCount() -> Int {
        return players.count
    }
    internal func getPlayer(index: Int) -> PlayerInfo {
        var key : MCPeerID = Array(players.keys)[index]
        var playerInfo = players[key]
        return playerInfo!
    }
    
    func HandleDisconnect(peer: MCPeerID) {
        /// remove from game data
        players.removeValueForKey(peer)
        // remove from UI collections
        delegate.handlePlayerDisconnect(peer)
    }
    
    func checkForTargetsTimer()
    {
        checkForTargets()
    }
    
    func checkForTargets()
    {
        if (!checkingForTargets)
        {
            checkingForTargets = true
            var meInfo = players[meId]
            var displayName = meId.displayName
            for (id, info) in players {
                if (id != meId) {
                    var distanceInMeters = info.location.distanceFromLocation(meInfo!.location)
                    if (distanceInMeters > 0 && distanceInMeters < MAX_DISTANCE)
                    {
                        delegate.inRange(id, distance: distanceInMeters)
                    }
                    else
                    {
                        delegate.outOfRange(id, distance: distanceInMeters)
                    }
                }
            }
            checkingForTargets = false
        }
    }
    
    func playerLocationUpdate(playerID : MCPeerID!, location: CLLocation!) {

        var prevPlayerInfo = players[playerID]
        var info = PlayerInfo(playerID: playerID, location: location)
        players[playerID] = info

        var meInfo = players[meId]
       
        var positionSame = false
        if (prevPlayerInfo != nil)
        {
            var prevLat = prevPlayerInfo!.location.coordinate.latitude
            var prevLng = prevPlayerInfo!.location.coordinate.longitude
            var currLat = location.coordinate.latitude
            var currLng = location.coordinate.longitude
            positionSame = (prevLat == currLat && prevLng == currLng)
        }
        if (self.meId == playerID && !positionSame) {
            self.sendMyLocationMessage(meInfo!.location)
        }

        checkForTargets()
    }
    
    
    func fire(playerID: MCPeerID!) {
        sendMyFireTorpedoMessage(playerID)
    }
    
    func hitSuccess(playerID: MCPeerID!) {
    }
    
    func hit(playerID: MCPeerID!) {
        delegate.hit(playerID);
        sendPlayerHitMessage(playerID)
    }
    
    func firedUpon(playerID: MCPeerID!) {
        delegate.firedUpon(playerID)
        var random = Int(arc4random_uniform(UInt32(4)));
        var amHit = random == 0 || true
        if (amHit) {
            hit(playerID)
        }
    }
    
    func evade() {
    }
    
    func move() {
    }
    
    func playerDestroyed(playerID : MCPeerID!) {
        var info = players[playerID];
        if (info != nil) {
            info!.isAlive = false;
        }
    }
}

internal class PlayerInfo {
    internal var playerID : MCPeerID!;
    private var location : CLLocation!
    private var isAlive : Bool! = true
    private var hits : Int16! = 0
    init(playerID: MCPeerID, location: CLLocation) {
        self.playerID = playerID
        self.location = location
    }
}