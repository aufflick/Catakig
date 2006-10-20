/*	LibAppleII-Priv.h

	Private definitions for source files in the LibAppleII library.  Client
	applications should normally ignore this header.  The public API is all
	defined in "LibAppleII.h".
*/
#import "LibAppleII.h"
#import "MyUtils.h"

//---------------------------------------------------------------------------
//	Macros

#define LENGTH(ARRAY_1D) \
	( sizeof(ARRAY_1D) / sizeof(ARRAY_1D[0]) )
	// number of elements in a one-dimensional array

#define DFLAG(SHIFT, NAME) \
	ks##NAME = (SHIFT),  kf##NAME = 1U << ks##NAME,
	// defines bit-flag constants with ease

#define QCOPY(DEST, SRC, LEN) do { \
	for (long i = ((long)(LEN))>>2;  --i >= 0;) \
		((uint32_t*)(DEST))[i] = ((const uint32_t*)(SRC))[i]; \
	} while (0)

#define IS_OPEN(FD)		((FD) >= 0)
#define CLOSE(FD)		(close(FD), -1)
#define REWIND(FD)		lseek((FD), 0, SEEK_SET)
#define TELL(FD)		lseek((FD), 0, SEEK_CUR)

//---------------------------------------------------------------------------
//	Handy integer constants.

enum
{
	//-------------------------------------------------------------
	// File format identifiers

	kFmtUnknown = 0,

	kFmtDO,      kFmtPO,      kFmtNIB,      kFmtHDV,
	kFmt2IMG_DO, kFmt2IMG_PO, kFmt2IMG_NIB, kFmt2IMG_HDV,

	kFmtGZip, kFmtBZip,
	kFmtSHK, kFmtBSC, kFmtBinaryII,
	kFmtNB2, kFmtDiskCopy4, // kFmtCopyIIPlus, kFmtFDI,

	//-------------------------------------------------------------
	// Apple II soft-switch flags (used in A2Computer field 'mFlags').

	DFLAG( 0, TEXT)			// flags affecting video display
	DFLAG( 1, MIXED)
	DFLAG( 2, 80COL)
	DFLAG( 3, SINGRES)			// (inverse of "DHIRES" flag)
	DFLAG( 4, HIRESv)
	DFLAG( 5, PAGE2v)
	DFLAG( 6, 80STOREv)
	DFLAG( 7, ALTCHAR)

	DFLAG( 8, RAMWRT)		// flags affecting memory writes
	DFLAG( 9, LCWRTlo)
	DFLAG(10, LCWRThi)

	DFLAG(11, ALTZP)		// flags affecting memory reads and writes
	DFLAG(12, LCBANK2)
	DFLAG(13, HIRESm)
	DFLAG(14, PAGE2m)
	DFLAG(15, 80STOREm)

	DFLAG(16, RAMRD)		// flags affecting memory reads
	DFLAG(17, LCRD)
	DFLAG(18, C3ROM)
	DFLAG(19, CXROM)
	DFLAG(20, HotSlot)
//	DFLAG(21, HotSlot1)
//	DFLAG(22, HotSlot2)

	ksWMap = ksRAMWRT,  kmWMap = (1 << (3+5)) - 1,
	ksRMap = ksALTZP,   kmRMap = (1 << (5+7)) - 1,

	DFLAG(28, XYMASK)		// IIc flags
	DFLAG(29, VBLMASK)
	DFLAG(30, X0EDGE)
	DFLAG(31, Y0EDGE)

	//-------------------------------------------------------------
	// Miscellany

	DFLAG(0, HaltNoPower)  // flags for 'mHalts' field of A2Computer
	DFLAG(1, HaltReset)

	kTapRatio		= 5,
	kFilterRes		= 128,
	kFilterSize		= kFilterRes * kTapRatio,

	kBadFD			= -1,
	kLightSustain	= 5 << 4,
	k64KB			= 1UL << 16,
//	k1MB			= 1UL << 20,
};

//---------------------------------------------------------------------------
//	Type definitions.

typedef int				fd_t;			// file descriptor
typedef uint32_t		PixelGroup;		// a run of four 8-bit pixels
typedef struct A2IWM	A2IWM;
//typedef struct A2PSG	A2PSG;

typedef struct A2Memory
{
	uint8_t
		RAM[8][2][0x2000],	// main and aux RAM (64 KB each)
		ROM[2][0x4000],		// up to 2 banks of ROM

		mixedSlotROM[0x800],
		WOM[0x800],			// write-only memory (for ROM writes)
		pad_[0x1000],		// pad struct up to next 0x2000 boundary

		diskBuffers[4][0x2000];

} A2Memory;

//---------------------------------------------------------------------------

extern struct A2PrivateTables
{
	uint8_t			tPHP[1 << 12];
	uint16_t		tPLP[0x100],
					tROL[0x100 << 3],
					tROR[0x100 << 3];
	int16_t			tADC [0xC40], tSBC [0xC40], // for 65c02
					tADCo[0xC40], tSBCo[0xC40]; // for 6502
	int8_t			rmaps[kmRMap+1][0x80+1],
					wmaps[kmWMap+1][0x80+1];
	struct {
		uint32_t	flat;
		uint32_t	delta[kFilterSize];
	}				audio;
	struct {
		uint16_t	T[3][8][0x100]; // [charset][row][screen code] -> 14b
		uint32_t	Hs[0x100]; // 8b -> 14b
	}				vidBits;
	struct {
		PixelGroup	Ts[1<<(2*2)], Hs[1<<(5*2)], G[16],
					Td[1<<(4*2)], Hd[1<<(6+3)];
	}				vidPix;

	uint8_t			curTime[32];

} A2T;

//---------------------------------------------------------------------------
//	Prototypes of global functions.

#ifdef __cplusplus
extern "C" {
#endif

BOOL		A2AppendResourceFile(fd_t fout, NSString* resName);
void		A2DumpArray(const char*, const void*, size_t, int);
unsigned	A2GleanFileFormat(const void* header, size_t size);
unsigned	A2HitIWM(A2IWM* iwm, unsigned ea, unsigned d);
void*		A2MemoryMap(void* addr, size_t size, fd_t fd, off_t foff);
fd_t		A2OpenTempFile(size_t size);
unsigned	A2Random16(void);
void		A2WriteEntireFile(fd_t fout, fd_t fin);
void		A2WriteFiller(fd_t fout, char fillValue, size_t reps);

#ifdef __cplusplus
}
#endif

//---------------------------------------------------------------------------
