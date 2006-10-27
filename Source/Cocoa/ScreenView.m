/*	class ScreenView

	The big view taking up most of an Apple II window, which displays the
	computer's live video.  Subclass of NSOpenGLView.
*/
#import "Catakig-Cocoa.h"
#import "MyDocument.h"
#import "ScreenView.h"
#import "IndicatorLight.h"

@implementation ScreenView
//---------------------------------------------------------------------------

enum
{
	kCaptureAllScreens		= NO,
//	kUseShieldWindow		= NO,
	kUseOwnGState			= YES,
	kUseSetSystemUIMode		= NO,
	kLockPixels				= YES,

	kTexWidth			= 1024,				// width and ...
	kTexHeight			=  256,				//   height of shared GL texture
	kPixelFormat		= GL_COLOR_INDEX,
	kPixelType			= GL_UNSIGNED_BYTE,
//	kBestScreenDepth	= 16,

	kfFlash				= 1 << 6,
	kfMonochrome		= 1 << 7,
};

static struct
{
	ScreenView*				fullScreenScreen;
	NSOpenGLContext*		fullScreenContext;

	NSOpenGLPixelFormat*	sharedPixelFormat;
	NSOpenGLContext*		sharedContext;
	GLuint					displayListID;
	GLuint					textureID;
	uint8_t*				pixels; // [kTexHeight][kTexWidth]
} g;

//---------------------------------------------------------------------------

static GLuint MakeDisplayList(void)
{
	GLuint	listID	= glGenLists(1);

	if (listID < 1) // then failed to allocate
		return 0;

	const GLfloat	cw =  kA2ScreenWidth     / (double)kTexWidth,
					ch = (kA2ScreenHeight/2) / (double)kTexHeight;

	glNewList(listID, GL_COMPILE);
	glBegin(GL_QUADS);

	glTexCoord2f(0,   0);	glVertex2i(0, 0);
	glTexCoord2f(0,  ch);	glVertex2i(0, kA2ScreenHeight);
	glTexCoord2f(cw, ch);	glVertex2i(kA2ScreenWidth, kA2ScreenHeight);
	glTexCoord2f(cw,  0);	glVertex2i(kA2ScreenWidth, 0);

	glEnd();
	glEndList();
	return listID;
}

//---------------------------------------------------------------------------

static GLuint MakeTextureObject(void)
{
	GLuint	textureID = 0;

	glGenTextures(1, &textureID);
	glBindTexture(GL_TEXTURE_2D, textureID);

	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_PRIORITY, 0.); // 0 or 1??
//	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
//	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_STORAGE_HINT_APPLE,
		GL_STORAGE_SHARED_APPLE); // extension!!

	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, kTexWidth, kTexHeight, 0,
		kPixelFormat, kPixelType, g.pixels);

	return textureID;
}

//---------------------------------------------------------------------------

static void BlessThisContext(NSOpenGLContext* context) //!!
{/*
	Sets up an OpenGLContext the way we like it.  Also makes the context
	the current one, leaving it that way on return.
*/
	[context makeCurrentContext];
	[context SetSwapInterval:1L];

	glDisable(GL_DITHER);
	glDisable(GL_BLEND);
	glDisable(GL_FOG);
	glDisable(GL_LIGHTING);
	glDisable(GL_ALPHA_TEST);
	glDisable(GL_STENCIL_TEST);
	glDisable(GL_DEPTH_TEST);

	glEnable(GL_TEXTURE_2D);
//	glEnableClientState(GL_VERTEX_ARRAY);
//	glEnableClientState(GL_TEXTURE_COORD_ARRAY);

	glShadeModel(GL_FLAT);
	glDepthMask(NO); // helpful??
	glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);

	glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_FASTEST); // need??
	glHint(GL_CLIP_VOLUME_CLIPPING_HINT_EXT, GL_FASTEST); // extension!!

	glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, YES); // extension!!
	glPixelStorei(GL_UNPACK_ALIGNMENT, 8); // helpful??
	glPixelStorei(GL_UNPACK_ROW_LENGTH, kTexWidth);
	glPixelTransferi(GL_MAP_COLOR, GL_TRUE);

	if (g.displayListID == 0)
		g.displayListID = MakeDisplayList();
	if (g.textureID == 0)
		g.textureID = MakeTextureObject();

	glBindTexture(GL_TEXTURE_2D, g.textureID);
	GL_PreparePalette();
}

//---------------------------------------------------------------------------

static NSOpenGLContext* MakeFullScreenContext(CGDirectDisplayID dpy)
{/*
	Assumes full-screen mode is already active.
*/
	NSOpenGLPixelFormatAttribute	pixFmtAttrs[] =
	{
		NSOpenGLPFAFullScreen,
		NSOpenGLPFAScreenMask, CGDisplayIDToOpenGLDisplayMask(dpy),
		NSOpenGLPFASingleRenderer,
		NSOpenGLPFAAccelerated,
		NSOpenGLPFANoRecovery,
		NSOpenGLPFADoubleBuffer,

	//	NSOpenGLPFAColorSize,		16,
		NSOpenGLPFAAlphaSize,		0,
		NSOpenGLPFADepthSize,		0,
		NSOpenGLPFAStencilSize,		0,
		NSOpenGLPFAAccumSize,		0,
		0 };
	NSOpenGLPixelFormat*	pixFmt;
	NSOpenGLContext*		context = nil;

	[(pixFmt = [[NSOpenGLPixelFormat alloc]
		initWithAttributes:pixFmtAttrs]) autorelease];
	context = [[NSOpenGLContext alloc]
		initWithFormat:pixFmt shareContext:nil];
	[context setFullScreen];

	BlessThisContext(context);
	MakeDisplayList();
	glBindTexture(GL_TEXTURE_2D, MakeTextureObject());
	GL_ClearBothBuffers();
	GL_PrepareViewport(CGDisplayPixelsWide(dpy), CGDisplayPixelsHigh(dpy));

	return context;
}

//---------------------------------------------------------------------------

+ (void)initialize
{
	NSOpenGLPixelFormatAttribute  pixFmtAttrs[] =
	{
		NSOpenGLPFAWindow,
		NSOpenGLPFAAccelerated,
		NSOpenGLPFANoRecovery,
		NSOpenGLPFADoubleBuffer,
	//	NSOpenGLPFABackingStore,
	//	NSOpenGLPFAPixelBuffer,

		NSOpenGLPFAColorSize,		16,
		NSOpenGLPFAAlphaSize,		0,
		NSOpenGLPFADepthSize,		0,
		NSOpenGLPFAStencilSize,		0,
		NSOpenGLPFAAccumSize,		0,
		0 };

	g.pixels = NSAllocateMemoryPages(kTexWidth * kTexHeight);
	if (g.pixels != nil)
	{
		madvise(g.pixels, kTexWidth * kTexHeight, MADV_SEQUENTIAL);
		if (kLockPixels)
			mlock(g.pixels, kTexWidth * kTexHeight);
	}

	g.sharedPixelFormat = [[NSOpenGLPixelFormat alloc]
		initWithAttributes:pixFmtAttrs];
	g.sharedContext = [[NSOpenGLContext alloc]
		initWithFormat:g.sharedPixelFormat shareContext:nil];
	BlessThisContext(g.sharedContext);

//	NSLog(@"GL version = '%s'", glGetString(GL_VERSION));//!!
}

//---------------------------------------------------------------------------

- (id)initWithFrame:(NSRect)frame
{
//	NSLog(@"SV -initWithFrame called"); //!!

	self = [super initWithFrame:frame pixelFormat:g.sharedPixelFormat];
	if (self == nil)
		return nil;

	if (kUseOwnGState)
		[self allocateGState]; // helpful??

	mRenderScreen = (void*) [A2Computer instanceMethodForSelector:
		@selector(RenderScreen::) ];
	mRunForOneStep = (void*) [A2Computer instanceMethodForSelector:
		@selector(RunForOneStep:) ];

//	Need to release this view's previous GLContext??
	[self setOpenGLContext:[[NSOpenGLContext alloc]
		initWithFormat: g.sharedPixelFormat
		shareContext:   g.sharedContext ]];
	BlessThisContext([self openGLContext]);

	return self;
}

//---------------------------------------------------------------------------

- (void)dealloc
{
	if (kUseOwnGState)
		[self releaseGState]; // need this??
	[super dealloc];
}

//---------------------------------------------------------------------------

- (void)prepareOpenGL
{/*
	"Used by subclasses to initialize OpenGL state."

	"This method is called only once after the OpenGL context is made the
	current context. Subclasses that implement this method can use it to
	configure the Open GL state in preparation for drawing."
*/
//	NSLog(@"SV -prepareOpenGL called"); //!!
}

//---------------------------------------------------------------------------

- (void)reshape
{/*
	"Called by Cocoa when the view's visible rectangle or bounds change."

	"Called if the visible rectangle or bounds of the receiver change
	(for scrolling or resize).  The default implementation does nothing.
	Override this method if you need to adjust the viewport and display
	frustum."
*/
	NSSize	vsize = NSIntegralRect([self bounds]).size;

	GL_PrepareViewport(vsize.width, vsize.height);
	GL_ClearBothBuffers();

//	NSLog(@"SV -reshape called"); //!!
}

//---------------------------------------------------------------------------

- (void)drawRect:(NSRect)r
{
	NSOpenGLContext*	context;

	if (g.fullScreenScreen == self)
		[(context = g.fullScreenContext) makeCurrentContext];
	else
		context = [self openGLContext];

	mRenderScreen(mA2, nil, g.pixels, kTexWidth);
	glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, kA2ScreenWidth, 192,
		kPixelFormat, kPixelType, g.pixels);
	glCallList(g.displayListID);
	[context flushBuffer];

//	if (g.fullScreenScreen == self)
//		[self MakeCurrentContext]; // need to restore previous context??
}

//---------------------------------------------------------------------------

- (IBAction)ToggleColorVideo:(id)sender
{/*
	Toggles this Apple II's video style between monochrome and color.
*/
	mVideoStyle ^= kfMonochrome;
	[self setNeedsDisplay:YES];
}

//---------------------------------------------------------------------------

- (IBAction)ToggleFullScreen:(id)sender
{/*
	Toggles this Apple II between full-screen mode and windowed mode.
*/
	static CGDirectDisplayID	dpy;
	static CFDictionaryRef		prevMode;

	[mDocument Pause];

	if (g.fullScreenScreen == nil) // then take over user's screen
	{
		dpy      = CGMainDisplayID(); // always main display??
		prevMode = CGDisplayCurrentMode(dpy);

		[NSCursor hide];
		[NSMenu setMenuBarVisible:NO];

		if (kCaptureAllScreens)
			CGCaptureAllDisplays();
		else
			CGDisplayCapture(dpy);

		CGDisplaySwitchToMode(dpy,
			CGDisplayBestModeForParameters(dpy, 16, 640, 480, nil) );
		if (kUseSetSystemUIMode)
			SetSystemUIMode(kUIModeAllHidden, 0); // disables cmd-tab, etc.

		g.fullScreenContext = MakeFullScreenContext(dpy);
		g.fullScreenScreen = self;
	}
	else // relinquish screen and restore desktop
	{
		[self MakeCurrentContext];
		GL_ClearBothBuffers(); // erase old content

		g.fullScreenScreen = nil;
		g.fullScreenContext = [g.fullScreenContext Release];

		if (kUseSetSystemUIMode)
			SetSystemUIMode(kUIModeNormal, 0);
		CGDisplaySwitchToMode(dpy, prevMode);
		CGReleaseAllDisplays();

		[NSMenu setMenuBarVisible:YES];
		[NSCursor unhide];
	}

	SetMouseRange();
	[self setNeedsDisplay:YES];
	[mDocument Unpause];
}

//---------------------------------------------------------------------------

- (void)Flash
{/*
	Should be called a few times per second (say 3 or 4) to implement
	flashing, and to update the indicator lights.
*/
	unsigned	lchg = mPrevLights ^ [mA2 Lights];

	if (lchg != 0)
	{
		mPrevLights ^= lchg;

		if (lchg & kfA2LightPrinter)	[mPrinterLight ToggleState];
		if (lchg & kfA2LightDDrive0)	[mDDLight0 ToggleState];
		if (lchg & kfA2LightDDrive1)	[mDDLight1 ToggleState];
	}

	if (g.fullScreenContext)
		[g.fullScreenContext makeCurrentContext];
	else
		[self MakeCurrentContext];

	glPixelTransferi(GL_INDEX_OFFSET, (mVideoStyle ^= kfFlash));
	[self setNeedsDisplay:YES];

#if 0
	if ([mDocument IsRunning])
		[[self window] setDocumentEdited:YES];
#endif
}

//---------------------------------------------------------------------------

- (void)keyDown:(NSEvent*)event
{
//	if (not [mDocument IsRunning]) // then ignore keypresses
//		return;

//	NSString*	chstr = [event charactersIgnoringModifiers];
	NSString*	chstr = [event characters];

	if (chstr == nil  or  [chstr length] < 1)
		return;

	unsigned	mods = [event modifierFlags],
				ch   = [chstr characterAtIndex:0];
	BOOL		keyInNumPad = ((mods & NSNumericPadKeyMask) != 0);

//	NSLog(@"char %04X, mods %08X", ch, mods); //!!

	switch (ch)
	{
	  case NSLeftArrowFunctionKey:  ch =  8;  break;
	  case NSRightArrowFunctionKey: ch = 21;  break;
	  case NSDownArrowFunctionKey:  ch = 10;  break;
	  case NSUpArrowFunctionKey:    ch = 11;  break;
	  case NSClearLineFunctionKey:  ch = 27;  break;

	  case 3:	if (keyInNumPad) // then it's 'enter', not ctrl-C
					ch = 13;
				break;

	  case '7': case '8': case '9':
	  case '4': case '5': case '6':
	  case '1': case '2': case '3':
		if (keyInNumPad  and  G.prefs.joystickControl == kJoyKeypad)
		{
			[A2Computer InputPaddlesByKeypad:ch];
			return;
		}
		break;
	}

	[mA2 InputChar:ch];
}

//---------------------------------------------------------------------------

- (BOOL)performKeyEquivalent:(NSEvent*)event
{/*
	"Returns YES if theEvent is a key equivalent that the receiver handled,
	NO if it is not a key equivalent that it should handle."

	"If the receiver’s key equivalent is the same as the characters of the
	key-down event theEvent, as returned by charactersIgnoringModifiers,
	the receiver should take the appropriate action and return YES.
	Otherwise, it should return the result of invoking super’s
	implementation.  The default implementation of this method simply passes
	the message down the view hierarchy (from superviews to subviews) and
	returns NO if none of the receiver’s subviews responds YES."
*/
	if (g.fullScreenScreen != nil  and
		([event modifierFlags] & NSCommandKeyMask) )
		return YES;

	return [super performKeyEquivalent:event];
}

//---------------------------------------------------------------------------

//- (BOOL)isFlipped { return YES; }

+ (void)FullScreenOff
	{ [g.fullScreenScreen ToggleFullScreen:self]; }

+ (void)AllNeedDisplay
	{ [MyDocument AllNeedDisplay]; }

- (BOOL)acceptsFirstResponder
	{ return YES; } // yes, we want those keypresses

- (BOOL)isOpaque
	{ return YES; } // eliminates unsightly flickering

- (BOOL)wantsDefaultClipping
	{ return NO; } // bypasses clip-rect preparation

//---------------------------------------------------------------------------
@end
