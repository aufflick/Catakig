/*  class A2DiskDrive
*/
#import "LibAppleII-Priv.h"
#import "A2DiskDrive.h"
#import "A2DiskImages.h"

@implementation A2DiskDrive
//---------------------------------------------------------------------------

enum
{
	kSizeNIBTrack		= 0x1A00, // 6656
	kSizeNB2Track		= 0x18F0, // 6384
	kSizePhysTrack		= kSizeNIBTrack, // should be 6350-6480 bytes

	kGap3				= 16, // should be 16-24 bytes
	kGap2				=  6, // should be  5-10 bytes
	kSizePhysSector		= kGap3 + (3+8+3) + kGap2 + (3+86+256+1+3),
//	kNumTracks			= 35, // 35-40??
	kDefaultVolumeNum	= 254,

	kOpenRW				= O_NONBLOCK | O_RDWR | O_EXLOCK,
	kOpenR				= O_NONBLOCK | O_RDONLY,
};

static struct
{
	regex_t		rexDigits,
				rexSuffixes5,
				rexSuffixes3;
} g;

//---------------------------------------------------------------------------

+ (void)initialize
{
	enum {	kFlags = REG_EXTENDED | REG_NOSUB | REG_ICASE };

	if (self != [A2DiskDrive class])
		return; // ensures this routine executes no more than once

	regcomp(&g.rexDigits, "[0-9]+", kFlags);
	regcomp(&g.rexSuffixes5, "2i?mg|dsk|[dp]o|n[iy]b", kFlags);
	regcomp(&g.rexSuffixes3, "2i?mg|img|hdv", kFlags);
}

//---------------------------------------------------------------------------

- (void)_WriteWorkingDiskToFile:(fd_t)fout:(BOOL)as2IMG
{
	REWIND(fout);
	ftruncate(fout, 0);

	if (as2IMG)
	{
		A2Header2IMG  hdr =
		{
			.m2IMG			= "2IMG",
			.mCreator		= "CTKG",
			.mHeaderLength	= NSSwapHostShortToLittle(64),
			.mVersion		= NSSwapHostShortToLittle(1),
			.mFormat		= 2, // NIB
		//	.mPad1			= {0},
			.mVolNumber		= 0,
			.mGotVolume		= 0,
		//	.mPad2			= 0,
			.mLocked		= 0,
			.mNumBlocks		= 0,
			.mDataPos		= NSSwapHostLongToLittle(sizeof(A2Header2IMG)),
			.mDataLen		= NSSwapHostLongToLittle(35L * 0x2000),
			.mCommentPos	= 0,
			.mCommentLen	= 0,
			.mAppDataPos	= 0,
			.mAppDataLen	= 0,
		//	.mPad3			= {0},
		};
		write(fout, &hdr, sizeof(hdr));
	}

	for (int t = 0;  t < 35;  ++t)
	{
		[self SeekTrack:t];
		write(fout, mTrackBase, kSizeNIBTrack);
	}
}

//---------------------------------------------------------------------------

static void EnnybSector(uint8_t* dest, //[kSizePhysSector]
	uint8_t src[256+2], int volume, int track, int sector)
{/*
	Make a physical, nybblized sector out of a logical one.  Input is
	taken from array _src_; output is deposited into array _dest_.
*/
#define ENCODE_44(BYTE) \
	dest[0] = 0xAA | (x=(BYTE))>>1; \
	dest[1] = 0xAA | x;  dest += 2

#define TRIPLET(B0,B2) \
	dest[0] = B0;  dest[1] = 0xAA;  dest[2] = B2;  dest += 3

	static const uint8_t  pbyte[] =
	{	// physical encoding of 6-bit logical values
		0x96,0x97,0x9A,0x9B,0x9D,0x9E,0x9F,0xA6,
		0xA7,0xAB,0xAC,0xAD,0xAE,0xAF,0xB2,0xB3,
		0xB4,0xB5,0xB6,0xB7,0xB9,0xBA,0xBB,0xBC,
		0xBD,0xBE,0xBF,0xCB,0xCD,0xCE,0xCF,0xD3,
		0xD6,0xD7,0xD9,0xDA,0xDB,0xDC,0xDD,0xDE,
		0xDF,0xE5,0xE6,0xE7,0xE9,0xEA,0xEB,0xEC,
		0xED,0xEE,0xEF,0xF2,0xF3,0xF4,0xF5,0xF6,
		0xF7,0xF9,0xFA,0xFB,0xFC,0xFD,0xFE,0xFF
	};
	uint8_t		x, ox;

	dest += kGap3;
	TRIPLET(0xD5, 0x96);
	ENCODE_44(volume);
	ENCODE_44(track);
	ENCODE_44(sector);
	ENCODE_44(volume ^ track ^ sector);
	TRIPLET(0xDE, 0xEB);
	dest += kGap2;
	TRIPLET(0xD5, 0xAD);

	for (int i = ox = 0;  i < 86;  ++i, ox = x)
	{
		x = "\0\x02\x01\x03"[ src     [i] & 3] |
			"\0\x08\x04\x0C"[(src+ 86)[i] & 3] |
			"\0\x20\x10\x30"[(src+172)[i] & 3];
		dest[i] = pbyte[ox ^ x];
	}
	dest += 86;

	for (int i = 0;  i < 256;  ++i, ox = x)
		dest[i] = pbyte[ox ^ (x = src[i] >> 2)];
	dest += 256;

	*dest++ = pbyte[x];
	TRIPLET(0xDE, 0xEB);

#undef ENCODE_44
#undef TRIPLET
}

//---------------------------------------------------------------------------

- (void)_ImportDisk140K:(int)format:(int)volume
{
	const uint8_t	sectorMaps[][16] =
	{
		{0,7,14,6,13,5,12,4,11,3,10,2,9,1,8,15}, // DO
		{0,8,1,9,2,10,3,11,4,12,5,13,6,14,7,15}, // PO
	//	{0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15}, // identical
	//	{0,15,14,13,12,11,10,9,8,7,6,5,4,3,2,1}, // reversed
	};
	enum {			kGap1 = 0x2000 - 16*kSizePhysSector };
	const uint8_t*	map;
	long			base = TELL(mOrigFD);
	uint8_t			lsec[256+2], // logical sector
					psec[kSizePhysSector]; // physical sector

	lsec[256] = lsec[257] = 0;
	memset(psec, 0xFF, sizeof(psec));
	map = sectorMaps[format == kFmtPO  or  format == kFmt2IMG_PO];

	for (int t = 0;  t < 35;  ++t) // 35 tracks of ...
	{
		for (int s = 0;  s < 16;  ++s) // 16 physical sectors
		{
			pread(mOrigFD, lsec, 256, base + 256L*(t*16 + map[s]));
			EnnybSector(psec, lsec, volume, t, s);
			write(mWorkFD, psec, kSizePhysSector);
		}
		A2WriteFiller(mWorkFD, 0xFF, kGap1);
	}

	ftruncate(mWorkFD, 35*0x2000);
}

//---------------------------------------------------------------------------

- (void)_ImportDiskNIB:(uint32_t)rdTrackSize
{
	enum {		wrTrackSize = 0x2000 };
	uint8_t		buf[2][wrTrackSize];

	memset(buf[0], 0xFF, wrTrackSize);

	for (int t = 35;  --t >= 0;)
	{
		read(mOrigFD, buf[0], rdTrackSize);
#if 0
		memcpy(buf[1], buf[0], wrTrackSize);
		
#endif
		write(mWorkFD, buf[0], wrTrackSize);
	}
}

//---------------------------------------------------------------------------

- (BOOL)SeekTrack:(unsigned)reqTrack
{/*
	Moves this drive's R/W head to the requested track, identified by a
	non-negative index.  Returns whether successful.  Fails if the index is
	outside the range of available tracks.
*/
	if (reqTrack > mTrackMax) // then requested track out of range
		return NO;

//	if (mTrackIndex != reqTrack)
		A2MemoryMap(mTrackBase, 0x2000, mWorkFD, reqTrack*0x2000);

//	mTheta = 0; // always rewind??
	mTrackIndex = reqTrack;
	return YES;
}

//---------------------------------------------------------------------------

- (void)Unload
{/*
	Empties this disk drive of any disk.
*/
	if (mDiskModified  and  IS_OPEN(mOrigFD))
	{
		[self _WriteWorkingDiskToFile:mOrigFD:NO];
		[mFilePath SetFileCreator:'Ctkg' andType:'A2D5'];
		if ([mFilePath ExtensionMatches:&g.rexSuffixes5])
			[mFilePath SetFileExtension:@"nyb"];
	}

	[self SeekTrack:0];

	mContent		= kA2DiskNone;
	mOrigFD			= CLOSE(mOrigFD);
	mFilePath		= [mFilePath Release];
	mTrackSize		= 0x1A00;
	mTrackMax		= 0;
	mTheta			= 0;
	mDiskModified	= NO;

	memset(mTrackBase, 0xFF, mTrackSize);
}

//---------------------------------------------------------------------------

- (id)InitUsingBuffer:(uint8_t [/*0x2000*/])buffer
{
	if (nil == (self = [super init]))
		return nil;

	mTrackBase	= buffer;
	mOrigFD		= kBadFD;
	mWorkFD		= A2OpenTempFile(35L * 0x2000);

	if (not IS_OPEN(mWorkFD))
		return [self Release];

	[self Unload];
	return self;
}

//---------------------------------------------------------------------------

- (void)dealloc
{
	[self Unload];
	close(mWorkFD);
	[super dealloc];
}

//---------------------------------------------------------------------------

- (BOOL)_OpenDiskImageFile:(NSString*)fpath
{
	const char*		cfpath		= [fpath fileSystemRepresentation];
	unsigned		volumeNum	= kDefaultVolumeNum,
					format		= kFmtUnknown;
	struct stat		st;
	long			n;
	union {
		A2Header2IMG		_2IMG;
		A2HeaderDiskCopy4	DC4;
		char				bytes[512];
	}						header;

	/*-------------------------------------------------------
		Try opening the file for reading & writing -- if that
		fails, then just for reading -- and if that fails,
		give up.
	*/
	if (IS_OPEN(mOrigFD = open(cfpath, kOpenRW)))
		mContent = kA2DiskReadWrite;
	else if (IS_OPEN(mOrigFD = open(cfpath, kOpenR)))
		mContent = kA2DiskReadOnly;
	else // we can't open in any useful mode
		return NO;

	if (fstat(mOrigFD, &st) != 0  or
		read(mOrigFD, &header, sizeof(header)) < sizeof(header) )
		return NO;

	/*------------------------------------------------------
		Infer the file's format from it's size or header.
	*/
	n = st.st_size / 35;

	if (n == 0x1000) // then DO or PO
		format = kFmtDO + [[fpath lowercaseString] hasSuffix:@".po"];
	else if (n == kSizeNIBTrack)
		format = kFmtNIB;
	else if (n == kSizeNB2Track)
		format = kFmtNB2;
	else // try lexing the header bytes to infer format
		format = A2GleanFileFormat(&header, sizeof(header));

	if (format == kFmtUnknown // still?  then test for HDV format
		and (st.st_size & 0x1FF) == 0
		and (st.st_size >> 9) >= 280
		and (st.st_size >> 9) <= 0xFFFF
	)	format = kFmtHDV;

	mTrackMax		= 35 - 1;
	mTrackSize		= kSizePhysTrack;
	mFilePath		= [fpath retain];
	REWIND(mOrigFD);
	REWIND(mWorkFD);

//	NSLog(@"disk file format = %d", format); //!!

	switch (format)
	{
	  default:		return NO;

	  case kFmtDO:	// fall thru
	  case kFmtPO:	[self _ImportDisk140K:format:volumeNum];  break;
	  case kFmtNB2:	// fall thru
	  case kFmtNIB:	[self _ImportDiskNIB:(st.st_size / 35)];  break;

	  case kFmt2IMG_PO:  case kFmt2IMG_DO:  case kFmt2IMG_NIB:
		if (header._2IMG.mLocked & 0x80)
			mContent = kA2DiskReadOnly;
		if (header._2IMG.mGotVolume & 1)
			volumeNum = header._2IMG.mVolNumber;
		lseek(mOrigFD,
			NSSwapLittleLongToHost(header._2IMG.mDataPos),
			SEEK_SET);

		if (format == kFmt2IMG_NIB)
			[self _ImportDiskNIB:kSizeNIBTrack];
		else
			[self _ImportDisk140K:format:volumeNum];
		break;
#if 0
	  case kFmtDiskCopy4:
		lseek(mOrigFD, 84, SEEK_SET);
		mTrackMax = 80 - 1;
		break;

	  case kFmtHDV:  case kFmt2IMG_HDV: //??
		break;
#endif
	}

	return YES;
}

//---------------------------------------------------------------------------

- (BOOL)Load:(NSString*)fpath //!!
{/*
	Attempts to load the specified disk image file into this disk drive.
	Returns whether successful.

	Any disk currently loaded is unloaded first.  Passing nil has the
	effect of unloading only, and is automatically successful.
*/
	[self Unload];
	if (fpath == nil)
		return YES;

//	errno = 0;
//	fpath = [fpath stringByStandardizingPath]; //??
	if (not [self _OpenDiskImageFile:fpath])
	{
		[self Unload];
		return NO;
	}

	return YES;
}

//---------------------------------------------------------------------------

- (NSString*)Label
{/*
	Returns a name for the currently loaded disk that's appropriate to
	display in the user interface.  Common file extensions are omitted.
	Returns an empty string if the drive is empty.
*/
	if (mFilePath == nil)
		return @"";

	NSString*	name = [mFilePath lastPathComponent];

	return [[name pathExtension] Matches:&g.rexDigits]? name :
		[name stringByDeletingPathExtension];
}

//---------------------------------------------------------------------------

+ (BOOL)ShouldShowFilename:(NSString*)path
{
#if 0
	NSString	*app, *type;
	[[NSWorkspace sharedWorkspace] getInfoForFile:path
		application:&app type:&type];
	NSLog(@"file type = '%@'", type);
#endif

	struct stat		st;

	if (not [path Stat:&st]) // can't stat?  then reject
		return NO;
/*
	if it's a bundle/package
		return NO
	else if it's a directory
		return YES
	else if it's not a readable file
		return NO
	else if we like the extension
		return YES
	else return whether we like the file size
*/
	if (st.st_mode & S_IFDIR) // pass non-bundle directories
		return YES; //return [NSBundle bundleWithPath:path] == nil;

	if (not [path IsReadableFile]) // reject unreadable files
		return NO;
	if ([path ExtensionMatches:&g.rexSuffixes5])
		return YES;

	off_t	tsz = st.st_size / 35;

	if (tsz == 0x1000)
		return YES;

	return tsz >= kSizeNB2Track  and  tsz <= kSizeNIBTrack;
}

//---------------------------------------------------------------------------

- (unsigned)Content
	{ return mContent; }
	// Returns this drive's current content (kA2DiskNone, etc.)

//---------------------------------------------------------------------------
@end
