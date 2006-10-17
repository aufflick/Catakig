#import "Catakig-Cocoa.h"
#import "MyDocument.h"
#import "ScreenView.h"
#import "IndicatorLight.h"

@implementation MyDocument (Audio)
//---------------------------------------------------------------------------

enum
{
	kSampleRate			= 22050,
	kNumSpeeds			= 4,
	kSpeedMask			= kNumSpeeds - 1,
	kBytesPerChannel	= 1,
	kUnsigned			= YES,
	kFormatFlags		= 0,

#if 0
	kFormatFlags2		= kAudioFormatFlagIsSignedInteger
	#if __BIG_ENDIAN__
						| kAudioFormatFlagIsBigEndian
	#endif
						| kAudioFormatFlagIsNonInterleaved
						| kAudioFormatFlagIsPacked,
#endif
};

//---------------------------------------------------------------------------
#if 0
static OSStatus InputProc0(
	ScreenView*					screen,
	AudioUnitRenderActionFlags*	ioActionFlags,
	const AudioTimeStamp*		timeStamp,
	UInt32						busNumber,
	UInt32						nFrames,
	AudioBufferList*			ioData)
{
	*ioActionFlags |= kAudioUnitRenderAction_OutputIsSilence;
	memset(ioData->mBuffers[0].mData, 0x80, nFrames);
	return noErr;
}
#endif
//---------------------------------------------------------------------------

static OSStatus InputProc12(
	ScreenView*					screen,
	AudioUnitRenderActionFlags*	ioActionFlags,
	const AudioTimeStamp*		timeStamp,
	UInt32						busNumber,
	UInt32						nFrames,
	AudioBufferList*			ioData)
{/*
	Called during normal-speed and double-speed emulation.
*/
	uint8_t*		data = ioData->mBuffers[0].mData;
#if 0
	static BOOL		printed;

	if (not printed)
	{
		printed = YES;
		NSLog(@"%d %d %ld %ld",
			ioData->mNumberBuffers,
			ioData->mBuffers[0].mNumberChannels,
			ioData->mBuffers[0].mDataByteSize,
			numberFrames);
	}
#endif

	screen->mRunForOneStep(screen->mA2, nil, data);

#if 0
	if (nFrames == 368)
	{
		for (int i = 91;  --i >= 0;)
		{
			(data+276)[i] = (data+273)[i];
			(data+184)[i] = (data+182)[i];
			(data+ 92)[i] = (data+ 91)[i];
			data[183] = data[182];
			data[275] = data[274];
			data[367] = data[366];
		}
	}
#endif

	return noErr;
}

//---------------------------------------------------------------------------

static OSStatus InputProc3(
	ScreenView*					screen,
	AudioUnitRenderActionFlags*	ioActionFlags,
	const AudioTimeStamp*		timeStamp,
	UInt32						busNumber,
	UInt32						nFrames,
	AudioBufferList*			ioData)
{/*
	Called during 6x speed emulation.  The playback rate is double the
	norm, and we call the Apple II emulator 3 times in this callback.
*/
	A2Computer*		a2   = screen->mA2;
	uint8_t*		data = ioData->mBuffers[0].mData;

	screen->mRunForOneStep(a2, nil, data);
	screen->mRunForOneStep(a2, nil, data);
	screen->mRunForOneStep(a2, nil, data);

	return noErr;
}

//---------------------------------------------------------------------------

static struct
{
	void*		inputProc;
	UInt32		sampleRate,
				bufFrameSize;
}
	gSpeedInfo[kNumSpeeds] =
{
	{0},
	{InputProc12,	kSampleRate,	kA2SamplesPerStep*2},
	{InputProc12,	kSampleRate*2,	kA2SamplesPerStep},
	{InputProc3,	kSampleRate*2,	kA2SamplesPerStep},
};

//---------------------------------------------------------------------------

- (OSStatus)_PrepareAudioUnit:(int)speed
{
	AURenderCallbackStruct  input =
	{
		.inputProcRefCon	= mScreen,
		.inputProc			= (AURenderCallback)
								(gSpeedInfo[speed].inputProc),
	};
	AudioStreamBasicDescription  format =
	{
		.mSampleRate		= gSpeedInfo[speed].sampleRate,
		.mFormatID			= kAudioFormatLinearPCM,
		.mFormatFlags		= kFormatFlags,
		.mFramesPerPacket	= 1, // must be 1 for uncompressed data
		.mChannelsPerFrame	= 1, // or 2 for stereo??
		.mBitsPerChannel	= kBytesPerChannel * 8,
		.mBytesPerFrame		= kBytesPerChannel,
		.mBytesPerPacket	= kBytesPerChannel,
	};
	OSStatus		sts;

	sts = AU_SetBufferFrameSize(G.audioUnit,
		gSpeedInfo[speed].bufFrameSize);
	if (sts != noErr)
		return sts;

	sts = AudioUnitSetProperty(G.audioUnit,
		kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input,
		0, &format, sizeof(format));
	if (sts != noErr)
		return sts;

	sts = AudioUnitSetProperty(G.audioUnit, 
		kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input,
		0, &input, sizeof(input));
	if (sts != noErr)
		return sts;

// kAudioUnitProperty_MaximumFramesPerSlice (UInt32)
// kAudioUnitProperty_SetExternalBuffer (AudioUnitExternalBuffer)

	return noErr;
}

//---------------------------------------------------------------------------

- (void)_SetRunState:(int)newState
{/*
	Sets the run-state of this document to a new value.  The run state is
	an integer: a combination of the user-selected emulation speed (lower
	2 bits) and the pause level (remaining upper bits).  Emulation occurs
	only when the run-state value is greater than zero.
*/
	int			speed = newState & kSpeedMask;
	OSStatus	sts;

	[mSpeedLight setIntValue:speed];
	sts = AudioOutputUnitStop(G.audioUnit);

	if ((mRunState = newState) > 0)
	{
		sts = [self _PrepareAudioUnit:speed];
		sts = AudioOutputUnitStart(G.audioUnit);
	}
}

//---------------------------------------------------------------------------

- (void)awakeFromNib
{
	NSWindow*	mainWindow = [mScreen window];

//	NSLog(@"doc window key? %c", "ny"[[mainWindow isKeyWindow]]); //!!

	[mModelEmblem setStringValue:[mA2 ModelName]];
	[self setHasUndoManager:NO];
	[self _SetRunState:(1 - kNumSpeeds)];

	[mScreen setNextResponder:mA2];
	[mA2 setNextResponder:mainWindow];

	[mainWindow useOptimizedDrawing:YES];
//	[mainWindow setBackgroundColor:[NSColor blackColor]];
//	[mainWindow setAcceptsMouseMovedEvents:YES];
//	[mainWindow setResizeIncrements:NSMakeSize(0, 100)];
}

//---------------------------------------------------------------------------

- (IBAction)HitSpeedControl:(id)sender
{/*
	Responds to the user invoking one of the speed control commands.
*/
	[self _SetRunState:( mRunState & ~kSpeedMask | [sender tag] )];
}

//---------------------------------------------------------------------------

- (void)windowDidResignKey:(NSNotification*)note
{
	G.activeScreen = nil;
	[self Pause];
	[ScreenView FullScreenOff];
}

//---------------------------------------------------------------------------

- (void)windowDidBecomeKey:(NSNotification*)note
{
	[self Unpause];
	G.activeScreen = mScreen;
}

//---------------------------------------------------------------------------

- (void)windowWillMiniaturize:(NSNotification*)note
{/*
	Called when this window is about to be miniturized and put in the Dock.
	Here we make sure that the window's dock image looks like its content.
	We must do this ourselves because NSOpenGLViews don't co-operate with
	Quartz.

	Calling '-setOpaque' is required to make the Quartz underlay and the
	window shadow appear correctly.  We restore the opaque-ness property
	to YES in '-windowDidMiniaturize'.
*/
	NSWindow*	window = [note object];

	[self Pause];
	[mScreen PrepareToMiniaturize];
	[window setOpaque:NO];
}

//---------------------------------------------------------------------------

- (void)Pause
	{ [self _SetRunState:(mRunState - kNumSpeeds)]; }

- (void)Unpause
	{ if (mRunState < 0)  [self _SetRunState:(mRunState + kNumSpeeds)]; }

- (BOOL)IsRunning
	{ return mRunState > 0; }

- (void)windowWillBeginSheet:(NSNotification*)note
	{ [self Pause]; }

- (void)windowDidEndSheet:(NSNotification*)note
	{ [self Unpause]; }

- (void)windowWillClose:(NSNotification*)note
	{ [self windowDidResignKey:note]; }

- (void)windowDidMiniaturize:(NSNotification*)note
	{ [[note object] setOpaque:YES];  [self Unpause]; }
	 // see '-windowWillMiniaturize'

- (BOOL)keepBackupFile
	{ return G.prefs.keepBackupFiles; }

//---------------------------------------------------------------------------
@end
