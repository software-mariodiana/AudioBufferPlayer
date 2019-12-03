##Re-implementing Audio Sessions in Objective-C##

###Documentation###

See: "Audio Session Cookbook" from the [*Audio Session Programming Guide*](https://developer.apple.com/library/ios/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/Cookbook/Cookbook.html)

###Project###
"AudioBufferPlayer" by Matthijs Hollemans  
[https://github.com/hollance/AudioBufferPlayer](https://github.com/hollance/AudioBufferPlayer)

###Description###
In iOS 7 Apple deprecated several methods from its Audio Session C implementation, methods that dealt with initializing and configuring an application's Audio Session. Apple doesn't offer any substitute methods as part of the in-line popup documentation, because the deprecation doesn't involve merely substituting new methods for old. Rather, the reimplementation takes the older C code system and replaces it with a new system written in Objective-C. 

Since I wasn't able to find any example code, after searching Stack Overflow, I—horror of horrors—was forced to read Apple's documentation. Once I got a handle on Mr. Hollemans' code and found the corresponding section in Apple's documentation that dealt with the Objective-C system's handling of initializing, configuring, and so forth, it wasn't that difficult to figure out how to update the code. 

These notes are meant to document what I learned.

###Preliminaries###
After downloading the project from Github, I followed all of Xcode's recommendations for updating the project, including fixing any ARC requirements.

###Moving to Objective-C###

####1. Declarations and a Delegate####

Apple's new system involves `AVAudioSession`. This requires adding the `AVFoundation` framework and then importing the needed header:

    #import <AVFoundation/AVAudioSession.h>
    
I added the import to the `MHAudioBufferPlayer` header file.

Next, the `AVAudioSession` (singleton) instance uses a delegate to handle interruptions. (More on this later.) Since the original code handled interruptions in the `MHAudioBufferPlayer` class, I made this class the delegate, declaring the protocol in the header file:

    @interface MHAudioBufferPlayer : NSObject <AVAudioSessionDelegate>
    
The `MHAudioBufferPlayer` instance is created in the view controller's `setupAudioBufferPlayer` method, so near the bottom of the method, right before the last line where the player is sent its `start` message, I set the instance as the delegate of the `AVAudioSession`:

    [[AVAudioSession sharedInstance] setDelegate:_player];
    
####2. Replacing Deprecated C Functions####

There were four spots in the original code that were flagged as deprecated. These four spots appeared involved three C functions in all. The three functions were:

  1. `AudioSessionInitialize`
  2. `AudioSessionSetProperty`
  3. `AudioSessionSetActive`

These functions appear in the `MHAudioBufferPlayer.m` file in two different methods: `setUpAudioSession` and `tearDownAudioSession`. The original code looked like this:

    - (void)setUpAudioSession
    {
	    AudioSessionInitialize(
		    NULL,
		    NULL,
		    InterruptionListenerCallback,
		    (__bridge void *)self);
    
	    UInt32 sessionCategory = kAudioSessionCategory_MediaPlayback;
	    AudioSessionSetProperty(
		    kAudioSessionProperty_AudioCategory,
		    sizeof(sessionCategory),
		    &sessionCategory);
    
	    AudioSessionSetActive(true);
    }
    
    - (void)tearDownAudioSession
    {
	    AudioSessionSetActive(false);
    }
    
As you can tell, the audio session is initialized, configured, and activated in the `setUpAudioSession` method, and then deactivated in the `tearDownAudioSession` method. Note also that a callback handler for interruptions (there it is again!) is passed during the initialization, and the category of session (`kAudioSessionCategory_MediaPlayback`) is declared in the same method. We're going to reimplement all this in Objective-C, rewriting the two methods.

The `setUpAudioSession` method will now look like this in Objective-C:

    - (BOOL)setUpAudioSession
    {
        BOOL success = NO;
        NSError *error = nil;
       
        AVAudioSession *session = [AVAudioSession sharedInstance];
        
        success = [session setCategory:AVAudioSessionCategoryPlayback error:&error];
        if (!success) {
            NSLog(@"%@ Error setting category: %@",
                  NSStringFromSelector(_cmd), [error localizedDescription]);
            
            // Exit early
            return success;
        }
        
        success = [session setActive:YES error:&error];
        if (!success) {
            NSLog(@"%@", [error localizedDescription]);
        }
        
        return success;
    }
    
Shame on me for not handling potential errors better! (I'm still figuring that part out.) But aside from that, here's what's going on.

In the Objective-C version, `AVAudioSession` is a singleton object. As such, we don't need to worry about initializing it. (The framework takes care of that for us.) I'm setting the same category as used in the C code, only it goes by a different name in the Objective-C implementation: `AVAudioSessionCategoryPlayback`. (See Apple's documentation for full details.) I then activate the session. We don't setup handling for interruptions here, because we will be handling interruptions in the delegate methods.

The reimplemented `tearDownAudioSession` method is even simpler:

    - (BOOL)tearDownAudioSession
    {
        NSError *deactivationError = nil;
        BOOL success = [[AVAudioSession sharedInstance] setActive:NO error:&deactivationError];
        if (!success) {
            NSLog(@"%@", [deactivationError localizedDescription]);
        }
        return success;
    }
    
Essentially, we use the same `setActive:error:` method, only passing `NO` to deactivate the session, rather than `YES` to activate it.

####3. Handling Interruptions####

The phone can ring, an email can ding, and so forth. Therefore, our application should be able to handle potential interruptions. More or less what goes on is that the phone takes control of the Audio Session, taking it away from us, does whatever it needs to do, and when it's finished hands the Audio Session back to us.

In the C implementation, interruptions were handled in a single function, used as a callback: `InterruptionListenerCallback`. We saw that the callback was given to the Audio Session during its initialization. That entire `InterruptionListenerCallback` function can be deleted. We're going to handle interruptions by implementing two delegate methods: `beginInterruption` and `endInterruption`. Just for the sake of comparison, here is the callback function from the original C implementation: 

    static void InterruptionListenerCallback(void *inUserData, UInt32 interruptionState)
    {
	    MHAudioBufferPlayer *player = (__bridge MHAudioBufferPlayer *)inUserData;
	    if (interruptionState == kAudioSessionBeginInterruption)
	    {
		    [player tearDownAudio];
	    }
	    else if (interruptionState == kAudioSessionEndInterruption)
	    {
		    [player setUpAudio];
		    [player start];
	    }
    }
    
The original C implementation passed that function as Argument 3 of the (now deprecated) `AudioSessionInitialize` function. Argument 4 was our `MHAudioBufferPlayer` instance itself. Things are simpler in the Objective-C version. Here are the two methods that replace this function:
    
    - (void)beginInterruption
    {
        [self tearDownAudio];
    }
    
    - (void)endInterruption
    {
        [self setUpAudio];
        [self start];
    }

####Update (deprecation removal)####

The above delegate methods have since been deprecated and removed entirely. Interruptions are now communicated via notification. First the method to handle the notification:

    - (void)audioSessionDidReceiveInterruption:(NSNotification *)notification
    {
        AVAudioSessionInterruptionType interruption =
            [[[notification userInfo] objectForKey:AVAudioSessionInterruptionTypeKey] integerValue];
        
        if (interruption == AVAudioSessionInterruptionTypeBegan) {
            [self tearDownAudio];
        }
        else if (interruption == AVAudioSessionInterruptionTypeEnded) {
            [self setUpAudio];
            [self start];
        }
    }

Register for the notification at the end of the `setUpAudioSession` method:

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(audioSessionDidReceiveInterruption:)
                                                 name:AVAudioSessionInterruptionNotification
                                               object:session];

And remove the observer at the start of the `tearDownAudioSession` method:

    [[NSNotificationCenter defaultCenter] removeObserver:self];

###Conclusion###
Build and run the application. It should all work as before. For further reading, see Apple's [*Audio Session Programming Guide.*](https://developer.apple.com/library/archive/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/Introduction/Introduction.html)

*Copyright © 2013, 2019 Mario Diana.*
