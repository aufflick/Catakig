/*	class A2Computer (category ROM)

	Methods for dealing with Apple II ROM, and model-specific features.
*/
#import "LibAppleII-Priv.h"

@implementation A2Computer (ROM)
//---------------------------------------------------------------------------

static struct // the ROM repository
{
	uint8_t
		bogus[0x100],		// These are init'd with file 'myROM.h'.
		printer[0x100],
		clock[0x100],
		memory[0x100],

		DiskII[0x100],
		SSCX[0x700], SSC[0x100],
		IIeSerialX[0x700], IIeSerial[0x100],
		Slinky[0x100], SlinkyX[0x800],
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

	return NO; // means 'modelCode' isn't valid
}

//---------------------------------------------------------------------------

- (void)_InstallPeripheralROM:(unsigned)slotNum
	:(const uint8_t [/*0x100*/])slotROM
	:(const uint8_t [/*0x800*/])expansionROM
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
	Makes model-specific preparations for this Apple II, primarily ROM
	content and flag settings.
*/
	enum 
	{
		kMF_ec = // set of mutable flags common to IIe and IIc
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

#if 1
	for (int s = 1;  s <= 7;  ++s) // for debugging memory mapping!!
	{
		memset(ROM1 + 0x100*s, s, 0x100);
		memset(ROM1 + 0x800*s, s*0x11, 0x800);
	}
#endif

//	Install the machine's primary ROM, copying it from the repository.

	switch (mModel)
	{
	  case kA2ModelIIo:
		memcpy(ROM0 + 0x1000, gROM.IIo, 0x3000);
		goto PrepNonIIc;

	  case kA2ModelIIp:
		memcpy(ROM0 + 0x1000, gROM.IIpD0, 0x3000);
		goto PrepNonIIc;

	  case kA2ModelIIe:
		memcpy(ROM0 + 0x0100, gROM.IIeC1, 0x3F00);
		mMutableFlags |= kMF_ec | kfCXROM | kfC3ROM;
		// fall into ...

	  PrepNonIIc:
		[self _InstallPeripheralROM:1 :gROM.printer :nil];
		[self _InstallPeripheralROM:3 :gROM.clock :nil];
		[self _InstallPeripheralROM:4 :gROM.memory :nil];
		[self _InstallPeripheralROM:6 :gROM.DiskII :nil];

		memcpy(mMemory->mixedSlotROM, ROM1, 0x800);
		memcpy(mMemory->mixedSlotROM+0x300, ROM0+0x300, 0x100);
		memcpy(mPrinter.reg,
			"\x68\xEE\x7B\xFF"
			"\x68\xEE\x7B\xFF"
			"\0\x10\0\0\xFF\xFF\xFF\xFF", 16);
		break;

	  case kA2ModelIIcp:
		memcpy(ROM0 + 0x100, gROM.IIcpMain, 0x3F00);
		memcpy(ROM1 + 0x100, gROM.IIcpAlt , 0x3F00);
		goto PrepIIc;

	  case kA2ModelIIc:
		// Check for older, single-bank IIc ROM!!
		memcpy(ROM0 + 0x100, gROM.IIcMain, 0x3F00);
		memcpy(ROM1 + 0x100, gROM.IIcAlt , 0x3F00);
		// fall into ...

	  PrepIIc:
		mMutableFlags |= kMF_ec;
		memcpy(mPrinter.reg,
			"\0\x50\0\0\0\x50\0\0\0\x50\0\0\0\x50\0\0", 16);
	//	memcpy(mModem.reg, "\0\x10\0\0\0\x10\0\0\0\x10\0\0\0\x10\0\0", 16);
		break;
	}
}

//---------------------------------------------------------------------------

+ (BOOL)ScanFileForROM:(NSString*)filePath
{/*
	Scans the given file, looking for ROM segments that we recognize.  A
	segment is recognized if the checksum of its first 256 bytes matches
	a sum that we've precomputed.  Recognized segments are read into the
	ROM repository structure (above).
*/
#define CASE(N, ARR) \
	case 0x##N:  dest = gROM.ARR;  len = sizeof(gROM.ARR);  break;

	enum {		kLogging = NO,
				chunkSize = 256 };
	uint8_t		chunk[chunkSize];
	FILE*		fin;
	uint32_t	crcInit = crc32(0L, Z_NULL, 0);

	fin = fopen([filePath fileSystemRepresentation], "rb");
	if (fin == NULL)
		return NO;
	setbuf(fin, NULL);

	if (kLogging)
		NSLog(@"Scanning file '%@' for ROM", [filePath lastPathComponent]);

	while (fread(chunk, 1, chunkSize, fin) == chunkSize)
	{
		uint32_t	crc = crc32(crcInit, chunk, chunkSize);
		uint8_t*	dest;
		long		len;

		if (kLogging)
			NSLog(@"%05lX: crc=%08X", ftell(fin) - chunkSize, crc);

		switch (crc)
		{
			CASE(AA2342E8, IIo)
			CASE(B9E3B093, IIpD0)			CASE(79135697, IIpD5)
			CASE(40375280, IIeC1)			CASE(1DB83E23, IIeD5)
		//	CASE(24F39DF7, IIcpMain)		CASE(F768C5C3, IIcpAlt)

			case 0x816CDA70: // rev. 00
			CASE(228C4909, IIcMain) // rev. 03 and 04

			case 0xFA9D7930: // rev. 00
			case 0xF768C5C3: // rev. 04 (also IIcpAlt!!)
			CASE(DC459600, IIcAlt) // rev. 03

			CASE(CE7144F6, DiskII)
			CASE(BA81A559, Mouse)
			CASE(92600557, Slinky)			CASE(67C88BD0, SlinkyX)
			CASE(87DF71C4, SSC)				CASE(F085C5CF, SSCX)
			CASE(926CBF62, IIeSerial)		CASE(F35CD658, IIeSerialX)

			default: continue; // chunk not recognized; continue reading
		}
		memcpy(dest, chunk, chunkSize);
		fread(dest+chunkSize, 1, len-chunkSize, fin);

		if (crc == 0xB9E3B093) // IIpD0
			memcpy(gROM.IIeD0, dest, len);
	}

	fclose(fin);
	return YES;

#undef CASE
}

//---------------------------------------------------------------------------

+ (void)ScanDirectoryForROM:(NSString*)dirPath
{/*
	Scans every file in the given directory for recognized segments of ROM.
	If nil is passed, the application's "ROMs" directory is searched.
*/
	NSEnumerator	*e;
	NSString		*fname, *fpath;

	if (dirPath == nil)
		dirPath = [[[NSBundle mainBundle] bundlePath]
			stringByAppendingPathComponent:@"../ROMs"];

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
