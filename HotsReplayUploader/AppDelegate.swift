//
//  AppDelegate.swift
//  HotsReplayUploader
//
//  Created by Gabriel N on 12/04/15.
//  Copyright (c) 2015 Gabriel N. All rights reserved.
//

import Cocoa
import EonilFileSystemEvents
import AppKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet var textLog: NSTextView!

    let blizzardAppSuppPath:String = "~/Library/Application Support/Blizzard/".stringByExpandingTildeInPath
    var appStorage =  NSFileManager.defaultManager().URLForDirectory(NSSearchPathDirectory.ApplicationSupportDirectory, inDomain: NSSearchPathDomainMask.UserDomainMask, appropriateForURL: nil, create: false, error: nil)!.path! + "/KonsultbyraGN/Hotsuploader/Replays"
    var	monitor	=	nil as FileSystemEventMonitor?
    
    var statusBar = NSStatusBar.systemStatusBar()
    var statusBarItem : NSStatusItem = NSStatusItem()
    var menu : NSMenu = NSMenu()
    var menuItemShow : NSMenuItem = NSMenuItem()
    var menuItemExit: NSMenuItem = NSMenuItem()

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        
        // Insert code here to initialize your application
        self.textLog.string = "Initialized HotsReplayUploader..."
        let operationQueue = NSOperationQueue()
        println(appStorage)
        operationQueue.addOperationWithBlock() {
            var error : NSError?
            NSFileManager.defaultManager().createDirectoryAtPath(self.appStorage, withIntermediateDirectories: true, attributes: nil, error: &error)
            if (error != nil) {
                self.textLog.string = "Error could not create app-storage, things won't work"
            }
            self.scanForReplays()
            self.watchForReplays()
        }
        
        // Very basic update code, allows me to pup up a message which opens a static link 
        // when there is a new version
        var error : NSError?
        let updateMessage = String(contentsOfURL: NSURL(string:"https://nyman.re/hotsreplayuploader/update_alpha.txt")!, encoding: NSUTF8StringEncoding, error: &error)
        if (updateMessage != "") {
            let updatePopup:NSAlert = NSAlert()
            updatePopup.addButtonWithTitle("View details and download")
            updatePopup.addButtonWithTitle("Cancel")
            updatePopup.messageText = "New update available"
            updatePopup.informativeText = updateMessage
            if updatePopup.runModal() == NSAlertFirstButtonReturn {
                NSWorkspace.sharedWorkspace().openURL(NSURL(string: "https://nyman.re/hotsreplayuploader/update.html")!)
            }
        }
        
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }
    
    func  uploadFile(path: String, fileName: String) -> Bool {
        let contentType = "application/octet-stream"
        let file = NSUUID().UUIDString + "-" + fileName
        let fileUrlEncoded = file.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)!
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "EEE, dd MMM YYYY HH:mm:ss Z"
        let formattedDate = dateFormatter.stringFromDate(NSDate())
        let resource = "\(bucket)"
        let s3stringToSign = "PUT\n\n\(contentType)\n\(formattedDate)\n/\(bucket)/\(fileUrlEncoded)"
        //println("String to sign:")
        //println(s3stringToSign)
        let s3authorizationHeader = s3stringToSign.hmacData(.SHA1, key: s3secret).base64EncodedStringWithOptions(NSDataBase64EncodingOptions.Encoding76CharacterLineLength)
        //println("S3 auth header:", s3authorizationHeader)
        //println(fileUrlEncoded)
        //println(NSURL(string: "https://\(bucket).s3.amazonaws.com/\(fileUrlEncoded)"))
        var request = NSMutableURLRequest(URL: NSURL(string: "https://\(bucket).s3.amazonaws.com/\(fileUrlEncoded)")!)
        request.HTTPMethod = "PUT"
        request.setValue("AWS \(s3accessKey):" + s3authorizationHeader, forHTTPHeaderField: "Authorization")
        request.setValue(formattedDate, forHTTPHeaderField: "Date")
        
        var nsurlConfiguration = NSURLSessionConfiguration.defaultSessionConfiguration()
        var session = NSURLSession(configuration: nsurlConfiguration, delegate: nil, delegateQueue: nil)
        
        //println("Request:")
        //println(request);
        //println(request.allHTTPHeaderFields)
        
        let fullPath = NSURL.fileURLWithPath(path + "/" + fileName)
        if fullPath == nil {
            return false
        }
        //println("Creating upload task for \(fullPath)")
        var task = session.uploadTaskWithRequest(request, fromFile: fullPath!, completionHandler: {data, response, error in
            //println("Response")
            //println(response);
            //println(NSString(data:data, encoding: NSUTF8StringEncoding));
            
            println("Pinging hotslogs at https://www.hotslogs.com/UploadFile.aspx?FileName=\(fileUrlEncoded)")
            var hotslogPingUrl = NSURL(string: "https://www.hotslogs.com/UploadFile.aspx?FileName=\(fileUrlEncoded)")
            var pingError: NSError?
            var success = String(contentsOfURL: hotslogPingUrl!, encoding: NSUTF8StringEncoding, error: &pingError)
            if (pingError != nil) {
                println("Error pinging hotslogs, error was\(pingError?.description)")
                self.textLog.string = self.textLog.string! + "\nFailed to ask hotslogs to process \(fileName), will try again later"
            }
            println("Pinged hotslogs, got back \(success)")
            // Create the upload indicator
            let uploadedIndicator = "\(self.appStorage)/.hotslogUploaded_\(fileName)"
            NSFileManager.defaultManager().createFileAtPath(uploadedIndicator, contents: nil, attributes: nil)
            dispatch_async(dispatch_get_main_queue()) {
                self.textLog.string = self.textLog.string! + "\nHotslogs: Uploaded \(fileName)"
            }
        });
        task.resume()
        return true
    }
    
    func uploadHeroesGG(path: String, fileName:String) -> Bool {
        let fullPath = NSURL.fileURLWithPath(path + "/" + fileName)
        if fullPath == nil {
            return false
        }
        var request = NSMutableURLRequest(URL: NSURL(string: "http://upload.hero.gg/ajax/upload-replay?from=hotsreplayuploader")!)
        request.HTTPMethod = "POST"
        var nsurlConfiguration = NSURLSessionConfiguration.defaultSessionConfiguration()
        
        
        // Multipart/form-data uploading based on https://medium.com/@creativewithin/uploading-a-file-in-swift-via-post-multipart-form-data-93dd1001f9e5
        let boundaryConstant = "Boundary-7MA4YWxkTLLu0UIW";
        let contentType = "multipart/form-data; boundary=" + boundaryConstant
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        let fieldName = "file"
        let mimeType = "application/octet-stream"
        
        // Set data
        var error: NSError?
        var replayDataString = NSData(contentsOfFile: "\(path)/\(fileName)")!
        var dataString:NSMutableData = "--\(boundaryConstant)\r\n".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)!.mutableCopy() as! NSMutableData
        dataString.appendData("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)
        dataString.appendData("Content-Type: \(mimeType)\r\n\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)
        dataString.appendData(replayDataString)
        dataString.appendData("\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)
        dataString.appendData("--\(boundaryConstant)--\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)
        
        var session = NSURLSession(configuration: nsurlConfiguration, delegate: nil, delegateQueue: nil)
        var task = session.uploadTaskWithRequest(request, fromData:dataString, completionHandler: {data, response, error in
            //println("Hero.gg response")
            //println(response)
            //println(error)
            //println(NSString(data:data, encoding: NSUTF8StringEncoding))
            if(response != nil && error == nil) {
                println("Seemed to succeed, creating uploadedIndicator")
                let uploadedIndicator = "\(self.appStorage)/.heroggUploaded_\(fileName)"
                NSFileManager.defaultManager().createFileAtPath(uploadedIndicator, contents: nil, attributes: nil)
                dispatch_async(dispatch_get_main_queue()) {
                    self.textLog.string = self.textLog.string! + "\nHero.gg: Uploaded \(fileName)"
                }
            }
        });
        task.resume()
        return true
    }

    func handleFileEvent(events: [FileSystemEvent]) -> () {
        dispatch_async(dispatch_get_main_queue()) {
            println(events)
            for event in events {
                println(event)
                self.processFile(event.path)
            }
        }
    }
    
    func processFile(absolutePath: String) -> Bool {
        let fileName = absolutePath.lastPathComponent
        let path = absolutePath.stringByDeletingLastPathComponent
        // Do basic checks to see that it's a replay in the correct location
        // and that it's not a "uploaded-indicator"
        if (
            !fileName.lowercaseString.hasSuffix(".stormreplay") ||
            fileName.rangeOfString("Uploaded_") != nil ||
            path.lastPathComponent.lowercaseString != "multiplayer"
            ) {
                //println("Failed basic checks for \(absolutePath)")
                return false
        }
        let uploadedIndicator = "\(appStorage)/.hotslogUploaded_\(fileName)"
        if (
            NSFileManager.defaultManager().fileExistsAtPath(absolutePath) &&
            !NSFileManager.defaultManager().fileExistsAtPath(uploadedIndicator)
            ) {
                println("Would upload \(absolutePath)")
                uploadFile(path, fileName: fileName)
        } else {
            //println("File \(absolutePath) does not exist or already upladed")
        }
        
        // Also upload to hero.gg
        let heroggUploadedIndicator = "\(appStorage)/.heroggUploaded_\(fileName)"
        if (
            NSFileManager.defaultManager().fileExistsAtPath(absolutePath) &&
                !NSFileManager.defaultManager().fileExistsAtPath(heroggUploadedIndicator)
            ) {
                println("Would upload to hero.gg \(absolutePath)")
                uploadHeroesGG(path, fileName: fileName)
        } else {
            //println("File \(absolutePath) does not exist or already upladed")
        }
        return true
    }
    
    func watchForReplays() {
        var	queue	=	dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)
        monitor	=	FileSystemEventMonitor(pathsToWatch: [blizzardAppSuppPath], latency: 1, watchRoot: false, queue: queue, callback: handleFileEvent)
        println("Watching \(blizzardAppSuppPath)")
        self.textLog.string = self.textLog.string! + "\nWatching the replay folder for changes..."
    }
    
    func scanForReplays() {
        let fileManager = NSFileManager.defaultManager()
        let enumerator:NSDirectoryEnumerator = fileManager.enumeratorAtPath(blizzardAppSuppPath)!
        while let element =  enumerator.nextObject() as? String {
            let path = "\(blizzardAppSuppPath)/\(element)"
            processFile(path)
        }
        self.textLog.string = self.textLog.string! + "\nScanned the replay folder for replays..."
    }
    
    override func awakeFromNib() {
        createStatusBar()
    }
    
    func createStatusBar() {
        // Add the status bar item
        statusBarItem = statusBar.statusItemWithLength(-1)
        statusBarItem.menu = menu
        statusBarItem.image = NSImage(named: "MenuIcon")
        //statusBarItem.action = Selector("setWindowVisible:")
        
        menuItemShow.title = "Show main window"
        menuItemShow.action = Selector("setWindowVisible:")
        
        menuItemExit.title = "Quit HotsReplayUploader"
        menuItemExit.action = Selector("terminate:")
        
        menu.addItem(menuItemShow)
        menu.addItem(menuItemExit)
    }
    
    func setWindowVisible(sender: AnyObject) {
        //self.window!.orderFront(self)
        self.window!.orderFrontRegardless()
    }

}

