//
//  SessionManager.swift
//  SilentHunter
//
//  Created by Tommy Fannon on 10/11/14.
//  Copyright (c) 2014 Crazy8Dev. All rights reserved.
//

import Foundation
import MultipeerConnectivity



class Networking : NSObject, MCSessionDelegate, MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate
{
    var peerID : MCPeerID!
    var session : MCSession!
    var serviceAdvertiser : MCNearbyServiceAdvertiser!
    var serviceBrowser : MCNearbyServiceBrowser!

    
    var msgProcessor: IProcessMessages!
    var chat: IChat!
    
    init(name : String) {
        super.init()
        peerID = MCPeerID(displayName: name)
    }
    
    func startServices() {
        setupSession()
        serviceAdvertiser.startAdvertisingPeer()
        serviceBrowser.startBrowsingForPeers()
    }
    
    func stopServices() {
        serviceBrowser.stopBrowsingForPeers()
        serviceAdvertiser.stopAdvertisingPeer()
        session.disconnect()
    }
    
    func restartServices() {
        chat.logit("Restarting session")
        stopServices()
        startServices()
    }
    
    
    func setupSession() {
        var sessionName = gSettings.sessionOverride ? gSettings.sessionName : "SilentHunter"
        var deviceId = UIDevice.currentDevice().identifierForVendor.UUIDString
        chat.logit("Setting up session: \(sessionName) for \(deviceId)")
        session = MCSession(peer: peerID)
        session.delegate = self
        serviceAdvertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType:sessionName)
        serviceAdvertiser.delegate = self
        serviceBrowser = MCNearbyServiceBrowser(peer: peerID, serviceType: sessionName)
        serviceBrowser.delegate = self
    }
    

    //MARK: MCSessionDelegate
    // Called when a peer sends an NSData to us
    func session(session: MCSession!, didReceiveData data: NSData!,
        fromPeer peerID: MCPeerID!)  {
            // This needs to run on the main queue
            dispatch_async(dispatch_get_main_queue()) {
                
                var msg = NSString(data: data, encoding: NSUTF8StringEncoding)
                var msgParts:[String] = msg.componentsSeparatedByString("|") as [String];
                
                var msgType = msgParts[0]
                if (msgType.toInt() == Game.Messages.MsgTypeChat) {
                    self.chat?.updateChat(msgParts[1], fromPeer: peerID)
                }
                else
                {
                    msgParts.removeAtIndex(0)
                    self.msgProcessor?.ProcessMessage(peerID, msgType: msgType.toInt(), data: msgParts)
                }
                
            }
            
    }
    
    // The following methods do nothing, but the MCSessionDelegate protocol
    // requires that we implement them.
    func session(session: MCSession!,
        didStartReceivingResourceWithName resourceName: String!,
        fromPeer peerID: MCPeerID!, withProgress progress: NSProgress!)  {
            
            // Called when a peer starts sending a file to us
    }
    
    func session(session: MCSession!,
        didFinishReceivingResourceWithName resourceName: String!,
        fromPeer peerID: MCPeerID!,
        atURL localURL: NSURL!, withError error: NSError!)  {
            // Called when a file has finished transferring from another peer
    }
    
    func session(session: MCSession!, didReceiveStream stream: NSInputStream!,
        withName streamName: String!, fromPeer peerID: MCPeerID!)  {
            // Called when a peer establishes a stream with us
    }

    // Called when a connected peer changes state (for example, goes offline)
    func session(session: MCSession!, peer peerID: MCPeerID!,
        didChangeState state: MCSessionState)  {
            var message : String = ""
            switch state {
            case MCSessionState.Connecting : message = "Connecting"
            case MCSessionState.Connected : message = "Connected"
            case MCSessionState.NotConnected:
                message = "Not Connected"
                var who = peerID.displayName
                msgProcessor?.HandleDisconnect(peerID)
            default:""
            }
            //Async.main {
            dispatch_async(dispatch_get_main_queue()) {
                println("\(peerID.displayName) changed state to \(message)")
                self.chat?.logit("\(peerID.displayName) changed state to \(message)")
            }
    }
    
    func session(session: MCSession!, didReceiveCertificate certificate: [AnyObject]!, fromPeer peerID: MCPeerID!, certificateHandler: ((Bool) -> Void)!) {
        certificateHandler(true)
    }
    
    
    //MARK: MCNearbyServiceBrowserDelegate
    func browser(browser: MCNearbyServiceBrowser!, didNotStartBrowsingForPeers error: NSError!) {
        self.chat?.logit("browser.didNotStartBrowsing")
    }
    
    func browser(browser: MCNearbyServiceBrowser!, foundPeer peerID: MCPeerID!, withDiscoveryInfo info: [NSObject : AnyObject]!) {
        var shouldInvite = false
        var remotePeerName = peerID.displayName
        var myName = self.peerID.displayName
        var message = ("Found \(remotePeerName)")
        self.chat.logit(message)
        shouldInvite = remotePeerName != myName
        if shouldInvite {
            browser.invitePeer(peerID, toSession: self.session, withContext: nil, timeout: 30.0)
            message = "Inviting \(remotePeerName)"
            self.chat?.logit(message)
        }
        else {
        }
    }
    
    func browser(browser: MCNearbyServiceBrowser!, lostPeer peerID: MCPeerID!) {
        self.chat.logit("browser.lostPeer: \(peerID.displayName)")
    }
    
    //MARK: MCNearbyServiceAdvertiserDelegate
    func advertiser(advertiser: MCNearbyServiceAdvertiser!, didNotStartAdvertisingPeer error: NSError!) {
         self.chat.logit("browser.didNotStartAdvertising")
    }
    
    func advertiser(advertiser: MCNearbyServiceAdvertiser!, didReceiveInvitationFromPeer peerID: MCPeerID!, withContext context: NSData!, invitationHandler: ((Bool, MCSession!) -> Void)!) {
        var message = "Received invitation from: \(peerID.displayName)"
        self.chat.logit(message)
        invitationHandler(true, self.session)
        message = "Accepted invitation from: \(peerID.displayName)"
        self.chat?.logit(message)
    }
    
    
    //MARK:  networking
    func sendMessage(msgType: Int, msgData: [String], toPeer:MCPeerID?=nil) {
        if (self.session.connectedPeers.count > 0)
        {
            var joiner = "|"
            var joinedStrings = joiner.join(msgData)
            if (toPeer == nil) {
                sendToPeers(msgType, data: joinedStrings)
            }
            else {
                sendToPeer(toPeer!, msgType: msgType, data: joinedStrings)
            }
        }
    }
    
    func sendToPeers(msgType:Int, data: String, peers: [MCPeerID]? = nil) {
        var error : NSError?
        
        var msg = String(msgType) + "|" + data;
        let rawMsg = msg.dataUsingEncoding(NSUTF8StringEncoding,
            allowLossyConversion: false)
        
        var sendToPeers: [MCPeerID]
        if (peers == nil || peers?.count == 0){
            sendToPeers = self.session.connectedPeers as [MCPeerID]
        }
        else {
            sendToPeers = peers!
        }
        
        var peerCount = sendToPeers.count
        if (peerCount > 0) {
            
            self.session.sendData(rawMsg, toPeers: sendToPeers,
                withMode: MCSessionSendDataMode.Unreliable, error: &error)
            
            if error != nil {
                print("Error sending data: \(error?.localizedDescription)")
            }
            
            if (msgType == Game.Messages.MsgTypeChat) {
                chat?.updateChat(data, fromPeer: self.peerID)
            }
            
        }
        
    }
    
    
    /*
    * Sends a message to the identified peer.
    * msgType - Type of Message to send (Game.Messages)
    * data - '|' delimited string of additional data for the message type
    */
    func sendToPeer(peer: MCPeerID, msgType:Int, data: String) {
        // create an array of just this peer to send the message to
        var peers = [ peer ];
        sendToPeers(msgType, data: data, peers: peers)
    }
}
