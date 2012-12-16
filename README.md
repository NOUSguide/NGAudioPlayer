NGAudioPlayer
=============

A threadsafe audio player for iOS that can handle queueing of URLs, supports background audio and supports iOS standard media and controls.

Supporting iOS standard media and remote controls
-------------------------------------------------

To get the controls connected with NGAudioPlayer unfortunately you need to put this three lines of code into your AppDelegate:

```objectivec
- (void)remoteControlReceivedWithEvent:(UIEvent *)receivedEvent {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"remoteControlReceivedWithEvent" object:receivedEvent];
}
```

Thread safety
-------------

NGAudioPlayer's methods can be executed from any thread or queue without hesitation. NGAudioPlayer executes all delegate methods on the main queue by default but you can set it using the property 'delegate_queue'.