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
    func sendToPeers(msgType:Int, data: String)
    func sendToPeer(peer: MCPeerID, msgType:Int, data: String)
}

class ViewController: UIViewController, CLLocationManagerDelegate
    ,MCBrowserViewControllerDelegate, MCSessionDelegate, UITextFieldDelegate, GameDelegate
{
    var game: Game!
    
    let serviceType = "LCOC-Chat"
    
    var locationManager : CLLocationManager!
    var lblOutput : UILabel!
    var lastLocation : CLLocation?
    var audioPing : AudioPlayer = AudioPlayer(filename: "ping")
    var browser : MCBrowserViewController!
    var assistant : MCAdvertiserAssistant!
    var session : MCSession!
    var network : NetworkDelegate!
    var peerID: MCPeerID!
    var targetPeers = [MCPeerID : Bool]()
    var targetPeer : MCPeerID?
    
    var sessionManager = SessionMananger()
    var prefs = Dictionary<String, String>()
    
    //MARK: Outlets
    @IBOutlet var txtSimulatorId: UITextField!
    @IBOutlet var btnFire: UIButton!
    @IBOutlet weak var txtLocation: UILabel!
    @IBOutlet weak var txtMessages: UITextView!
    @IBOutlet weak var txtChatMsg: UITextField!
    
    //MARK: Actions
    @IBAction func handleSimulatorIdChanged(sender: AnyObject) {
        prefs["SimulatorId"] = txtSimulatorId.text
        let userDefaults = NSUserDefaults.standardUserDefaults()
        userDefaults.setObject(prefs as Dictionary<NSObject,AnyObject>, forKey: "prefs")
    }
    
    @IBAction func btnSend(sender: UIButton) {
         network.sendToPeers(Game.Messages.MsgTypeChat,data: self.txtChatMsg.text)
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
   
    //MARK:  controller
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.txtChatMsg.delegate = self;
        self.txtSimulatorId.delegate = self;
        
        // Do any additional setup after loading the view, typically from a nib.
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 0.0;//33
        locationManager.requestAlwaysAuthorization()
        locationManager.startUpdatingLocation()
        
        game = Game(id: sessionManager.peerID)
        network = sessionManager
        game.network = network
        
        self.game!.delegate = self;
        
        self.btnFire.hidden = true;
        
        // HACK for other player
        var playerID : MCPeerID! = MCPeerID(displayName: "Breakthrough")
        var location : CLLocation! = CLLocation(latitude: 37.33150351, longitude: -122.03071596)
        self.game!.playerUpdate(playerID, location: location)
        
        restoreUserPrefs()
    }
    
    func restoreUserPrefs() {
        let userDefaults = NSUserDefaults.standardUserDefaults();
        if let prefs = userDefaults.objectForKey("prefs") as? Dictionary<String,String> {
            txtSimulatorId.text = prefs["SimulatorId"]
        }
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
        network.sendToPeers(Game.Messages.MsgTypeChat,data: self.txtChatMsg.text)
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
                network.sendToPeers(msgType, data: joinedStrings)
            }
            else {
                network.sendToPeer(toPeer!, msgType: msgType, data: joinedStrings)
            }
        }
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
    
    
    func inRange(playerID : MCPeerID!)
    {
        targetPeers[playerID] = true
        targetPeer = playerID;
        self.btnFire.hidden = false
    }
    
    func outofRange(playerID : MCPeerID!)
    {
        targetPeers[playerID] = false
        if (targetPeer == playerID)
        {
            findNextTarget()
        }
    }
    
    func notify(message: NSString!) {
        var alert = UIAlertController(title: "Alert", message: message, preferredStyle : UIAlertControllerStyle.Alert)
        self.presentViewController(alert, animated: false, completion: nil)
    }
    
    func findNextTarget()
    {
        self.targetPeer = nil
        self.btnFire.hidden = false
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

