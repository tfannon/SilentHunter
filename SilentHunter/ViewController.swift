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

protocol IChat {
    func updateChat(text : String, fromPeer peerID: MCPeerID)
    func logit(message:String)
}

class ViewController: UIViewController, CLLocationManagerDelegate,UITextFieldDelegate, GameDelegate, UITableViewDelegate, UITableViewDataSource, IChat, UIGestureRecognizerDelegate
{
    
    var debugViewController : DebugViewController! = DebugViewController()
    
    var game: Game! = nil
    var locationManager : CLLocationManager!
    var network : Networking!
    
    var lblOutput : UILabel!
    var lastLocation : CLLocation?
    
    var audioPing : AudioPlayer = AudioPlayer(filename: "ping")
    var audioHit : AudioPlayer = AudioPlayer(filename: "hit")
    var audioFire : AudioPlayer = AudioPlayer(filename: "fire")
    
    var targetPeers = [MCPeerID : Bool]()
    var targetPeer : MCPeerID?
    var targetsForDataBinding = [MCPeerID]()
    var ableToFire : Bool = true
    var timerAbleToFire : NSTimer?
    
    var prefs = Dictionary<String, String>()
    
    
    //MARK: Outlets
    @IBOutlet var btnFire: UIButton!
    @IBOutlet weak var txtLocation: UILabel!
    @IBOutlet weak var txtMessages: UITextView!
    @IBOutlet weak var txtChatMsg: UITextField!
    
   
    //MARK:  controller
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "cell")
        self.txtChatMsg.delegate = self;
        
        let name = UIDevice.currentDevice().name
        //order is important here so dependencies are all hooked up
        network = Networking(name: name)
        game = Game(network: network)
        network.msgProcessor = game;
        network.chat = self;
        network.startServices()
        
        self.game.delegate = self;
        self.btnFire.hidden = true;
        self.btnFire.setTitle("Loading torpedoes", forState: UIControlState.Disabled)
        
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 0.0;
        locationManager.requestAlwaysAuthorization()
        locationManager.startUpdatingLocation()
        
        var edgeSwipe = UIScreenEdgePanGestureRecognizer(target: self, action: "respondToSwipeGesture:")
        edgeSwipe.edges = UIRectEdge.Right;
        self.view.addGestureRecognizer(edgeSwipe)
        
        var swipeUp = UISwipeGestureRecognizer(target: self, action: "respondToSwipeGesture:")
        swipeUp.direction = .Up
        view.addGestureRecognizer(swipeUp)
    }
    
    func respondToSwipeGesture(gesture: UIScreenEdgePanGestureRecognizer) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil);
        let vc = storyboard.instantiateViewControllerWithIdentifier("debugviewcontroller") as UIViewController;
        self.presentViewController(vc, animated: true, completion: nil);
    }
    func respondToTap(gesture: UITapGestureRecognizer) {
        self.txtMessages.text = ""
    }
    
    //MARK:  location
    
    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        
        var location = locations[locations.endIndex - 1] as CLLocation
        self.game.playerUpdate(network.peerID, location: location)
        
        var coordinate = location.coordinate
        var accuracy = location.horizontalAccuracy
        var lat = coordinate.latitude
        var long = coordinate.longitude
        var distanceInMeters = 0.0;
        if (lastLocation != nil)
        {
            distanceInMeters = location.distanceFromLocation(lastLocation!)
        }
        var message = "Latitude: \(lat)\nLongitude: \(long)\nDifference: \(distanceInMeters)\nAccuracy: \(accuracy)"
        txtLocation.text = message
        lastLocation = location
        
    }
    
    func locationManager(manager: CLLocationManager!, didFailWithError error: NSError!) {
        let message = "Error while updating location: " + error.localizedDescription
        txtLocation.text = message
    }
    
    func textFieldShouldReturn(textField: UITextField!) -> Bool {   //delegate method
        network.sendToPeers(Game.Messages.MsgTypeChat,data: self.txtChatMsg.text)
        txtChatMsg.text = "";
        txtChatMsg.resignFirstResponder()
        return true;
    }
    
    
    
    /*
    * Logs a message in raw form to the output text view
    */
    func logit(message: String) {
        println(message)
        self.txtMessages.text = message + "\n" + self.txtMessages.text
    }
    
    func updateChat(text : String, fromPeer peerID: MCPeerID) {
        // Appends some text to the chat view
        
        // If this peer ID is the local device's peer ID, then show the name
        // as "Me"
        var name : String
        
        switch peerID {
        case network.peerID:
            name = "Me"
        default:
            name = peerID.displayName
        }
        
        // Add the name to the message and display it
        let message = "\(name): \(text)\n"
        self.txtMessages.text =  message + self.txtMessages.text
        self.txtChatMsg.text = ""
    }
   

    @IBAction func btnSend(sender: UIButton) {
        network.sendToPeers(Game.Messages.MsgTypeChat,data: self.txtChatMsg.text)        
    }

    @IBAction func btnFire_Clicked(sender: AnyObject) {
        fire();
    }
    
    func getTarget() -> MCPeerID?
    {
        var target = self.targetPeer
        return target;
    }
    
    func setPotentialTarget(target: MCPeerID!)
    {
        targetPeers[target] = true
        if (getTarget() == nil)
        {
            //audioPing.play()
            self.targetPeer = target
            self.btnFire.hidden = false
        }
        if (contains(targetsForDataBinding, target) == false) {
            RegenerateTargetListForBinding()
        }
    }
 
    func clearPotentialTarget(target: MCPeerID!)
    {
        targetPeers[target] = false
        if (getTarget() == target)
        {
            self.targetPeer = nil
            self.btnFire.hidden = true
        }
        
        findPotentialTarget()
        
        if (contains(targetsForDataBinding, target)) {
            RegenerateTargetListForBinding()
        }
    }
    
    func findPotentialTarget()
    {
        for (id, playerInRange) in targetPeers
        {
            if (playerInRange)
            {
                setPotentialTarget(id)
                break
            }
        }
    }
 
    func RegenerateTargetListForBinding()
    {
        targetsForDataBinding.removeAll(keepCapacity: true)
        for (id, playerInRange) in targetPeers
        {
            if (playerInRange)
            {
                targetsForDataBinding.append(id)
            }
        }
        //logit("In/Out range change: reloading data")
        tableView.reloadData()
    }
    
    func inRange(playerID : MCPeerID!)
    {
        setPotentialTarget(playerID)
    }
    
    func outOfRange(playerID : MCPeerID!)
    {
        clearPotentialTarget(playerID)
    }
    
    func handlePlayerDisconnect(playerID: MCPeerID)
    {
        targetPeers.removeValueForKey(playerID)
        // if the player disconnecting was my target, null it out
        if (getTarget() == playerID)
        {
            self.targetPeer = nil
        }
        // regenerate the table view
        if (contains(targetsForDataBinding, playerID)) {
            RegenerateTargetListForBinding()
        }
    }
    
    func fire()
    {
        self.btnFire.hidden = true
        self.btnFire.enabled = false
        self.btnFire.backgroundColor = UIColor.blackColor()
        
        var target = getTarget()
        if (target != nil)
        {
            ableToFire = false;
            timerAbleToFire = NSTimer.scheduledTimerWithTimeInterval(
                10.0, target: self, selector:"torpedosLoaded", userInfo: nil, repeats: false)
            
            audioFire.play()
            self.game.fire(target)
            println("fired at \(target!.displayName)")
        }
    }
    
    func torpedosLoaded()
    {
        ableToFire = true
        timerAbleToFire!.invalidate()
        self.btnFire.enabled = true
        self.btnFire.backgroundColor = UIColor.redColor()
        println("torpedos loaded")
        findPotentialTarget();
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
   
    
    @IBOutlet weak var tableView: UITableView!
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var count = self.targetsForDataBinding.count
        return count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell:UITableViewCell = self.tableView.dequeueReusableCellWithIdentifier("cell") as UITableViewCell
        var player:MCPeerID = self.targetsForDataBinding[indexPath.row]
//        cell.lblPlayerName.text = player.displayName
//        cell.btnFire.addTarget(self, action: "fireTorpedo:", forControlEvents: UIControlEvents.TouchUpInside)
        var playerName = player.displayName
        cell.textLabel?.text = playerName
        return cell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        
    }
    
    func fireTorpedo(sender:UIButton!)
    {
       println("button clicked")
    }
}

