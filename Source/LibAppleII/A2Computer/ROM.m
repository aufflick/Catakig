/*	class A2Computer (category ROM)

	Methods for dealing with Apple II ROM, and model-specific features.
*/
#import "LibAppleII-Priv.h"

@implementation A2Computer (ROM)
//---------------------------------------------------------------------------

static struct // the ROM repository
{
	uint8_t
		bogus[0x100],		// These are init'd with 'myROM.h'.
		printer[0x100],
		clock[0x100],
		Slinky[0x100],

		DiskII[0x100],
		SSCX[0x700], SSC[0x100],
		IIeSerialX[0x700], IIeSerial[0x100],
		SlinkyX[0x800],
		Mouse[0x100], // MouseX[0x800],
	//	PIC[0x100],
	//	ThunderClock[0x100], ThunderClockX[0x800],

		IIo[0x3000],
		IIpD0[0x500], IIpD5[0x3000-0x500],
		IIeC1[0xF00], IIeD0[0x500], IIeD5[0x3000-0x500],
		IIcMain [0x3F00], IIcAlt [0x3F00],
		IIcpMain[0x3F00], IIcpAlt[0x3F00];

} gROM = {
	#include "myROM.h"
};

//---------------------------------------------------------------------------

+ (void)_InitROM
{/*
	Called once at startup, from '+initialize'.
*/
#define PREP(ARR) \
	memcpy(gROM.ARR + sizeof(gROM.ARR) - 256, gROM.bogus, 256)

	PREP(IIo);			PREP(IIpD5);		PREP(IIeD5);
	PREP(IIcMain);		PREP(IIcAlt);
	PREP(IIcpMain);		PREP(IIcpAlt);

	[A2Computer ScanDirectoryForROM:nil];

#undef PREP
}

//---------------------------------------------------------------------------

+ (BOOL)ModelHasROM:(unsigned)modelCode
{/*
	Returns whether ROM for the given Apple II model is available in the
	ROM repository.
*/
	switch (modelCode)
	{
	  case kA2ModelIIo:
		return gROM.IIo[0] != 0;

	  case kA2ModelIIp:
		return gROM.IIpD0[0]  and  gROM.IIpD5[0];

	  case kA2ModelIIe:
		return gROM.IIeC1[0]  and  gROM.IIeD0[0]  and  gROM.IIeD5[0];

	  case kA2ModelIIc:
		return gROM.IIcMain[0]  and  gROM.IIcAlt[0];

	  case kA2ModelIIcp:
		return gROM.IIcpMain[0]  and  gROM.IIcpAlt[0];
	}

	return NO; // means model code isn't valid
}

//---------------------------------------------------------------------------

- (void)_InstallPeripheralROM:(unsigned)slotNum
	:(const uint8_t*)slotROM // size 256
	:(const uint8_t*)expansionROM // size 2048
{/*
	Private utility method for importing a peripheral's ROM content,
	given its slot number and pointers to the bytes.
*/
	if (slotNum < 1  or  slotNum > 7) // safety check
		return;

	if (slotROM != nil)
		memcpy(mMemory->ROM[1] + 0x100*slotNum, slotROM, 0x100);

	if (expansionROM != nil)
		memcpy(mMemory->ROM[1] + 0x800*slotNum, expansionROM, 0x800);
}

//---------------------------------------------------------------------------

- (void)_PrepareModel
{/*
	Makes model-specific preparations for this Apple II, including ROM
	content and flag settings.
*/
	enum 
	{
		kMF_ec =	// set of mutable flags common to IIe and IIc
					kf80COL | kfSINGRES | kfALTCHAR |
					kfALTZP | kfRAMRD | kfRAMWRT |
					kf80STOREm | kf80STOREv
	};
	uint8_t		*ROM0 = mMemory->ROM[0], // internal, or main bank
				*ROM1 = mMemory->ROM[1]; // external, or alt. bank

	if (mModel < kA2ModelIIe)
		mTblADC = A2T.tADCo, mTblSBC = A2T.tSBCo;
	else
		mTblADC = A2T.tADC , mTblSBC = A2T.tSBC;

	mMutableFlags = 0;
	memset(mMemory->ROM, 0, sizeof(mMemory->ROM)); // wipe ROM clean

	for (int i = 0;  i <= 7;  ++i) // for debugging memory mapping!!
		memset(ROM1 + 0x800*i, i*0x11, 0x800);

//	Install the machine's primary ROM, copied from the repository.

	switch (mModel)
	{
	  case kA2ModelIIo:
		memcpy(ROM0 + 0x1000, gROM.IIo, 0x3000);
		goto PrepIIo_p_e;

	  case kA2ModelIIp:
		memcpy(ROM0 + 0x1000, gROM.IIpD0, 0x3000);
		goto PrepIIo_p_e;

	  case kA2ModelIIe:
		memcpy(ROM0 + 0x0100, gROM.IIeC1, 0x3F00);
		mMutableFlags |= kMF_ec | kfCXROM | kfC3ROM;
		// fall into PrepIIo_p_e

	  PrepIIo_p_e:
		[self _InstallPeripheralROM:1 :gROM.SSC :gROM.SSCX];
		[self _InstallPeripheralROM:2 :gROM.clock :nil];
		[self _InstallPeripheralROM:4 :gROM.Slinky :gROM.SlinkyX];
		[self _InstallPeripheralROM:6 :gROM.DiskII :nil];
		memcpy(mMemory->altSlotROM, ROM1, 0x800);
		memcpy(mMemory->altSlotROM+0x300, ROM0+0x300, 0x100);
		memcpy(mPrinter.reg,
			"\x68\xEE\x7B\xFF\x68\xEE\x7B\xFF"
			"\0\x10\0\0\xFF\xFF\xFF\xFF", 16);
		break;


	  case kA2ModelIIcp:
		memcpy(ROM0 + 0x0100, gROM.IIcpMain, 0x3F00);
		memcpy(ROM1 + 0x0100, gROM.IIcpAlt , 0x3F00);
		goto PrepIIc;

	  case kA2ModelIIc:
		// Check for older, single-bank IIc ROM!!
		memcpy(ROM0 + 0x0100, gROM.IIcMain, 0x3F00);
		memcpy(ROM1 + 0x0100, gROM.IIcAlt , 0x3F00);
		// fall into PrepIIc;

	  PrepIIc:
		mMutableFlags |= kMF_ec;
		memcpy(mPrinter.reg,
			"\0\x50\0\0\0\x50\0\0\0\x50\0\0\0\x50\0\0", 16);
	//	memcpy(mModem.reg,
	//		"\0\x10\0\0\0\x10\0\0\0\x10\0\0\0\x10\0\0", 16);
		break;
	}
}

//---------------------------------------------------------------------------

+ (BOOL)ScanFileForROM:(NSString*)filePath
{/*
	Scans the given file, looking for ROM segments that we recognize.  A
	segment is recognized if the checksum of its first 256 bytes matches
	one that we've precomputed.  Segments are then read into the ROM
	repository, defined above.
*/
#define CASE(N, ARR)  case 0x##N: \
	dest = gROM.ARR;  len = sizeof(gROM.ARR);  break;

	enum {			kDebug = NO,
					chunkSize = 256 };
	uint8_t			chunk[chunkSize];
	NSInputStream*	sin;

	if (nil == (sin = [[NSInputStream alloc] initWithFileAtPath:filePath]))
		return NO;
	[sin open];

	if (kDebug)
		NSLog(@"Scanning ROM file '%@'", [filePath lastPathComponent]);

	while ([sin read:chunk maxLength:chunkSize] == chunkSize)
	{
		uint32_t	crc = adler32(~0UL, chunk, chunkSize);
		uint8_t*	dest;
		long		len;

		if (kDebug)
			NSLog(@"%05lX: crc=%08X",
				[[sin propertyForKey:NSStreamFileCurrentOffsetKey] longValue]
					- chunkSize, crc);

		switch (crc)
		{
			CASE(5FCB5D2A, IIo)
			CASE(B2ADA4E6, IIpD0)			CASE(F3048537, IIpD5)
			CASE(EDA770F0, IIeC1)			CASE(085488C1, IIeD5)

			CASE(A3BB7671, IIcMain)			CASE(A9A56CEC, IIcAlt)
			CASE(A40E7672, IIcpMain)		CASE(A99F6CE9, IIcpAlt)

			CASE(9C377B54, DiskII)
		//	CASE(39797894, Mouse)
		//	CASE(67D46AFF, SSC)				CASE(B2EB6D44, SSCX)
		//	CASE(C37D631F, IIeSerial)		CASE(CDFB877A, IIeSerialX)
		//	CASE(FCE2762B, Slinky)			CASE(807A73D1, SlinkyX)

			default: continue; // chunk not recognized; continue reading
		}
		memcpy(dest, chunk, chunkSize);
		[sin read:dest+chunkSize maxLength:len-chunkSize];

		if (dest == gROM.IIpD0)
			memcpy(gROM.IIeD0, dest, len);
	}

	[sin close]; // need??
	[sin release];
	return YES;

#undef CASE
}

//---------------------------------------------------------------------------

+ (void)ScanDirectoryForROM:(NSString*)dirPath
{/*
	Scans every file in the given directory for recognized segments of
	ROM.  If nil is passed, the default directory is "ROMs", at the same
	level as the application bundle.
*/
	if (dirPath == nil)
		dirPath = [[[NSBundle mainBundle] bundlePath]
			stringByAppendingPathComponent:@"../ROMs"];

	NSEnumerator	*e;
	NSString		*fname, *fpath;

	e = [[[NSFileManager defaultManager]
		directoryContentsAtPath:dirPath] objectEnumerator];
	if (e == nil)
		return;

	while (nil != (fname = [e nextObject]))
	{
		if ([fname characterAtIndex:0] != '.')
		{
			fpath = [dirPath stringByAppendingPathComponent:fname];
			[A2Computer ScanFileForROM:fpath];
		}
	}
}

//---------------------------------------------------------------------------
@end
