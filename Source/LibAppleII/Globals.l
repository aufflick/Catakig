/*	Globals.l (.m)
*/
%option 8bit never-interactive noyywrap prefix="A2Globals_"
%{
#import "LibAppleII-Priv.h"
#import "A2DiskDrive.h"

int yylex(void);
%}

ANY			[\0-\xFF]
BSC			[^F]*FiLeStArTfIlEsTaRt[ \t]*[\r\n]
NIB			[\x96-\xFF]+
DiskCopy4	[\0-\x3F]{ANY}{79}[\0-\3][\x12\x22\x24]\1\0
_2IMG		2IMG{ANY}{4}\x40\0[\0\1]\0
_2IMG_PO	{_2IMG}\1{ANY}{7}(\x18\1|\0\0)\0\0
_2IMG_HDV	{_2IMG}\1{ANY}{7}([\x19-\xFF]\1|{ANY}[\2-\xFF])\0\0

%%

{_2IMG}\0				return kFmt2IMG_DO;
{_2IMG}\2				return kFmt2IMG_NIB;
{_2IMG_PO}				return kFmt2IMG_PO;
{_2IMG_HDV}				return kFmt2IMG_HDV;

N\xF5F\xE9l\xE5			return kFmtSHK;
\x1F\x8B[\0-\x9]		return kFmtGZip;
BZh						return kFmtBZip;
{DiskCopy4}				return kFmtDiskCopy4;
{BSC}					return kFmtBSC;
\x0A\x47\x4C			return kFmtBinaryII;
{NIB}					return kFmtNIB;

{ANY}					return kFmtUnknown;

%%
//---------------------------------------------------------------------------

struct A2Globals  A2G =
{
	.defaultModel		= kA2ModelIIp,
	.defaultExtraRAM	= 0, // sensible values: 0, 18-21

	.standardColors = // ... in a 12-bit RGB format
	{
		0x000, 0xC03, 0x00A, 0xB0F,
		0x060, 0x666, 0x06C, 0x0CF,
		0x630, 0xF60, 0x666, 0xF9F,
		0x0F0, 0xFF0, 0x3F9, 0xFFF,
	},

/*
	.flagsSSC1			= 0xED78,
	.flagsSSC2			= 0xED78,
	.flagsEpsonRX80		= 0,
	.printerDataMask	= 0x7F,
*/
};

struct A2PrivateTables  A2T =
{
	#include "A2T.h"
};

//---------------------------------------------------------------------------

unsigned A2GleanFileFormat(const void* header, size_t size)
{/*
	Infers a file's format from its header bytes.
*/
	YY_BUFFER_STATE		bufState = yy_scan_bytes(header, size);
	unsigned			format = yylex();

	yy_delete_buffer(bufState);
	return format;
}

//---------------------------------------------------------------------------

unsigned A2Random16(void)
{/*
	Returns a pseudo-random 16-bit integer.  The algorithm here is an
	embellishment of one described in:

		"Efficient and Portable Combined Random Number Generators"
		by Pierre L'Ecuyer
		Communications of the ACM
		Vol 31, #6, June 1988
*/
	enum {
		m = 2147483563, a = 40014, q = 53668, r = 12211,
	//	m = 2147483399, a = 40692, q = 52774, r =  3791,
	};
	static long		v = 1;
	ldiv_t			d = ldiv(v, q);

	if ((v = d.rem * a - d.quot * r) <= 0)
		v += m;
	return (v ^ v>>16) & 0xFFFF;
}

//---------------------------------------------------------------------------

void* A2MemoryMap(void* addr, size_t size, fd_t fd, off_t foff)
{/*
	Maps or re-maps a range of the process address space to a range within
	an open file, or to new memory if no file is given.  If passed a file,
	we assume the file was opened for both reading and writing.

	Returns the same results as 'mmap'.
*/
	int		flags = MAP_SHARED // or MAP_PRIVATE??
				| (fd < 0? MAP_ANON : MAP_FILE);

	if (addr != nil)
	{
		flags |= MAP_FIXED;
	//	msync(addr, size, MS_SYNC + MS_INVALIDATE); // need??
		munmap(addr, size);
	}
	return mmap(addr, size, PROT_READ + PROT_WRITE, flags, fd, foff);
}

//---------------------------------------------------------------------------

fd_t A2OpenTempFile(size_t size)
{/*
	Creates and opens a temporary file for reading and writing.  Also sets
	the file's size fo _size_, if non-zero.  Returns a valid file descriptor
	on success, or an invalid one (< 0) on failure.
*/
	FILE*   fptr;
	fd_t	fd;

	if (NULL == (fptr = tmpfile())) // then failed to create file
		return kBadFD;

	fd = dup(fileno(fptr));
	fclose(fptr);
	if (fd < 0  or  size < 1  or  ftruncate(fd, size) == 0)
		return fd;

//	Reaching here: file was created successfully, but the resize failed.
	return CLOSE(fd);
}

//---------------------------------------------------------------------------

void A2WriteFiller(fd_t fout, char fillValue, size_t reps)
{/*
	Writes fill bytes to the given file.
*/
	enum {  kChunk = 1<<9 };
	char	buf[kChunk];

	memset(buf, fillValue, kChunk);
	for (;  reps >= kChunk;  reps -= kChunk)
		write(fout, buf, kChunk);
	if (reps > 0)
		write(fout, buf, reps);
}

//---------------------------------------------------------------------------

void A2WriteEntireFile(fd_t fout, fd_t fin)
{/*
	Writes all the remaining bytes from one open file to another.
*/
	char	buf[1<<9];

	for (int n;  (n = read(fin, buf, sizeof(buf))) > 0;)
		write(fout, buf, n);
}

//---------------------------------------------------------------------------

BOOL A2AppendResourceFile(fd_t fout, NSString* resName)
{/*
	Searches the application bundle for a given resource file, then
	appends its content to the given destination file.
*/
	NSString*   fpath;
	fd_t		fin;

	fpath = [resName PathForResource];
	if (fpath == nil)
		return NO;

	fin = open([fpath fileSystemRepresentation], O_RDONLY);
	if (fin < 0)
		return NO;

	A2WriteEntireFile(fout, fin);
	close(fin);
	return YES;
}

//---------------------------------------------------------------------------

void A2DumpArray(const char* name, const void* arr, size_t sz, int type)
{/*
	Dumps an array of integers to a text file, in the format of C static
	initializers.
*/
	static FILE*	fout = NULL;
	char*			p = (char*)arr;
	int				esz = abs(type);

	if (fout == NULL)
		fout = fopen(
			[[@"~/Desktop/A2T.h" stringByExpandingTildeInPath]
				fileSystemRepresentation], "w");

	fprintf(fout, ".%s = { ", name);

	for (long n = sz/esz;  --n >= 0;  p += esz)
	{
		switch (type)
		{
		  case  1:	fprintf(fout, "%u," , *(uint8_t *)p);  break;
		  case -1:	fprintf(fout, "%d," , *(int8_t  *)p);  break;
		  case  2:	fprintf(fout, "%u," , *(uint16_t*)p);  break;
		  case -2:	fprintf(fout, "%d," , *(int16_t *)p);  break;
		  case  4:	fprintf(fout, "%lu,", *(uint32_t*)p);  break;
		  case -4:	fprintf(fout, "%ld,", *(int32_t *)p);  break;
		}
	}
	fprintf(fout, " },\n");
}

//---------------------------------------------------------------------------

unsigned A2HitIWM(A2IWM* iwm, unsigned ea, unsigned d)
{
#define INC_THETA \
	if ((dr->mTheta += 1) >= dr->mTrackSize) \
		dr->mTheta = 0
#define WRITING  (ea & 32)

	enum
	{
		DFLAG(0, CA0)			DFLAG(4, Spinning)
		DFLAG(1, CA1)			DFLAG(5, ActiveDrive)
		DFLAG(2, CA2)			DFLAG(6, Q6)
		DFLAG(3, LSTRB)			DFLAG(7, Q7)
	
		kfQ67		= kfQ6 | kfQ7,
	};

	unsigned		f  = iwm->flags;
	A2DiskDrive*	dr = iwm->drive[f>>ksActiveDrive & 1];

	if (ea & 1) // we're hitting an odd address
	{
		f |= 1U << (ea >> 1 & 7);

		if ((ea & 8) == 0) // then stepper motor moves, maybe
		{
			int		ti  = dr->mTrackIndex,
					tiDelta = "=<><>=<>"[ea&6 | ti&1] - '=';

			if (tiDelta != 0)
				[dr SeekTrack:(ti + tiDelta)];
		}

		if (WRITING  and  (f & kfQ67) == kfQ67)
		{
			if (not (f & kfSpinning))
				iwm->modeReg = d;
			else if (dr->mContent == kA2DiskReadWrite)
			{
				dr->mDiskModified = YES;
				dr->mTrackBase[dr->mTheta] = d | 0x80;
				INC_THETA;
			}
		}
	}
	else // we're hitting an even address
	{
		f &= ~(1U << (ea >> 1 & 7));

		if (not WRITING)
		{
			if ((f & kfQ67) == 0) // return disk data
			{
				d = dr->mTrackBase[dr->mTheta];
				INC_THETA;
			}
			else if (f & kfQ6) // return status reg
				d = (dr->mContent == kA2DiskReadOnly)<<7
					| (f&kfSpinning)<<1
					| (iwm->modeReg & 0x1F);
			else // return handshake reg
				d = 0xC0;
		}
	}

	if (f & kfSpinning)
		iwm->lights = kLightSustain | (1 + (f>>ksActiveDrive & 1));
	iwm->flags = f;
	return d;

#undef INC_THETA
#undef WRITING
}

//---------------------------------------------------------------------------
