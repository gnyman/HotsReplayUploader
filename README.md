# OS X replay uploader for Heroes of the Storm

Very light weight and simple (with emphasis on simple) tool which will (hopefully) automatically upload all your replays as you play heroes of the storm.

It's mainly a project for me to play around with Swift and some OS X programming with the added bonus of maybe being helpful to me when I occasionally play and maybe somebody else.

## Alpha
Currently it's a early alpha, it runs and it uploads files. It has zero error handling and a very ugly way of knowing which files it has already uploaded.

Feel free to try it out if you feel brave, there is no logic to remove any files so there should not be any risk but no guarantees.

## Technical stuff
### Keeping track of uploaded files
It uses a very silly way of keeping track of which files it has uploaded, when it thinks it has uploaded a replay successfully (remember no error checking) it creates a hidden file names .hotslogUploaded_<name of uploaded file> in the same folder as the replay. If it finds this file, it assumes the replay is uploaded. This of course means that if you ever delete a replay that it has uploaded, due to HOTS reusing the names, it won't be uploaded again. This will be fixed as soon as I learn CoreData or give up on that and use some other method of storing which ones has been uploaded.

### Lightweight
When you start the app, it scans through you whole Blizzard app data folder to find .stormreplay files which has not been uploaded. After that, it uses the native FSNotify API to get notified about changes in the folders. This should mean it uses 0 cpu power after it has been started unless there is something to do. The idea is that it should be lightweight enough to run all the time, even when you don't play HOTS.

## Get it
You can download it from https://nyman.re/hotsreplayuploader/HotsReplayUploaderAlpha.app.zip or you can compile this project. You will have to get the s3 authentication keys from the hotslogs.com maintainer though.

## Known issues
- does not handle the deletion of replays
- ugly

## ToDo
- menubar icon (to be less in the way

# Thanks to
Hoon H. for creating the [EonilFileSystemEvents](https://github.com/Eonil/FileSystemEvents) which does all the work with the file-notify api.
