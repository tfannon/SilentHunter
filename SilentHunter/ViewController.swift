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

class ViewController: UIViewController, CLLocationManagerDelegate,UITextFieldDelegate, GameDelegate, UITableViewDelegate, UITableViewDataSource, IChat
{

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        game = Game(id: sessionManager.peerID)
     }
    
    var game: Game!
    var locationManager : CLLocationManager!
    var network : Networking!
    
    var lblOutput : UILabel!
    var lastLocation : CLLocation?
    var audioPing : AudioPlayer = AudioPlayer(filename: "ping")
    var audioHit : AudioPlayer = AudioPlayer(filename: "hit")
    var targetPeers = [MCPeerID : Bool]()
    var targetPeer : MCPeerID?
    var ableToFire : Bool = true
    var timerAbleToFire : NSTimer?
    
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

   
    //MARK:  controller
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "cell")
        
        self.txtChatMsg.delegate = self;
        
        // Do any additional setup after loading the view, typically from a nib.
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 0.0;//33
        locationManager.requestAlwaysAuthorization()
        locationManager.startUpdatingLocation()
        
        network = sessionManager
        game.network = network
        
        self.game.delegate = self;
        
        self.game!.delegate = self;
        self.btnFire.hidden = true;
        self.btnFire.setTitle("Loading torpedoes", forState: UIControlState.Disabled)
        

    }
    
    func restoreUserPrefs() {
        let userDefaults = NSUserDefaults.standardUserDefaults();
        if let prefs = userDefaults.objectForKey("prefs") as? Dictionary<String,String> {
            self.prefs = prefs
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
                var lat = coordinate.latitude
                var long = coordinate.longitude
                var distanceInMeters = 0.0;
                if (lastLocation != nil)
                {
                    distanceInMeters = location.distanceFromLocation(lastLocation!)
                }
                var message = "Latitude: \(lat)\nLongitude: \(long)\nDifference: \(distanceInMeters)"
                txtLocation.text = message
                self.game.playerUpdate(sessionManager.peerID, location: location)
                lastLocation = location
            }
        }
    }
    
    func locationManager(manager: CLLocationManager!, didFailWithError error: NSError!) {
        let message = "Error while updating location: " + error.localizedDescription
        txtLocation.text = message
    }
    
    func textFieldShouldReturn(textField: UITextField!) -> Bool {   //delegate method
        //network.sendToPeers(Game.Messages.MsgTypeChat,data: self.txtChatMsg.text)
        txtChatMsg.text = "";
        return false;
    }
    
    
    
    /*
    * Logs a message in raw form to the output text view
    */
    func logit(message: String) {
        println(message)
        self.txtMessages.text = self.txtMessages.text + message + "\n"
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
        self.txtMessages.text = self.txtMessages.text + message
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
    }
 
    func clearPotentialTarget(target: MCPeerID!)
    {
        targetPeers[target] = false
        if (getTarget() == target)
        {
            self.targetPeer = nil
            self.btnFire.hidden = true
            for (id, playerInRange) in targetPeers
            {
                if (playerInRange)
                {
                    setPotentialTarget(id)
                    break
                }
            }
        }
    }
    
    func inRange(playerID : MCPeerID!)
    {
        setPotentialTarget(playerID)
    }
    
    func outOfRange(playerID : MCPeerID!)
    {
        clearPotentialTarget(playerID)
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
        return self.game.getPlayerCount();
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell:UITableViewCell = self.tableView.dequeueReusableCellWithIdentifier("cell") as UITableViewCell
        var playerInfo:PlayerInfo = self.game.getPlayer(indexPath.row)
        cell.textLabel?.text = playerInfo.playerID.displayName
        return cell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        
    }
    
}

