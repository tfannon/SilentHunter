//
//  ViewController.swift
//  SilentHunter
//
//  Created by Tommy Fannon on 10/11/14.
//  Copyright (c) 2014 Crazy8Dev. All rights reserved.
//

import UIKit
import CoreLocation
import MultipeerConnectivity


protocol NetworkDelegate
{
    func sendMessage(msgType: Int, msgData: [String], toPeer:MCPeerID?)
}

class ViewController: UIViewController, CLLocationManagerDelegate
    ,MCBrowserViewControllerDelegate, MCSessionDelegate, NetworkDelegate,UITextFieldDelegate, GameDelegate
{
    var game: Game!
    
    let serviceType = "LCOC-Chat"
    
    var locationManager : CLLocationManager!
    var lblOutput : UILabel!
    var lastLocation : CLLocation?
    var audioPing : AudioPlayer = AudioPlayer(filename: "ping")
    var audioHit : AudioPlayer = AudioPlayer(filename: "hit")
    var browser : MCBrowserViewController!
    var assistant : MCAdvertiserAssistant!
    var session : MCSession!
    var peerID: MCPeerID!
    var targetPeers = [MCPeerID : Bool]()
    var targetPeer : MCPeerID?
    
    var sessionManager = SessionMananger()
    
   
    //MARK:  controller
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.txtChatMsg.delegate = self;
        
        // Do any additional setup after loading the view, typically from a nib.
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 0.0;//33
        locationManager.requestAlwaysAuthorization()
        locationManager.startUpdatingLocation()
        
        //initNetworking()
        
        game = Game(id: sessionManager.peerID)
        game.network = self
        self.game!.delegate = self;
        
        self.btnFire.hidden = true;
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //MARK:  location
    
    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        if (manager.location != nil)
        {
            var location = locations[locations.endIndex - 1] as CLLocation
            if (lastLocation == nil || lastLocation != location)
            {
                var coordinate = location.coordinate
                //audioPing.play()
                var lat = coordinate.latitude
                var long = coordinate.longitude
                var distanceInMeters = 0.0;
                if (lastLocation != nil)
                {
                    distanceInMeters = location.distanceFromLocation(lastLocation!)
                }
                var message = "Latitude: \(lat)\nLongitude: \(long)\nDifference: \(distanceInMeters)"
                txtLocation.text = message
                self.game!.playerUpdate(sessionManager.peerID, location: location)
                lastLocation = location
            }
        }
    }
    
    func locationManager(manager: CLLocationManager!, didFailWithError error: NSError!) {
        let message = "Error while updating location: " + error.localizedDescription
        txtLocation.text = message
    }
    
    func textFieldShouldReturn(textField: UITextField!) -> Bool {   //delegate method
        sendToPeers(Game.Messages.MsgTypeChat,data: self.txtChatMsg.text)
        txtChatMsg.text = "";
        return false;
    }
    
    
    //MARK:  networking
    func sendMessage(msgType: Int, msgData: [String], toPeer:MCPeerID?)
    {
        if (self.sessionManager.connectedPeers > 0)
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
    
    func initNetworking()
    {
        self.peerID = MCPeerID(displayName: UIDevice.currentDevice().name)
        self.session = MCSession(peer: peerID)
        self.session.delegate = self
        
        // create the browser viewcontroller with a unique service name
        self.browser = MCBrowserViewController(serviceType:serviceType, session:self.session)
        self.browser.delegate = self;
        self.assistant = MCAdvertiserAssistant(serviceType:serviceType, discoveryInfo:nil, session:self.session)
        
        // tell the assistant to start advertising our fabulous chat
        self.assistant.start()
    }
    
    //MARK: browser 
    
    func browserViewControllerDidFinish(
        browserViewController: MCBrowserViewController!)  {
            // Called when the browser view controller is dismissed (ie the Done
            // button was tapped)
            
            self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func browserViewControllerWasCancelled(
        browserViewController: MCBrowserViewController!)  {
            // Called when the browser view controller is cancelled
            
            self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func session(session: MCSession!, didReceiveData data: NSData!,
        fromPeer peerID: MCPeerID!)  {
            // Called when a peer sends an NSData to us
            
            // This needs to run on the main queue
            dispatch_async(dispatch_get_main_queue()) {
                
                var msg = NSString(data: data, encoding: NSUTF8StringEncoding)
                var msgParts:[String] = msg.componentsSeparatedByString("|") as [String];
                
                var msgType = msgParts[0]
                if (msgType.toInt() == Game.Messages.MsgTypeChat) {
                    self.updateChat(msgParts[1], fromPeer: peerID)
                }
                else
                {
                    msgParts.removeAtIndex(0)
                    self.game.ProcessMessage(peerID, msgType: msgType.toInt(), data: msgParts)
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
            // Called when a connected peer changes state (for example, goes offline)
            switch (state) {
            case MCSessionState.Connected:
                dispatch_async(dispatch_get_main_queue()) {
                    self.logit(peerID.displayName + " connected\n")
                }
                break
            case MCSessionState.Connecting:
                dispatch_async(dispatch_get_main_queue()) {
                    self.logit(peerID.displayName + " connecting\n")
                }
                break
            default:
                break
            }
            
            
    }
    
    /*
    * Logs a message in raw form to the output text view
    */
    func logit(message: String) {
        self.txtMessages.text = self.txtMessages.text + message
        
    }
    
    func updateChat(text : String, fromPeer peerID: MCPeerID) {
        // Appends some text to the chat view
        
        // If this peer ID is the local device's peer ID, then show the name
        // as "Me"
        var name : String
        
        switch peerID {
        case self.peerID:
            name = "Me"
        default:
            name = peerID.displayName
        }
        
        // Add the name to the message and display it
        let message = "\(name): \(text)\n"
        self.txtMessages.text = self.txtMessages.text + message
        
    }
    
    /*
    * Sends a message to ALL the connected peers.
    * msgType - Type of Message to send (Game.Messages)
    * data - '|' delimited string of additional data for the message type
    */
    private func sendToPeers(msgType:Int, data: String) {
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
        
            // special case for chat (to display in window)
            if (msgType == Game.Messages.MsgTypeChat) {
                self.updateChat(self.txtChatMsg.text, fromPeer: self.peerID)
                self.txtChatMsg.text = ""
            }
        }
        
    }
    
    
    /*
    * Sends a message to the identified peer.
    * msgType - Type of Message to send (Game.Messages)
    * data - '|' delimited string of additional data for the message type
    */
    private func sendToPeer(peer: MCPeerID, msgType:Int, data: String) {
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
        
        // special case for chat (to display in window)
        if (msgType == Game.Messages.MsgTypeChat) {
            self.updateChat(self.txtChatMsg.text, fromPeer: self.peerID)
            self.txtChatMsg.text = ""
        }
        
    }


    @IBOutlet var btnFire: UIButton!
    @IBOutlet weak var txtLocation: UILabel!
    @IBOutlet weak var txtMessages: UITextView!
    @IBOutlet weak var txtChatMsg: UITextField!

    @IBAction func btnBrowse(sender: UIButton) {
        self.presentViewController(self.browser, animated: true, completion: nil)
    }
    @IBAction func btnSend(sender: UIButton) {
        sendToPeers(Game.Messages.MsgTypeChat,data: self.txtChatMsg.text)
    }
    @IBAction func btnFire_Clicked(sender: AnyObject) {
        self.btnFire.hidden = true
        var target = self.targetPeer
        if (target != nil)
        {
            self.targetPeer = nil
            self.targetPeers[target!] = false
            self.game.fire(target)
        }
    }
    
    func inRange(playerID : MCPeerID!)
    {
        targetPeers[playerID] = true
        targetPeer = playerID;
        self.btnFire.hidden = false
    }
    
    func outOfRange(playerID : MCPeerID!)
    {
        targetPeers[playerID] = false;
        if (targetPeer == playerID)
        {
            findNextTarget()
        }
    }
    
    func hit(playerID: MCPeerID!)
    {
        audioHit.play()
    }
    
    func firedUpon(playerID: MCPeerID!) {
    }
    
    func notify(message: NSString!) {
        var alert = UIAlertController(title: "Alert", message: message, preferredStyle : UIAlertControllerStyle.Alert)
        self.presentViewController(alert, animated: false, completion: nil)
    }
    
    func findNextTarget()
    {
        self.targetPeer = nil
        self.btnFire.hidden = true
        for (id, playerInRange) in targetPeers
        {
            if (playerInRange)
            {
                inRange(id)
                break
            }
        }
    }
}

