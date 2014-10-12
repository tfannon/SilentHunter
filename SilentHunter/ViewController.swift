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

class ViewController: UIViewController, CLLocationManagerDelegate,UITextFieldDelegate, GameDelegate, UITableViewDelegate, UITableViewDataSource, IChat, UIGestureRecognizerDelegate, SettingsListener
{
    
    var game: Game! = nil
    var locationManager : CLLocationManager!
    var network : Networking!
    
    var lblOutput : UILabel!
    var lastLocation : CLLocation?
    
    var audioPing : AudioPlayer = AudioPlayer(filename: "ping")
    var audioHit : AudioPlayer = AudioPlayer(filename: "hit")
    var audioFire : AudioPlayer = AudioPlayer(filename: "fire")
    
    var targetPeers = [MCPeerID : PlayerRangeInfo]()
//    var targetPeers = [MCPeerID : Bool]()
    var targetPeer : MCPeerID?
    var targetsForDataBinding = [PlayerRangeInfo]()
    var ableToFire : Bool = true
    var repairing : Bool = false
    var timerLoadingTorpedos : NSTimer?
    var timerReparing : NSTimer?
    var numLogMsgs:Int = 0
    
    var secondsOfTorpedoLoading = 0;
    var secondsOfRepairing = 0;
    
    let SECONDS_FOR_REPAIR = 10
    let SECONDS_FOR_LOAD_TORPEDOS = 5
    
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
        
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 0.0;
        locationManager.requestAlwaysAuthorization()
        locationManager.startUpdatingLocation()
        
        gSettings.registerListener(self)
        
        var edgeSwipe = UIScreenEdgePanGestureRecognizer(target: self, action: "respondToSwipeGesture:")
        edgeSwipe.edges = UIRectEdge.Right;
        self.view.addGestureRecognizer(edgeSwipe)
        
        var swipeUp = UISwipeGestureRecognizer(target: self, action: "respondToSwipeGesture:")
        swipeUp.direction = .Up
        view.addGestureRecognizer(swipeUp)
        
        if (gSettings.locationOverride)
        {
            setOverriddenLocation(gSettings.getFakeLocation())
        }
    }
    
    func respondToSwipeGesture(gesture: UIScreenEdgePanGestureRecognizer) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil);
        let vc = storyboard.instantiateViewControllerWithIdentifier("debugviewcontroller") as DebugViewController;
        vc.mainViewController = self
        self.presentViewController(vc, animated: true, completion: nil);
    }
    func respondToTap(gesture: UITapGestureRecognizer) {
        self.txtMessages.text = ""
    }
    
    //MARK:  location
    
    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        
        var location = locations[locations.endIndex - 1] as CLLocation
        if (!gSettings.locationOverride) {
            setOverriddenLocation(location)
        }
    }
    
    func setOverriddenLocation(location: CLLocation)
    {
        self.game.playerLocationUpdate(network.peerID, location: location)
        
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
        if (++numLogMsgs > gSettings.maxLogMsgs) {
            self.txtMessages.text = ""
            numLogMsgs = 0
        }
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
    
    private func setPotentialTarget(target: MCPeerID!, distance:Double)
    {
        targetPeers[target] = PlayerRangeInfo(target: target, range: true, dist:distance)
        if (getTarget() == nil && ableToFire)
        {
            //audioPing.play()
            self.targetPeer = target
            self.btnFire.enabled = true
            self.btnFire.hidden = false
        }

        RegenerateTargetListForBinding()
    }
 
    private func clearPotentialTarget(target: MCPeerID!, distance:Double)
    {
        targetPeers[target] = PlayerRangeInfo(target: target, range: false, dist: distance)
        if (getTarget() == target)
        {
            self.targetPeer = nil
            self.btnFire.hidden = true
            for (id, playerRangeInfo) in targetPeers
            {
                if (playerRangeInfo.inRange)
                {
                    setPotentialTarget(id, distance: playerRangeInfo.distance)
                    break
                }
            }
        }
        
        findPotentialTarget()
        RegenerateTargetListForBinding()
    }
    
    func findPotentialTarget()
    {
        for (id, playerRangeInfo) in targetPeers
        {
            if (playerRangeInfo.inRange)
            {
                setPotentialTarget(id, distance: playerRangeInfo.distance)
                break
            }
        }
    }
 
    func RegenerateTargetListForBinding()
    {
        targetsForDataBinding.removeAll(keepCapacity: true)
        for (id, playerRangeInfo) in targetPeers
        {
            if (playerRangeInfo.inRange)
            {
                targetsForDataBinding.append(playerRangeInfo)
            }
        }
        //logit("In/Out range change: reloading data")
        tableView.reloadData()
    }
    
    func inRange(playerID : MCPeerID!, distance:Double)
    {
        setPotentialTarget(playerID, distance: distance)
    }
    
    func outOfRange(playerID : MCPeerID!, distance:Double)
    {
        clearPotentialTarget(playerID, distance: distance)
    }
    
    func handlePlayerDisconnect(playerID: MCPeerID)
    {
        targetPeers.removeValueForKey(playerID)
        // if the player disconnecting was my target, null it out
        if (getTarget() == playerID)
        {
            self.targetPeer = nil
            self.btnFire.hidden = true
            // look to see if there is another candidate peer target
            findPotentialTarget()
        }
        RegenerateTargetListForBinding()
    }
    
    func fire()
    {
        if (ableToFire)
        {
            disableFireButton("Loading torpedos")
            
            var target = getTarget()
            if (target != nil)
            {
                ableToFire = false;
                timerLoadingTorpedos = NSTimer.scheduledTimerWithTimeInterval(
                    1.0, target: self, selector:"torpedosLoading", userInfo: nil, repeats: false)
                
                audioFire.play()
                self.game.fire(target)
                println("fired at \(target!.displayName)")
            }
        }
    }
    
    func torpedosLoading()
    {
        self.secondsOfTorpedoLoading++;
        self.btnFire.setTitle("Loading torpedos \(SECONDS_FOR_LOAD_TORPEDOS - secondsOfTorpedoLoading)", forState: UIControlState.Disabled)
        if (secondsOfTorpedoLoading >= SECONDS_FOR_LOAD_TORPEDOS)
        {
            timerLoadingTorpedos?.invalidate()
            torpedosLoaded()
        }
    }
    func torpedosLoaded()
    {
        self.secondsOfTorpedoLoading = 0;
        ableToFire = true
        enableFireButton()
        println("torpedos loaded")
        findPotentialTarget();
    }

    func reparing()
    {
        self.secondsOfRepairing++
        self.btnFire.setTitle("Repairing \(SECONDS_FOR_REPAIR - secondsOfRepairing)", forState: UIControlState.Disabled)
        if (secondsOfTorpedoLoading >= SECONDS_FOR_REPAIR)
        {
            timerReparing?.invalidate()
            repairsComplete()
        }
    }
    func repairsComplete()
    {
        self.secondsOfRepairing = 0;
        ableToFire = true
        enableFireButton()
        println("repairs complete")
    }
    
    func hit(playerID: MCPeerID!)
    {
        if (timerReparing != nil)
        {
            timerReparing!.invalidate()
        }
        ableToFire = false
        disableFireButton("Repairing")
        timerReparing = NSTimer.scheduledTimerWithTimeInterval(
            1.0, target: self, selector:"repairing", userInfo: nil, repeats: false)
        audioHit.play()
        AudioPlayer.vibrate()
    }
    
    func firedUpon(playerID: MCPeerID!) {
    }
    
    func enableFireButton()
    {
        self.btnFire.enabled = true
        self.btnFire.backgroundColor = UIColor.redColor()
    }
    
    func disableFireButton(label : NSString!)
    {
        self.btnFire.setTitle(label, forState: UIControlState.Disabled)
        self.btnFire.enabled = false
        self.btnFire.backgroundColor = UIColor.blackColor()
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
        var playerInfo:PlayerRangeInfo = self.targetsForDataBinding[indexPath.row]
        var d = String(format: "%5.1f", playerInfo.distance)
        var playerName = "\(playerInfo.player.displayName) (\(d))m"
        cell.textLabel?.text = playerName
        return cell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        
    }
    
    func fireTorpedo(sender:UIButton!)
    {
       println("button clicked")
    }
    
    //Mark: Settings Listener
    func settingDidChange(settingType: SettingType) {
        if settingType == SettingType.Session {
            network.restartServices()
        }
    }
}

class PlayerRangeInfo {
    init(target:MCPeerID!, range:Bool, dist:Double) {
        inRange = range
        distance = dist
        player = target
    }
    var player:MCPeerID
    var inRange:Bool
    var distance:Double
}

