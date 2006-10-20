/*	class A2Computer

	An object representing an Apple II computer.  Methods in this source
	file do object allocation, initialization, deallocation, and
	(eventually) serialization.
*/
#import "LibAppleII-Priv.h"
#import "A2DiskDrive.h"

@implementation A2Computer
//---------------------------------------------------------------------------

+ (void)initialize
{
	if (self != [A2Computer class])
		return; // ensures this routine executes no more than once

	[A2Computer _InitAudio];
	[A2Computer _InitVideo];
	[A2Computer _InitCPU];
	[A2Computer _InitROM];
	[A2Computer _InitPrinting];

	[A2Computer SetMouseRangeTo:NSMakeRect(0, 0, 640, 480)];
	[A2Computer setVersion:1]; //??
	mlock(&A2T, sizeof(A2T));

	[NSTimer scheduledTimerWithTimeInterval:0.45
		target:			[A2Computer class]
		selector:		@selector(_UpdateClock:)
		userInfo:		nil
		repeats:		YES ];

	if (NSPageSize() > 0x2000)
		NSLog(@"Warning: VM page size = %ld (> 0x2000)", NSPageSize());
#if 0
	NSLog(@"A2Computer size = %lu", sizeof(struct{@defs(A2Computer)}));
	NSLog(@"VM page size = 0x%X", NSPageSize());
	NSLog(@"A2T size = %lu", sizeof(A2T));
#endif
}

//---------------------------------------------------------------------------

- (id)init
{/*
	"Add your subclass-specific initialization here.  If an error occurs,
	send a [self release] message and return nil."

	Not robust enough against failures!!
*/
	if (nil == (self = [super init]))
		return nil;

	mModel				= A2G.defaultModel;
	mFlags				= kfTEXT;
	mHalts				= kfHaltNoPower | kfHaltReset;
	mMemorySize			= sizeof(A2Memory);
	mPrinter.session	= tmpfile();
	mSlinky.mask		= (1UL << A2G.defaultExtraRAM) - 1;
	mSlinky.rNowhere	= 0xA0;
	mSlinky.rBase		= &mSlinky.rNowhere;
	mSlinky.wBase		= &mSlinky.wNowhere;

	if (mSlinky.mask != 0)
		mMemorySize += (mSlinky.mask + 1);
	mMemory = NSAllocateMemoryPages(mMemorySize);

	if (not mMemory  or  not mPrinter.session)
		return [self Release];

	if (mSlinky.mask != 0)
		mSlinky.rBase = mSlinky.wBase =
			(uint8_t*)mMemory + sizeof(A2Memory);

//	Create the disk drives, and give every one a track buffer to
//	work with.

	for (int dd = 4;  --dd >= 0;)
		mIWM[dd>>1].drive[dd&1] = [[A2DiskDrive alloc]
			InitUsingBuffer: mMemory->diskBuffers[dd] ];

//	Initialize video memory with random bytes (a theatrical effect).

	for (int i = 0x6000;  --i >= 0;)
		((uint16_t*)(mMemory->RAM))[i] = A2Random16();

	madvise(mMemory, mMemorySize, MADV_SEQUENTIAL);
	[self _PrepareModel];
	return self;
}

//---------------------------------------------------------------------------

- (void)_TestThePrinter:(BOOL)sampleOutput
{
	// Called only for debugging!!

	if (sampleOutput)
	{
		fputs(
			"---------1---------2---------3---------4"
			"---------5---------6---------7---------8\r\n\r\n"
			" !\"#$%&'()*+,-./0123456789:;<=>?\r\n"
			"@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_\r\n"
			"`abcdefghijklmnopqrstuvwxyz{|}~\r\n\r\n"
			"\x1B\x34Hello world!\x1B@\r\n", mPrinter.session);
		fprintf(mPrinter.session,
			"\x1BK\x07%c\1\2\3\4\5\6\7 |\r\n", 0);
		for (int i = 0;  i < 100;  ++i)
			fprintf(mPrinter.session, "%d\t%d\r\n", i, i*i);
	}

	[self SavePrintSessionAs:kA2PFVerbatim
		toFile:@"/Users/klipsch/Desktop/printout.raw"];
	[self SavePrintSessionAs:kA2PFPlain
		toFile:@"/Users/klipsch/Desktop/printout.txt"];
	[self SavePrintSessionAs:kA2PFEpsonToPS
		toFile:@"/Users/klipsch/Desktop/printout.ps"];
}

//---------------------------------------------------------------------------

- (void)dealloc
{
//	[self _TestThePrinter:NO];

	for (int dd = 4;  --dd >= 0;)
		[mIWM[dd>>1].drive[dd&1] release];

	if (mMemory != nil)
		NSDeallocateMemoryPages(mMemory, mMemorySize);

	fclose(mPrinter.session);
	[super dealloc];
}

//---------------------------------------------------------------------------

- (void)encodeWithCoder:(NSCoder*)enc // experimental!!
{
	[enc encodeArrayOfObjCType:@encode(uint8_t) count:7 at:&mA];
	[enc encodeArrayOfObjCType:@encode(uint16_t) count:2 at:&mPC];
	[enc encodeArrayOfObjCType:@encode(uint32_t) count:4 at:&mFlags];

	[enc encodeBytes:mMemory->RAM length:2*k64KB];

	for (int i = 0;  i <= 1;  i++)
	{
		A2IWM*	iwm = mIWM + i;
	}
}

//---------------------------------------------------------------------------

- (id)initWithCoder:(NSCoder*)dec // experimental!!
{
	if (nil == (self = [super init]))
		return nil;

	void*		ptr;
	unsigned	len;

	[dec decodeArrayOfObjCType:@encode(uint8_t) count:7 at:&mA];
	[dec decodeArrayOfObjCType:@encode(uint16_t) count:2 at:&mPC];
	[dec decodeArrayOfObjCType:@encode(uint32_t) count:4 at:&mFlags];

	ptr = [dec decodeBytesWithReturnedLength:&len];
	memcpy(mMemory->RAM, ptr, len);

	for (int i = 0;  i <= 1;  i++)
	{
		A2IWM*	iwm = mIWM + i;
	}

	return self;
}

//---------------------------------------------------------------------------
@end
