//
//  SessionManager.swift
//  SilentHunter
//
//  Created by Tommy Fannon on 10/11/14.
//  Copyright (c) 2014 Crazy8Dev. All rights reserved.
//

import Foundation
import MultipeerConnectivity


protocol SessionManagerDelegate {
    func sessionDidChangeState()
}

protocol NetworkDelegate
{
    func sendMessage(msgType: Int, msgData: [String], toPeer:MCPeerID?)
}

class SessionMananger : NSObject, MCSessionDelegate, MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate, NetworkDelegate
{
    var peerID : MCPeerID!
    var session : MCSession!
    var serviceAdvertiser : MCNearbyServiceAdvertiser!
    var serviceBrowser : MCNearbyServiceBrowser!
    var connectedPeers : Int = 0
    var delegate : SessionManagerDelegate?
    var msgProcessor: IProcessMessages?
    var chat: IChat?
    let serviceType = "SilentHunter"
    
    override init() {
        super.init()
        peerID = MCPeerID(displayName: UIDevice.currentDevice().name)
        startServices()
    }
    
    func startServices() {
        setupSession()
        serviceAdvertiser.startAdvertisingPeer()
        serviceBrowser.startBrowsingForPeers()
    }
    
    func setupSession() {
        session = MCSession(peer: peerID)
        serviceAdvertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType:serviceType)
        serviceAdvertiser.delegate = self
        serviceBrowser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
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
    
    func session(session: MCSession!, peer peerID: MCPeerID!,
        didChangeState state: MCSessionState)  {
            var message : String = ""
            switch state {
            case MCSessionState.Connected : message = "Connected"
            case MCSessionState.NotConnected : message = "Not Connected"
            default:""
            }
            println("\(peerID) changed state to \(message)")
            // Called when a connected peer changes state (for example, goes offline)
    }
    
    
    //MARK: MCNearbyServiceBrowserDelegate
    func browser(browser: MCNearbyServiceBrowser!, didNotStartBrowsingForPeers error: NSError!) {
        
    }
    
    func browser(browser: MCNearbyServiceBrowser!, foundPeer peerID: MCPeerID!, withDiscoveryInfo info: [NSObject : AnyObject]!) {
        var shouldInvite = false
        var remotePeerName = peerID.displayName
        var myName = self.peerID.displayName
        println("Found \(remotePeerName)")
        shouldInvite = remotePeerName != myName
        if shouldInvite {
            browser.invitePeer(peerID, toSession: self.session, withContext: nil, timeout: 30.0)
            println("Inviting \(remotePeerName)")
            //tell anyone who cares that we changed state
            self.delegate?.sessionDidChangeState()
        }
        else {
        }
    }
    
    func browser(browser: MCNearbyServiceBrowser!, lostPeer peerID: MCPeerID!) {
        
    }
    
    //MARK: MCNearbyServiceAdvertiserDelegate
    func advertiser(advertiser: MCNearbyServiceAdvertiser!, didNotStartAdvertisingPeer error: NSError!) {
        
    }
    
    func advertiser(advertiser: MCNearbyServiceAdvertiser!, didReceiveInvitationFromPeer peerID: MCPeerID!, withContext context: NSData!, invitationHandler: ((Bool, MCSession!) -> Void)!) {
    }
    
    
    //MARK:  networking
    func sendMessage(msgType: Int, msgData: [String], toPeer:MCPeerID?=nil)
    {
        if (connectedPeers > 0)
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
    
    
    /*
    * Sends a message to ALL the connected peers.
    * msgType - Type of Message to send (Game.Messages)
    * data - '|' delimited string of additional data for the message type
    */
    func sendToPeers(msgType:Int, data: String) {
        var error : NSError?
        
        var msg = String(msgType) + "|" + data;
        let rawMsg = msg.dataUsingEncoding(NSUTF8StringEncoding,
            allowLossyConversion: false)
        
        if (self.session.connectedPeers.count > 0) {
            
            self.session.sendData(rawMsg, toPeers: self.session.connectedPeers,
                withMode: MCSessionSendDataMode.Unreliable, error: &error)
            
            if error != nil {
                print("Error sending data: \(error?.localizedDescription)")
            }
            
        }
        
    }
    
    
    /*
    * Sends a message to the identified peer.
    * msgType - Type of Message to send (Game.Messages)
    * data - '|' delimited string of additional data for the message type
    */
    func sendToPeer(peer: MCPeerID, msgType:Int, data: String) {
        var error : NSError?
        
        var msg = String(msgType) + "|" + data;
        let rawMsg = msg.dataUsingEncoding(NSUTF8StringEncoding,
            allowLossyConversion: false)
        
        // create an array of just this peer to send the message to
        var peers = [ peer ];
        self.session.sendData(rawMsg, toPeers: peers,
            withMode: MCSessionSendDataMode.Unreliable, error: &error)
        
        if error != nil {
            print("Error sending data: \(error?.localizedDescription)")
        }
        
        /*
        
        // special case for chat (to display in window)
        if (msgType == Game.Messages.MsgTypeChat) {
            self.updateChat(self.txtChatMsg.text, fromPeer: self.peerID)
            self.txtChatMsg.text = ""
        }
        */
    }
}
