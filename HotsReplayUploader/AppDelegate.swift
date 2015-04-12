//
//  AppDelegate.swift
//  HotsReplayUploader
//
//  Created by Gabriel N on 12/04/15.
//  Copyright (c) 2015 Gabriel N. All rights reserved.
//

import Cocoa
import EonilFileSystemEvents

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet var textLog: NSTextField!

    let blizzardAppSuppPath:String = "~/Library/Application Support/Blizzard/".stringByExpandingTildeInPath
    
    var	monitor	=	nil as FileSystemEventMonitor?
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application
        self.textLog.stringValue = "Initialized HotsReplayUploader..."
        let operationQueue = NSOperationQueue()
        operationQueue.addOperationWithBlock() {
            self.scanForReplays()
            self.watchForReplays()
        }
        
        let s1      =   FileSystemEventMonitor(
            pathsToWatch: [
                "~/Documents".stringByExpandingTildeInPath,
                "~/Temp".stringByExpandingTildeInPath],
            latency: 1,
            watchRoot: true,
            queue: dispatch_get_main_queue()) { (events:[FileSystemEvent])->() in
                println(events)
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
        println("String to sign:")
        println(s3stringToSign)
        let s3authorizationHeader = s3stringToSign.hmacData(.SHA1, key: s3secret).base64EncodedStringWithOptions(NSDataBase64EncodingOptions.Encoding76CharacterLineLength)
        println("S3 auth header:", s3authorizationHeader)
        println(fileUrlEncoded)
        println(NSURL(string: "https://\(bucket).s3.amazonaws.com/\(fileUrlEncoded)"))
        var request = NSMutableURLRequest(URL: NSURL(string: "https://\(bucket).s3.amazonaws.com/\(fileUrlEncoded)")!)
        request.HTTPMethod = "PUT"
        request.setValue("AWS \(s3accessKey):" + s3authorizationHeader, forHTTPHeaderField: "Authorization")
        request.setValue(formattedDate, forHTTPHeaderField: "Date")
        
        var nsurlConfiguration = NSURLSessionConfiguration.defaultSessionConfiguration()
        var session = NSURLSession(configuration: nsurlConfiguration, delegate: nil, delegateQueue: nil)
        
        println("Request:")
        println(request);
        println(request.allHTTPHeaderFields)
        
        let fullPath = NSURL.fileURLWithPath(path + "/" + fileName)
        if fullPath == nil {
            return false
        }
        println("Creating upload task for \(fullPath)")
        var task = session.uploadTaskWithRequest(request, fromFile: fullPath!, completionHandler: {data, response, error in
            println("Response")
            println(response);
            println(NSString(data:data, encoding: NSUTF8StringEncoding));
            
            println("Pinging hotslogs at https://www.hotslogs.com/UploadFile.aspx?FileName=\(fileUrlEncoded)")
            var hotslogPingUrl = NSURL(string: "https://www.hotslogs.com/UploadFile.aspx?FileName=\(fileUrlEncoded)")
            var pingError: NSError?
            var success = String(contentsOfURL: hotslogPingUrl!, encoding: NSUTF8StringEncoding, error: &pingError)
            if (pingError != nil) {
                println("Error pinging hotslogs, error was\(pingError?.description)")
            }
            println("Pinged hotslogs, got back \(success)")
            // Create the upload indicator
            let uploadedIndicator = "\(path)/.hotslogUploaded_\(fileName)"
            NSFileManager.defaultManager().createFileAtPath(uploadedIndicator, contents: nil, attributes: nil)
        });
        task.resume()
        sleep(15)
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
            fileName.rangeOfString(".hotslogUploaded_") != nil ||
            path.lastPathComponent.lowercaseString != "multiplayer"
            ) {
                //println("Failed basic checks for \(absolutePath)")
                return false
        }
        let uploadedIndicator = "\(path)/.hotslogUploaded_\(fileName)"
        if (
            NSFileManager.defaultManager().fileExistsAtPath(absolutePath) &&
            !NSFileManager.defaultManager().fileExistsAtPath(uploadedIndicator)
            ) {
                println("Would upload \(absolutePath)")
                //uploadFile(path, fileName: fileName)
        } else {
            //println("File \(absolutePath) does not exist or already upladed")
        }
        return true
    }
    
    func watchForReplays() {
        var	queue	=	dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)
        monitor	=	FileSystemEventMonitor(pathsToWatch: ["~/Library/Application Support/Blizzard/".stringByExpandingTildeInPath], latency: 1, watchRoot: false, queue: queue, callback: handleFileEvent)
        println("Watching \(blizzardAppSuppPath)")
    }
    
    func scanForReplays() {
        let fileManager = NSFileManager.defaultManager()
        let enumerator:NSDirectoryEnumerator = fileManager.enumeratorAtPath(blizzardAppSuppPath)!
        while let element =  enumerator.nextObject() as? String {
            let path = "\(blizzardAppSuppPath)/\(element)"
            processFile(path)
        }
    }

}

