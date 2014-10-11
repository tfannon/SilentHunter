//
//  SessionManager.swift
//  SilentHunter
//
//  Created by Tommy Fannon on 10/11/14.
//  Copyright (c) 2014 Crazy8Dev. All rights reserved.
//

import Foundation
import MultipeerConnectivity



class SessionMananger : NSObject, MCSessionDelegate, MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate {
    
    var peerID : MCPeerID!
    var session : MCSession!
    var serviceAdvertiser : MCNearbyServiceAdvertiser!
    var serviceBrowser : MCNearbyServiceBrowser!
    var connectedPeers : Int = 0
    
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
                //self.updateChat(msg, fromPeer: peerID)
                println(msg)
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
    
    
    //MARK: MCNearbyServiceBrowserDelegage
    func browser(browser: MCNearbyServiceBrowser!, didNotStartBrowsingForPeers error: NSError!) {
        
    }
    
    func browser(browser: MCNearbyServiceBrowser!, foundPeer peerID: MCPeerID!, withDiscoveryInfo info: [NSObject : AnyObject]!) {
        var shouldInvite = false
        var remotePeerName = peerID.displayName
        var myName = self.peerID.displayName
        println("Found \(remotePeerName)")
        shouldInvite = remotePeerName == myName
        if shouldInvite {
            browser.invitePeer(peerID, toSession: self.session, withContext: nil, timeout: 30.0)
            println("Inviting \(remotePeerName)")
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
}
