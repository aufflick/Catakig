/*	main.m

	The application's global functions, including 'main'.
*/
#import "Catakig-Cocoa.h"

struct CatakigGlobals	G; // application-wide global variables

//---------------------------------------------------------------------------

int main(int argc, const char* argv[])
{
	return NSApplicationMain(argc, argv);
}

//---------------------------------------------------------------------------

void BeepFor(BOOL success)
{/*
	Optionally plays a sound, depending on user's preferences, to
	indicate success or failure.
*/
	if (G.prefs.beepsOn)
		[[NSSound soundNamed:(success? @"Glass" : @"Sosumi")] play];
}

//---------------------------------------------------------------------------

void ErrorAlert(NSWindow* window, NSString* title, NSString* msg)
{
	NSString*   defaultButton = @"Okay"; //??

	BeepFor(NO);

#if 0
	if (errno != 0)
		msg = [msg stringByAppendingString:
			[NSString stringWithFormat:@"\n\n(%d) %s",
				errno, strerror(errno)]];
#endif

	if (window != nil)
		NSBeginCriticalAlertSheet(title, defaultButton, nil, nil,
			window, nil, nil, nil, nil, msg);
	else
		NSRunCriticalAlertPanel(title, msg, defaultButton, nil, nil);
}

//---------------------------------------------------------------------------

void FatalErrorAlert(NSString* title, NSString* msg)
{
	BeepFor(NO);
	NSRunCriticalAlertPanel(title, msg, nil, nil, nil);
	[NSApp terminate:nil];
}

//---------------------------------------------------------------------------

void SetMouseRange(void)
{
	CGDirectDisplayID	dpy = CGMainDisplayID();
	union {
		CGRect	cg;
		NSRect	ns;
	}			bounds;

	bounds.cg = CGDisplayBounds(dpy);

	if (NO)
		NSLog(@"main display bounds: (%f %f) (%f %f)",
			bounds.ns.origin.x, bounds.ns.origin.y,
			bounds.ns.size.width, bounds.ns.size.height);

	if (CGDisplayIsCaptured(dpy))
		bounds.ns.origin.y =
			[[NSScreen MenuBarScreen] frame].size.height -
			CGDisplayPixelsHigh(dpy);

	[A2Computer SetMouseRangeTo:bounds.ns];
}

//---------------------------------------------------------------------------

OSStatus AU_Open(AudioUnit* audioUnit)
{/*
	Allocates and initializes a new output AudioUnit.
*/
	OSStatus				sts;
	UInt32					n;
	Component				comp;
	ComponentDescription	compDesc =
	{
		.componentType			= kAudioUnitType_Output,          
		.componentSubType		= kAudioUnitSubType_DefaultOutput,
		.componentManufacturer	= kAudioUnitManufacturer_Apple,
		.componentFlags			= 0,
		.componentFlagsMask		= 0,
	};

	*audioUnit = 0;
	if (NULL == (comp = FindNextComponent(NULL, &compDesc)))
		return fnfErr;
	if (noErr != (sts = OpenAComponent(comp, audioUnit)))
		return sts;
#if 0
	sts = AudioUnitSetProperty(*audioUnit,
		kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global,
		0, (n=364, &n), sizeof(n));
#endif

	return AudioUnitInitialize(*audioUnit);
}

//---------------------------------------------------------------------------

OSStatus AU_SetBufferFrameSize(AudioUnit audioUnit, UInt32 frameSize)
{/*
	Sets the number of frames-per-buffer used by the given AudioUnit.
*/
	OSStatus		sts;
	UInt32			n;
	AudioDeviceID	device = 0;

	sts = AudioUnitGetProperty(audioUnit,
		kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global,
		0, &device, (n=sizeof(device), &n));
	if (sts != noErr)
		return sts;

	sts = AudioDeviceSetProperty(device, NULL, 0, NO,
		kAudioDevicePropertyBufferFrameSize,
		sizeof(frameSize), &frameSize);

#if 0
	AudioDeviceGetProperty(device, 0, NO,
		kAudioDevicePropertyBufferFrameSize,
		(n=sizeof(frameSize), &n), &frameSize);
	NSLog(@"Device frame size is now %ld", frameSize);

	Float64	rate;
	AudioDeviceGetProperty(device, 0, NO,
		kAudioDevicePropertyNominalSampleRate,
		(n=sizeof(rate), &n), &rate);
	NSLog(@"Device nominal sample rate is %.2f", rate);
#endif

	return sts;
}

//---------------------------------------------------------------------------

void AU_Close(AudioUnit* audioUnit)
{
	if (*audioUnit) // is open...
	{
		AudioOutputUnitStop(*audioUnit);
		AudioUnitUninitialize(*audioUnit);
		CloseComponent(*audioUnit);
	}
	*audioUnit = 0;
}

//---------------------------------------------------------------------------

BOOL GL_CheckExtension(const char* name)
{/*
	Tests whether a given OpenGL extension is supported.
*/
	return gluCheckExtension((const GLubyte*)name,
		glGetString(GL_EXTENSIONS));
}

//---------------------------------------------------------------------------

void GL_ClearBothBuffers(void)
{/*
	Clears both the front and back buffers of the current GL context.
*/
	NSOpenGLContext*  context = [NSOpenGLContext currentContext];

	glClear(GL_COLOR_BUFFER_BIT);  [context flushBuffer];
	glClear(GL_COLOR_BUFFER_BIT);  [context flushBuffer];
}

//---------------------------------------------------------------------------

void GL_PrepareViewport(int viewWidth, int viewHeight)
{/*
	Sets up a centered, orthogonal projection for the current GL context.
*/
	int		hMargin	= (viewWidth  - kA2ScreenWidth ) / 2,
			vMargin	= (viewHeight - kA2ScreenHeight) / 2;

	glViewport(0, 0, viewWidth, viewHeight);

	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glOrtho(-hMargin, viewWidth - hMargin,
			viewHeight - vMargin, -vMargin,
			0, 1);

	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
}

//---------------------------------------------------------------------------

void GL_PreparePalette(void)
{
	for (int rgb = 3;  --rgb >= 0;)
	{
		GLushort	pal[4][64];
		GLushort	mono;

		memset(pal, 0, sizeof(pal));
		mono = 0x0101 * (G.prefs.monochromeHue >> (8*(2-rgb)) & 0xFF);

		for (int i = 16;  --i >= 0;)
		{
			pal[0][0x00|i] = pal[0][0x10|i] =
			pal[0][0x20|i] = 0x1111 *
				(A2G.standardColors[i]>>(4*(2-rgb)) & 15);

			pal[2][0x10|i] = mono;
			pal[2][0x20|i] = mono * ("0113123413243445"[i] & 7L) / 5;
		}
		memcpy(pal[1], pal[0], sizeof(pal[0]));
		memcpy(pal[3], pal[2], sizeof(pal[2]));

		pal[0][0x33] = pal[1][0x32] =
		pal[0][0x31] = pal[1][0x31] = 0xFFFF;

		pal[2][0x33] = pal[3][0x32] =
		pal[2][0x31] = pal[3][0x31] = mono;

		glPixelMapusv(GL_PIXEL_MAP_I_TO_R + rgb, 256, pal[0]);
	}
}

//---------------------------------------------------------------------------
