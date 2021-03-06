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

class ViewController: UIViewController, CLLocationManagerDelegate,
    UITextFieldDelegate, GameDelegate, UITableViewDelegate, UITableViewDataSource, IChat, UIGestureRecognizerDelegate, SettingsListener, TimerDelegate
{
    
    //MARK: Variables
    var game: Game! = nil
    var locationManager : CLLocationManager!
    var network : Networking!
    
    var lblOutput : UILabel!
    var lastLocation : CLLocation?
    
    var audioPing : AudioPlayer = AudioPlayer(filename: "ping")
    var audioHit : AudioPlayer = AudioPlayer(filename: "hit")
    var audioFire : AudioPlayer = AudioPlayer(filename: "fire")
    
    var targetPeers = [MCPeerID : PlayerRangeInfo]()
    var targetPeer : MCPeerID?
    var targetsForDataBinding = [PlayerRangeInfo]()
    
    let LOADING_TORPEDOS : NSString! = "LOADING_TORPEDOS"
    let REPAIRING : NSString! = "REPAIRING"
    let SONAR : NSString! = "SONAR"
    
    var timerLoadingTorpedos : Timer!
    var timerReparing : Timer!
    var timerSonar : Timer!
    var numLogMsgs:Int = 0
    
    var myLocation : CLLocation! = nil
    
    var debugController : DebugViewController!
    
    //MARK: Outlets
    @IBOutlet var btnFire: UIButton!
    @IBOutlet var txtLocation: UILabel!
    @IBOutlet var txtMessages: UITextView!
    @IBOutlet var txtChatMsg: UITextField!
    @IBOutlet var tableView: UITableView!
    
   
    //MARK: Controller methods
    override func viewDidLoad() {
        super.viewDidLoad()
        
        timerLoadingTorpedos = Timer(identifier: LOADING_TORPEDOS, delegate: self, increment: 1, totalSeconds: 5, repeats: false)
        timerReparing = Timer(identifier: REPAIRING, delegate: self, increment: 1, totalSeconds: 10, repeats: false)
        timerSonar = Timer(identifier: SONAR, delegate: self, increment: 1, totalSeconds: 5, repeats: true)
        timerSonar.start()

        self.tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "cell")
        self.txtChatMsg.delegate = self;
        
        //instantiate and hold onto our debug controller
        self.debugController = self.storyboard!.instantiateViewControllerWithIdentifier("debugviewcontroller") as? DebugViewController;
        debugController.viewDidLoad()
        
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
        
        handleFireButton()
    }
    
    func respondToSwipeGesture(gesture: UIScreenEdgePanGestureRecognizer) {
        
        self.presentViewController(debugController, animated: true, completion: nil);
    }
    
    func respondToTap(gesture: UITapGestureRecognizer) {
        self.txtMessages.text = ""
    }
    
    //MARK:  location
    
    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        
        var location = locations[locations.endIndex - 1] as CLLocation
        if (!gSettings.locationOverride) {
            setLocation(location)
        }
    }
    
    func locationManager(manager: CLLocationManager!, didFailWithError error: NSError!) {
        let message = "Error while updating location: " + error.localizedDescription
        txtLocation.text = message
    }
   
    func setLocation(location: CLLocation)
    {
        myLocation = location
        
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
            //self.debugController.txtStatus.text = ""
            numLogMsgs = 0
        }
        self.debugController.txtStatus.text = message + "\n" + self.debugController.txtStatus.text
        //self.txtMessages.text = message + "\n" + self.txtMessages.text
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
        targetPeers[playerID] = PlayerRangeInfo(target: playerID, range: true, dist: distance)
        RegenerateTargetListForBinding()
        println("inrange [\(network.peerID.displayName)] - [\(playerID.displayName)]")
    }
    
    func outOfRange(playerID : MCPeerID!, distance:Double)
    {
        targetPeers[playerID] = PlayerRangeInfo(target: playerID, range: false, dist: distance)
        RegenerateTargetListForBinding()
        println("outrange [\(network.peerID.displayName)] - [\(playerID.displayName)]")
    }
    
    func handlePlayerDisconnect(playerID: MCPeerID)
    {
        targetPeers.removeValueForKey(playerID)
        RegenerateTargetListForBinding()
    }
    
    func shipOperationsInProgress() -> Bool
    {
        return timerReparing.isRunning() || timerLoadingTorpedos.isRunning()
    }
    
    func timerIncrement(identifier: NSString!, elaspedSeconds : Double, totalSeconds : Double)
    {
        var remainingSeconds = Int(totalSeconds - elaspedSeconds)
        if (identifier == LOADING_TORPEDOS)
        {
            showShipOperationProgress("Loading Torpedos \(remainingSeconds)")
        }
        else if (identifier == REPAIRING)
        {
            showShipOperationProgress("Repairing \(remainingSeconds)")
        }
    }
    
    func timerFinished(identifier: NSString!)  {
        if (identifier == SONAR)
        {
            if (myLocation != nil)
            {
                self.game.playerLocationUpdate(network.peerID, location: myLocation)
                calculateTarget()
            }
        }
        handleFireButton()
    }
    
    func calculateTarget()
    {
        var playerInRangeID : MCPeerID? = nil
        //println("targetPeers [\(network.peerID.displayName)]: \(targetPeers.count)")
        for (id, playerRangeInfo) in targetPeers
        {
            if (playerRangeInfo.inRange)
            {
                playerInRangeID = id
                break
            }
        }
        if (playerInRangeID == nil)
        {
            self.targetPeer = nil
        }
        else if (getTarget() == nil)
        {
            println ("target aquired")
            self.targetPeer = playerInRangeID
        }
        handleFireButton()
    }
    
    func fire()
    {
        timerLoadingTorpedos.start()
        audioFire.play()
        
        var target = getTarget()
        if (target != nil)
        {
            self.game.fire(target)
            println("fired at \(target!.displayName)")
        }
    }
    
    func hit(playerID: MCPeerID!)
    {
        self.timerReparing.start()
        self.timerLoadingTorpedos.stop()
        audioHit.play()
        AudioPlayer.vibrate()
    }
    
    func firedUpon(playerID: MCPeerID!) {
    }
    
    func handleFireButton()
    {
        if (!shipOperationsInProgress())
        {
            self.btnFire.enabled = true
            self.btnFire.backgroundColor = UIColor.redColor()
        }
        self.btnFire.hidden =
            getTarget() == nil && !shipOperationsInProgress()
    }
    
    func showShipOperationProgress(label : NSString!)
    {
        self.btnFire.setTitle(label, forState: UIControlState.Disabled)
        self.btnFire.enabled = false
        self.btnFire.backgroundColor = UIColor.blackColor()
        self.btnFire.hidden = false
    }
    
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
        switch settingType {
            case .Session : network.restartServices()
            case .Location, .LocationOffset, .LocationOverride:
                if (gSettings.locationOverride)
                {
                    self.setLocation(gSettings.getFakeLocation())
                }
        default:""
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

