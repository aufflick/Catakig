/*	LibAppleII.h

	The one and only public interface file for the LibAppleII library.
*/
#import <Foundation/Foundation.h>
//mport <AppKit/AppKit.h>
#import <stdint.h>
#import <stdio.h>

//---------------------------------------------------------------------------
//	Handy integer constants.

enum
{
	kA2ModelNone = 0,		// Apple II model codes:
	kA2ModelIIo,				// the original Apple ][
	kA2ModelIIp,				// the ][+
	kA2ModelIIe,
	kA2ModelIIc,
	kA2ModelIIcp,				// the //c+ (not working yet!!)
//	kA2ModelIII,
//	kA2ModelIIIp,
	kA2NumModels,

	kA2DiskNone = 0,		// possible content of a disk drive
	kA2DiskReadOnly,
	kA2DiskReadWrite,

	kA2PFPlain = 0,			// printer I/O filters
	kA2PFEpsonToPS,
//	kA2PFScribeToPS,
	kA2PFVerbatim,

	kfA2LightDDrive0	= 1,		// indicator-light states, as returned
	kfA2LightDDrive1	= 1<<1,		//   from '-Lights'
	kfA2LightDDrive2	= 1<<2,
	kfA2LightDDrive3	= 1<<3,
	kfA2LightPrinter	= 1<<4,

	kfA2Button0			= 1,		// button & mod-key states
	kfA2Button1			= 1<<1,
	kfA2Button2			= 1<<2,
	kfA2ButtonMouse		= 1<<3,
	kfA2AnyKeyDown		= 1<<4,
	kfA2KeyOpenApple	= kfA2Button0,
	kfA2KeySolidApple	= kfA2Button1,
	kfA2KeyShift		= kfA2Button2,

	kA2ScreenWidth		= 4+560+4,	// the pixel width and
	kA2ScreenHeight		= 192*2,	//   height of a rendered screen image
	kA2PaddleRange		= 3000,		// largest useful paddle value
	kA2SamplesPerStep	= 364,		// audio samples per emulation step
//	kA2SamplesPerSec	= 22050,	// audio samples per second

#if 0
	kA2NaUSA = 0,			// nation codes (not used yet)
	kA2NaFrance,
	kA2NaGermany,
	kA2NaUK,
	kA2NaDenmark,
	kA2NaSweden,
	kA2NaItaly,
	kA2NaSpain,
	kA2NaJapan,
	kA2NaNorway,
#endif
};

//---------------------------------------------------------------------------

extern struct A2Globals
{
	unsigned		buttons;			// current button & mod-key states
	unsigned		paddle[2];			// current paddle values
	BOOL			timeInGMT;			// clock times are in GMT?
	BOOL			hearC02x;			// hits on $C02x are audible?

	uint8_t			defaultModel;
	uint8_t			defaultExtraRAM;
	const uint16_t	standardColors[16];

//	uint8_t			pixels[1<<8][1<<10];
//	uint16_t		dswitchSSC[2],		// DIP switch settings
//					dswitchEpsonRX80;
//	BOOL			keypadControlsPaddles;

} A2G;

//---------------------------------------------------------------------------
//	Apple II peripherals.

@class A2DiskDrive;


@protocol A2PrDiskDrive

- (NSString*)	Label;
- (unsigned)	Content;
- (BOOL)		Load:(NSString*)fpath;
- (void)		Unload;

@end


#if 0
@protocol A2PrPrinter

- (long)	SizeOfSession;
- (void)	ClearSession;
- (BOOL)	SaveSessionAs:(unsigned)filter toFile:(NSString*)fpath;

@end
#endif

//---------------------------------------------------------------------------

@interface A2Computer : NSResponder // <NSCoding>
{
	//-----------------	Computer State -----------------

	uint8_t				mA, mX, mY, mS,	// some 6502 registers
						mI,				// 6502 I flag (= 0 or 4)
						mModel,			// model identifier code
						mHalts;			// flags to block emulation
	uint16_t			mPC, mP;		// PC and pseudo-P registers
	uint32_t			mFlags,			// flags and soft-switches
						mMutableFlags,	// flags this model may change
						mCycles,		// CPU cycle count
						mWhenC07x;		// time when $C07x last referenced

	struct A2Memory*	mMemory;		// struct containing all our memory
	unsigned			mMemorySize;	// size of allocated memory
	int16_t				*mTblADC,		// this model's ADC and SBC tables
						*mTblSBC;

	uint8_t				mVideoFlags[262];	// video flags for each scanline

	//-----------------	Peripherals -----------------

	struct {			// keyboard input queue
		BOOL			hitRecently;
		uint8_t			head, tail, buf[256];
	}					mKeyQ;

	struct {			// printer
		FILE*			session;
		uint8_t			lights, reg[16];
	}					mPrinter;

	struct {
		int				index;
	}					mClock;

	struct {			// optional "Slinky" RAM card
		uint32_t		pos, mask;
		uint8_t			*rBase, *wBase, rNowhere, wNowhere;
	}					mSlinky;

	struct A2IWM {		// two IWM controllers, with two drives each
		A2DiskDrive*	drive[2];
		uint8_t			flags, modeReg, lights;
	}					mIWM[2];

#if 0
	struct A2PSG {		// stereo Mockingboard chips
		uint16_t		freqA, freqB, freqC,
						periodEnv;
		uint8_t			freqNG, disable, shapeEnv,
						levelA, levelB, levelC;
	}					mPSG[2];
#endif
}

@end

//---------------------------------------------------------------------------
//	The various methods of A2Computer, grouped by category.

@interface A2Computer (Audio)

+ (void)		_InitAudio;
- (void)		_DefaultAudio:(uint8_t [])audioOut :(unsigned)nSamples;
+ (void)		SetAudioVolume:(unsigned)volume;

@end

@interface A2Computer (CPU)

+ (void)		_InitCPU;
- (void)		RunForOneStep:(uint8_t [])audioOut;

@end

@interface A2Computer (Printing)

+ (void)		_InitPrinting;
- (long)		SizeOfPrintSession;
- (void)		ClearPrintSession;
- (BOOL)		SavePrintSessionAs:(unsigned)filter toFile:(NSString*)fpath;

@end

@interface A2Computer (ROM)

+ (void)		_InitROM;
+ (BOOL)		ModelHasROM:(unsigned)modelCode;
+ (BOOL)		ScanFileForROM:(NSString*)fpath;
+ (void)		ScanDirectoryForROM:(NSString*)dpath;
- (void)		_PrepareModel;

@end

@interface A2Computer (UserInterface)

+ (void)		InputPaddlesByKeypad:(char)ch;
+ (void)		InputPaddlesByMouse;
+ (void)		SetMouseRangeTo:(NSRect)r;
- (BOOL)		InputChar:(unichar)ch;
- (void)		InputChars:(NSString*)str;
- (unsigned)	ModelCode;
- (NSString*)	ModelName;
- (IBAction)	SignalReset:(id)sender;
- (IBAction)	SignalReboot:(id)sender;
- (unsigned)	Lights;
- (NSString*)	TextScreenAsString:(BOOL)newLines;
+ (BOOL)		ShouldShowDiskFilename:(NSString*)path;
+ (void)		_UpdateClock:(NSTimer*)timer;

- (id<A2PrDiskDrive>)	DiskDrive:(unsigned)index;

@end

@interface A2Computer (Video)

+ (void)		_InitVideo;
- (void)		RenderScreen:(void*)pixBase:(int32_t)rowBytes;

@end

//---------------------------------------------------------------------------
