
#import "MHAudioBufferPlayer.h"

//
// "Audio Session Cookbook" from the Audio Session Programming Guide
//
// https://developer.apple.com/library/ios/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/Cookbook/Cookbook.html
//
// We replace the C implementation methods that were deprecated in iOS 7,
// replacing them with the newer, Objective-C implementation.
//
// 2013.10.16 - Mario Diana <software@mariodiana.com>
//

// The number of Audio Queue buffers we keep in rotation
#define NumberOfAudioDataBuffers 3

@interface MHAudioBufferPlayer ()

@property (nonatomic, assign, readwrite) BOOL playing;

- (void)setUpAudio;
- (void)tearDownAudio;
- (void)start;

@end


static void PlayCallback(void *inUserData, AudioQueueRef inAudioQueue, AudioQueueBufferRef inBuffer)
{
	MHAudioBufferPlayer *player = (__bridge MHAudioBufferPlayer *)inUserData;
	if (player.playing && player.block != nil)
	{
		player.block(inBuffer, player.audioFormat);
		AudioQueueEnqueueBuffer(inAudioQueue, inBuffer, 0, NULL);
	}
}

@implementation MHAudioBufferPlayer
{
	// the audio queue object being used for playback
	AudioQueueRef _playQueue;
	
	// the audio queue buffers for the playback audio queue
	AudioQueueBufferRef _playQueueBuffers[NumberOfAudioDataBuffers];

	// the number of audio data packets to use in each audio queue buffer
	UInt32 _packetsPerBuffer;

	// the number of bytes to use in each audio queue buffer
	UInt32 _bytesPerBuffer;
}

- (id)initWithSampleRate:(Float64)sampleRate
                channels:(UInt32)channels
          bitsPerChannel:(UInt32)bitsPerChannel
        secondsPerBuffer:(Float64)secondsPerBuffer
{
	return [self initWithSampleRate:sampleRate
                           channels:channels
                     bitsPerChannel:bitsPerChannel
                   packetsPerBuffer:(UInt32)(secondsPerBuffer * sampleRate)];
}

- (id)initWithSampleRate:(Float64)sampleRate
                channels:(UInt32)channels
          bitsPerChannel:(UInt32)bitsPerChannel
        packetsPerBuffer:(UInt32)packetsPerBuffer
{
	if ((self = [super init]))
	{
		_playing = NO;
		_playQueue = NULL;
		_gain = 1.0;

		_audioFormat.mFormatID         = kAudioFormatLinearPCM;
		_audioFormat.mSampleRate       = sampleRate;
		_audioFormat.mChannelsPerFrame = channels;
		_audioFormat.mBitsPerChannel   = bitsPerChannel;
		_audioFormat.mFramesPerPacket  = 1;  // uncompressed audio
		_audioFormat.mBytesPerFrame    = _audioFormat.mChannelsPerFrame * _audioFormat.mBitsPerChannel/8;
		_audioFormat.mBytesPerPacket   = _audioFormat.mBytesPerFrame * _audioFormat.mFramesPerPacket;
		_audioFormat.mFormatFlags      = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;

		_packetsPerBuffer = packetsPerBuffer;
		_bytesPerBuffer = _packetsPerBuffer * _audioFormat.mBytesPerPacket;

		[self setUpAudio];
	}
	return self;
}

- (void)dealloc
{
	[self tearDownAudio];
}

- (void)setUpAudio
{
	if (_playQueue == NULL)
	{
		[self setUpAudioSession];
		[self setUpPlayQueue];
		[self setUpPlayQueueBuffers];
	}
}

- (void)tearDownAudio
{
	if (_playQueue != NULL)
	{
		[self stop];
		[self tearDownPlayQueue];
		[self tearDownAudioSession];
	}
}

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
        NSLog(@"%@ Error activating %@",
              NSStringFromSelector(_cmd), [error localizedDescription]);
    }
    
    return success;
}

- (BOOL)tearDownAudioSession
{
    NSError *deactivationError = nil;
    BOOL success = [[AVAudioSession sharedInstance] setActive:NO error:&deactivationError];
    if (!success) {
        NSLog(@"%@ Error deactivating %@",
              NSStringFromSelector(_cmd), [deactivationError localizedDescription]);
    }
    return success;
}

- (void)setUpPlayQueue
{
	AudioQueueNewOutput(
		&_audioFormat,
		PlayCallback,
		(__bridge void *)self, 
		NULL,                   // run loop
		kCFRunLoopCommonModes,  // run loop mode
		0,                      // flags
		&_playQueue);

	self.gain = 1.0;
}

- (void)tearDownPlayQueue
{
	AudioQueueDispose(_playQueue, YES);
	_playQueue = NULL;
}

- (void)setUpPlayQueueBuffers
{
	for (int t = 0; t < NumberOfAudioDataBuffers; ++t)
	{
		AudioQueueAllocateBuffer(
			_playQueue,
			_bytesPerBuffer,
			&_playQueueBuffers[t]);
	}
}

- (void)primePlayQueueBuffers
{
	for (int t = 0; t < NumberOfAudioDataBuffers; ++t)
	{
		PlayCallback((__bridge void *)self, _playQueue, _playQueueBuffers[t]);
	}
}

- (void)start
{
	if (!self.playing)
	{
		self.playing = YES;
		[self primePlayQueueBuffers];
		AudioQueueStart(_playQueue, NULL);
	}
}

- (void)stop
{
	if (self.playing)
	{
		AudioQueueStop(_playQueue, TRUE);
		self.playing = NO;
	}
}

- (void)setGain:(Float32)gain
{
	if (_gain != gain)
	{
		_gain = gain;
		AudioQueueSetParameter(_playQueue, kAudioQueueParam_Volume, _gain);
	}
}

#pragma mark -
#pragma mark AVAdudioSessionDelegate methods

- (void)beginInterruption
{
    [self tearDownAudio];
}

- (void)endInterruption
{
    [self setUpAudio];
    [self start];
}

@end
