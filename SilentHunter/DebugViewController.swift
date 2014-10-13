//
//  ViewController.swift
//  SilentHunter
//
//  Created by Tommy Fannon on 10/11/14.
//  Copyright (c) 2014 Crazy8Dev. All rights reserved.
//

import UIKit
import CoreLocation

class DebugViewController: UIViewController, UITextFieldDelegate
{
    @IBOutlet var txtSession: UITextField!
    @IBOutlet var sessionOverride: UISwitch!
    
    @IBOutlet var lblMsgs: UILabel!
    @IBOutlet weak var stepLogMsgs: UIStepper!
    
    @IBOutlet var locationOverride: UISwitch!
    @IBOutlet var txtLatitude: UITextField!
    @IBOutlet var txtLongitude: UITextField!
    
    @IBOutlet var txtMoveLeftGPSAmount: UITextField!
    @IBOutlet var stpLocationOverride: UIStepper!
    
    @IBOutlet var txtStatus: UITextView!
    
    @IBAction func moveStepperChanged(sender: UIStepper) {
        var moveLeftInMeters = sender.value;
        txtMoveLeftGPSAmount.text = NSString(format: "%.1f", moveLeftInMeters)
        gSettings.locationOffset = sender.value
        gSettings.persist()
    }
   
    @IBAction func stepLogMsgs(sender: UIStepper) {
        lblMsgs.text = String(gSettings.maxLogMsgs)
        gSettings.maxLogMsgs = Int(sender.value)
        gSettings.persist()
    }
    
    @IBAction func handleSessionOverride(sender: UISwitch) {
        gSettings.sessionOverride = sender.on
        gSettings.persist()
    }
    
    @IBAction func handleSessionNameChanged(sender: UITextField) {
        gSettings.sessionName = sender.text
        gSettings.persist()
    }
    
    @IBAction func handleLocationOverride(sender: UISwitch) {
        gSettings.locationOverride = sender.on
        if (sender.on) {
            moveStepperChanged(stpLocationOverride)
        }
        gSettings.persist()
    }
    
    @IBAction func handleLatitudeChange(sender: UITextField) {
        gSettings.latitude = txtLatitude.text.toDouble()!
        gSettings.persist()
    }
    
    @IBAction func handleLongitudeChange(sender: UITextField) {
        gSettings.longitude = txtLongitude.text.toDouble()!
        gSettings.persist()
    }


    func textFieldShouldReturn(textField: UITextField) -> Bool {
        txtSession.resignFirstResponder()
        txtLatitude.resignFirstResponder()
        txtLongitude.resignFirstResponder()
        txtMoveLeftGPSAmount.resignFirstResponder()
        return true
    }

    
    //MARK:  controller
    override func viewDidLoad() {
        super.viewDidLoad()
        
        var edgeSwipe = UIScreenEdgePanGestureRecognizer(target: self, action: "respondToSwipeGesture:")
        edgeSwipe.edges = UIRectEdge.Left
        self.view.addGestureRecognizer(edgeSwipe)
        
        var swipe = UISwipeGestureRecognizer(target: self, action: "respondToSwipeGesture:")
        swipe.direction = .Down
        view.addGestureRecognizer(swipe)
        
        let center = NSNotificationCenter.defaultCenter()
        center.addObserver(self, selector: "keyboardWillShow:", name: UIKeyboardDidShowNotification, object: nil)
        center.addObserver(self, selector: "keyboardWillHide:", name: UIKeyboardDidHideNotification, object: nil)
        
        txtSession.delegate = self
        txtLatitude.delegate = self
        txtLongitude.delegate = self
        txtMoveLeftGPSAmount.delegate = self

        sessionOverride.on = gSettings.sessionOverride
        txtSession.text = gSettings.sessionName
        locationOverride.on = gSettings.locationOverride
        txtLatitude.text = "\(gSettings.latitude)"
        txtLongitude.text = "\(gSettings.longitude)"
        lblMsgs.text = String(gSettings.maxLogMsgs)
        stepLogMsgs.value = Double(gSettings.maxLogMsgs)
        stpLocationOverride.value = gSettings.locationOffset
        txtMoveLeftGPSAmount.text = NSString(format: "%.1f", gSettings.locationOffset)
    }
    
    func respondToSwipeGesture(gesture: UIScreenEdgePanGestureRecognizer) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func keyboardWillShow(sender: NSNotification) {
        self.view.frame.origin.y -= 200
    }
    func keyboardWillHide(sender: NSNotification) {
        self.view.frame.origin.y += 200
    }
}

