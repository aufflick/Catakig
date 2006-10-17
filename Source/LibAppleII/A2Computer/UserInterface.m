/*	class A2Computer (category UserInterface)

	Methods having to do with user interaction: keypresses, the
	joystick/paddle values and button states, states of the indicator
	lights, etc.
*/
#import "LibAppleII-Priv.h"
#import "A2DiskDrive.h"

@implementation A2Computer (UserInterface)
//---------------------------------------------------------------------------

static NSRect	gMouseRange;

static NSString* gNameOfModel[] =
{
	@"??", // code 0 is invalid

	@"][", @"][+", @"//e", @"//c", @"//c+",
};

//---------------------------------------------------------------------------

- (IBAction)SignalReset:(id)sender
{/*
	Informs this Apple II that the user invoked RESET.  The Apple II will
	respond to it at a later time.
*/
	mHalts |= kfHaltReset;
}

//---------------------------------------------------------------------------

- (IBAction)SignalReboot:(id)sender
{/*
	Informs this Apple II that the user invoked a reboot (a "cold reset").
	The Apple II will respond to it at a later time.
*/
	mMemory->RAM[0][0][1012] = mMemory->RAM[0][0][1011] = 0;
		// sabotages the "power-up" byte

	mHalts |= kfHaltReset;
}

//---------------------------------------------------------------------------

- (BOOL)InputChar:(unichar)ch
{/*
	Informs this Apple II of a character typed on the keyboard.  Returns
	whether the character was successfully queued.  The character code
	must be plain ASCII (range 0-127), as that's all the Apple II ever
	supported.

	Also, this method turns on the "power" if it isn't already on.
*/
	if ( (uint8_t)(mKeyQ.tail - mKeyQ.head) > 250  or  ch > 127 )
		return NO;

	if (mModel < kA2ModelIIe)
		ch = toupper(ch);

	mKeyQ.buf[mKeyQ.tail++] = ch; // enqueue the character
	mKeyQ.hitRecently = YES;
	mHalts &= ~kfHaltNoPower;
	return YES;
}

//---------------------------------------------------------------------------

- (void)InputChars:(NSString*)str
{/*
	Puts the given string of characters into the Apple II's keyboard
	queue, as if they had all been typed -- really really quickly.
*/
	int		len = [str length];

	if (len > 250)
		len = 250;
	mKeyQ.head = mKeyQ.tail = 0;
	[str getCString:(char*)(mKeyQ.buf) maxLength:len];
	mKeyQ.tail = len;
	mKeyQ.hitRecently = YES;
}

//---------------------------------------------------------------------------

+ (void)InputPaddlesByKeypad:(char)ch
{/*
	Sets the paddle values (and joystick position) according to a digit
	key on the numeric keypad.
*/
	div_t	d = div((ch - 1) & 15, 3);

	A2G.paddle[0] = (kA2PaddleRange/2) * d.rem;
	A2G.paddle[1] = (kA2PaddleRange/2) * (2 - d.quot);
}

//---------------------------------------------------------------------------

+ (void)InputPaddlesByMouse
{/*
	Sets the paddle values (also joystick position) by the current
	coordinates of the host machine's mouse.  Only paddles #0 and #1 are
	affected.
*/
	NSPoint		mloc = [NSEvent mouseLocation];
	int			p0, p1;

	p0 = (mloc.x - gMouseRange.origin.x) * gMouseRange.size.width;
	p1 = kA2PaddleRange -
	     (mloc.y - gMouseRange.origin.y) * gMouseRange.size.height;

	if (p0 < 0)
		p0 = 0;
	A2G.paddle[0] = p0;

	if (p1 < 0)
		p1 = 0;
	A2G.paddle[1] = p1;
}

//---------------------------------------------------------------------------

+ (void)SetMouseRangeTo:(NSRect)r
{/*
	Informs the library of the extent rectangle over which the mouse's
	coordinates may roam.  Affects the future behavior of
	+InputPaddlesByMouse.
*/
	gMouseRange.origin		= r.origin;
	gMouseRange.size.width	= kA2PaddleRange / r.size.width;
	gMouseRange.size.height	= kA2PaddleRange / r.size.height;
}

//---------------------------------------------------------------------------

- (void)_RespondToReset
{
#if 0
	strcpy(((char*)mMemory->RAM[0][0]) + 0x309, //!!
		"\xA9\xA\x20\xA8\xFC\xAD\x30\xC0\x4C\x09\3");
#endif

	mFlags = kfTEXT | kfLCWRThi | kfLCBANK2 | kfC3ROM;
	if (mModel < kA2ModelIIc)
		mFlags |= 3UL << ksHotSlot;
	memset(mVideoFlags, mFlags, sizeof(mVideoFlags));

	mKeyQ.tail = mKeyQ.head = 0;
	mPC = mMemory->ROM[0][0x3FFD] << 8 // load PC from $FFFC-D in ROM
		| mMemory->ROM[0][0x3FFC];

//	mPrinter.reg[0x8] = ??;
	mPrinter.reg[0xA] = 0; // command reg
	mPrinter.reg[0xB] = 0x3E; // control reg
	mPrinter.lights = 0;

	mIWM[0].flags	= mIWM[1].flags		= 0;
	mIWM[0].lights	= mIWM[1].lights	= 0;
	mIWM[0].modeReg	= mIWM[1].modeReg	= 0; // Does mode-reg reset??

//	mSlinky.pos = 0; // Does this reset??
}

//---------------------------------------------------------------------------

- (unsigned)Lights
{/*
	Returns the status of the Apple II's indicator lights as a bit vector.
	Should be called about 3 to 4 times per second from the client
	application.
*/
	if (mHalts & kfHaltReset) // then RESET was raised earlier
	{
		[self _RespondToReset];
		mHalts &= ~kfHaltReset;
		return 0;
	}

	unsigned	lights = 0;

	for (int i = 2;  --i >= 0;)
	{
		A2IWM*		iwm = mIWM + i;
		unsigned	lt = iwm->lights;

		if (lt >= 16)
			iwm->lights -= 16,  lights |= (lt&3) << (2*i);
	}

	if (mPrinter.lights >= 16)
		mPrinter.lights -= 16,  lights |= kfA2LightPrinter;

	if (not mKeyQ.hitRecently  and  mKeyQ.tail != mKeyQ.head)
		mKeyQ.head++;
	mKeyQ.hitRecently = NO;

	return lights;
}

//---------------------------------------------------------------------------

static inline uint8_t ASCIIfy(int charset, uint8_t ch)
{/*
	Returns the ASCII equivalent of an Apple II character screen code
	(0-255), or a space character if there is no such thing.
*/
	static uint8_t	flip[3][8] =
	{
		0x40,0x00,0x00,0x40, 0xC0,0x80,0x80,0x80, // IIe std charset
		0x40,0x00,0x40,0x00, 0xC0,0x80,0x80,0x80, // IIe alt (MouseText)
		0x40,0x00,0x00,0x40, 0xC0,0x80,0x80,0xA0, // IIo and IIp
	};

	ch ^= flip[charset][ch >> 5];
	return (ch < 32  or  ch > 126)? 32 : ch;
}

//---------------------------------------------------------------------------

- (NSString*)TextScreenAsString:(BOOL)newLines
{/*
	Returns the content of the Apple II's text screen as a giant string of
	characters.  Optionally puts newline characters at the end of each
	screen line.  Returns nil if no text is visible.
*/
	unsigned	f = mFlags;

	if ((f & (kfTEXT | kfMIXED)) == 0) // then in full-graphics mode
		return nil;


	char		cstr[24*81 + 1], *pout = cstr;
	uint8_t*	dispPage = mMemory->RAM[0][0] + 0x400;
	int			charset; // 0-2

	charset = (mModel < kA2ModelIIe)? 2 : (f >> ksALTCHAR & 1);
	if ((f & (kf80STOREv | kfPAGE2v)) == kfPAGE2v)
		dispPage += 0x400;

	for (int v = (f & kfTEXT)? 0 : 20;  v < 24;  ++v)
	{
		uint8_t		*pin = dispPage + 128*(v&7) + 5*(v&~7);

		for (int h = 0;  h < 40;  ++h)
		{
			if (f & kf80COL)
				*pout++ = ASCIIfy(charset, pin[0x2000+h]);
			*pout++ = ASCIIfy(charset, pin[h]);
		}
		if (newLines)
			*pout++ = '\n';
	}

	return [NSString stringWithCString:cstr length:(pout-cstr)];
}

//---------------------------------------------------------------------------

+ (void)_UpdateClock:(NSTimer*)timer
{
	static struct
	{
		char	hi[100], lo[100];
	}
		digit =
	{
		"00000000001111111111222222222233333333334444444444"
		"55555555556666666666777777777788888888889999999999",
		"01234567890123456789012345678901234567890123456789"
		"01234567890123456789012345678901234567890123456789"
	};

	static time_t	tPrev; // = 0
	time_t			t;
	struct tm		tm;

	if (tPrev == time(&t))
		return;

//	NSLog(@"Clock time being updated.");

	tPrev = t;
	A2G.timeInGMT? gmtime_r(&t, &tm) : localtime_r(&t, &tm);
	tm.tm_year %= 100;
	tm.tm_mon += 1;

	uint8_t str[32] =
	{
		tm.tm_mon << 5 | tm.tm_mday,
		tm.tm_year << 1 | tm.tm_mon >> 3,
		tm.tm_min, tm.tm_hour,

		digit.hi[tm.tm_mon ], digit.lo[tm.tm_mon ], ',',
		'0', digit.lo[tm.tm_wday], ',',
		digit.hi[tm.tm_mday], digit.lo[tm.tm_mday], ',',
		digit.hi[tm.tm_hour], digit.lo[tm.tm_hour], ',',
		digit.hi[tm.tm_min ], digit.lo[tm.tm_min ], ',',
		digit.hi[tm.tm_sec ], digit.lo[tm.tm_sec ], 13,
	};

	for (int i = 32/4;  --i >= 0;)
		((uint32_t*)(A2T.curTime))[i] = ((uint32_t*)str)[i];
}

//---------------------------------------------------------------------------

- (id<A2PrDiskDrive>)DiskDrive:(unsigned)index
{/*
	Returns the disk drive object identified by the given index (0-3).
*/
	return (index > 3)? nil :
		mIWM[index >> 1].drive[index & 1];
}

//---------------------------------------------------------------------------

- (NSString*)ModelName
	{ return gNameOfModel[mModel]; }
	// Returns a short name for this Apple II's model.

- (unsigned)ModelCode
	{ return mModel; }
	// Returns the numeric code for this Apple II's model.

- (BOOL)acceptsFirstResponder
	{ return YES; }
	
+ (BOOL)ShouldShowDiskFilename:(NSString*)path
	{ return [A2DiskDrive ShouldShowFilename:path]; }

//---------------------------------------------------------------------------
@end
