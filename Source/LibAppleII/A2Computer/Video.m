/*	class A2Computer (category Video)

	Routines and tables for rendering frames of Apple II video.
*/
#import "LibAppleII-Priv.h"

@implementation A2Computer (Video)
//---------------------------------------------------------------------------

static unsigned DoubleBits(uint8_t b)
{/*
	Returns a 16-bit vector formed by replicating the bits of an 8-bit
	vector.  (Each 0 becomes 00, and each 1 becomes 11.)
*/
	static unsigned dbl[16] =
	{
		0x00,0x03,0x0C,0x0F, 0x30,0x33,0x3C,0x3F,
		0xC0,0xC3,0xCC,0xCF, 0xF0,0xF3,0xFC,0xFF,
	};

	return dbl[b>>4]<<8 | dbl[b&15];
}


static unsigned SpreadBits(uint8_t b)
	{ return DoubleBits(b) & 0x5555; }
	// Expands an 8-bit vector to 16, interleaving it with zeros.


static unsigned ShiftColor(unsigned c, int s)
	{ return c & 0xF0  |  0x0F & (((c&0x0F)*0x11)>>(s&3)); }
//	{ return ((c&0xF)*0x11) >> (s&3) & 0xF; }


static inline unsigned RandomByte(long* r)
	{ *r = *r * 157 % 32363;  return 0xFF & (*r>>8 ^ *r); }

//---------------------------------------------------------------------------

static void InitHPixelTables(void)
{
	uint8_t  colorOfBits[1 << 6] =
	{
		//       0    1    2    3    4    5    6    7
		/* 0 */ 0x0, 0x0, 0x0, 0x0, 0x2, 0x2, 0x3, 0x3,
		/* 1 */ 0x4, 0xC, 0x5, 0xD, 0x6, 0xE, 0x7, 0xF,
		/* 2 */ 0x0, 0x8, 0x9, 0x9, 0xA, 0xA, 0xB, 0xB,
		/* 3 */ 0xC, 0xC, 0xD, 0xD, 0xE, 0xE, 0xF, 0xF,
		/* 4 */ 0x0, 0x0, 0x1, 0x1, 0x3, 0x3, 0x3, 0x3,
		/* 5 */ 0x4, 0xC, 0x5, 0xD, 0x7, 0xF, 0x7, 0xF, // 55??
		/* 6 */ 0x0, 0x0, 0x9, 0x9, 0xB, 0xB, 0xB, 0xB,
		/* 7 */ 0xC, 0xC, 0xD, 0xD, 0xF, 0xF, 0xF, 0xF,
	};

	for (int i = 64;  --i >= 0;)
		colorOfBits[i] |= (i << 2 & 16); // monochrome bit

	for (int i = LENGTH(A2T.vidPix.Hd);  --i >= 0;)
		for (int j = 4;  --j >= 0;)
			((uint8_t*) (A2T.vidPix.Hd + i))[j] =
				ShiftColor(colorOfBits[i>>j & 0x3F], 2-j);

	for (int i = LENGTH(A2T.vidPix.Hs);  --i >= 0;)
	{
		unsigned	mono = 0;
			// the pattern of monochrome pixels _i_ represents

		for (int j = 0;  j <= 6;  j += 2)
			mono |= ("\0\3\0\2\4\7\4\6\0\7\0\6\0\7\0\6"[i>>j & 15]) << j;
		mono &= 0x1FF;

		for (int j = 4;  --j >= 0;)
			((uint8_t*) (A2T.vidPix.Hs + i))[j] =
				ShiftColor(((uint8_t*)(A2T.vidPix.Hd + mono))[j], 1);
	}
}

//---------------------------------------------------------------------------

static void InitPixelTables(void)
{/*
	Initializes the 'A2T.vpix' tables, which map video bit patterns to
	quartets of pixel values.

	The eight-bit pixel values used:
	  0x00-0F  HGR & DHGR colors, monochrome off
	    10-1F  HGR & DHGR colors, monochrome on
	    20-2F  GR & DGR colors (shades from 0 to 5 when in monochrome)
	    30-33  text: steady black, white; flashing black, white
*/
	InitHPixelTables();

	for (int i = 16;  --i >= 0;)
		A2T.vidPix.G[i] = 0x01010101 * (0x20 | i);

	for (int i = LENGTH(A2T.vidPix.Ts);  --i >= 0;)
	{
		uint8_t		*pix = (uint8_t*)(A2T.vidPix.Ts + i);

		pix[0] = pix[1] = 0x30 | (i    & 3);
		pix[2] = pix[3] = 0x30 | (i>>2 & 3);
	}

	for (int i = LENGTH(A2T.vidPix.Td);  --i >= 0;)
	{
		uint8_t		*pix = (uint8_t*)(A2T.vidPix.Td + i);

		pix[0] = 0x30 | (i    & 3);
		pix[1] = 0x30 | (i>>2 & 3);
		pix[2] = 0x30 | (i>>4 & 3);
		pix[3] = 0x30 | (i>>6 & 3);
	}
}

//---------------------------------------------------------------------------

static void InitBitPatterns(void)
{
	#include "glyphs.xbm"
		// defines: static char glyphs_xbm_bits[10*9*16]

	char	fix = ~glyphs_xbm_bits[0x20 * 9]; // bits from space character

	for (int ch = 128;  --ch >= 0;)
	{
		char*	xbm = glyphs_xbm_bits + (ch&0x70)*9 + (ch&15);

		for (int row = 0;  row < 8;  ++row, xbm += 16)
		{
			A2T.vidBits.T[1][row][128+ch] = 0x1555 ^ (
				A2T.vidBits.T[1][row][ch] =
					SpreadBits((*xbm ^ fix) & 0x7F) );
		}
	}

	for (int row = 8;  --row >= 0;)
	{
		uint16_t	*p0 = A2T.vidBits.T[0][row],
					*p1 = A2T.vidBits.T[1][row],
					*p2 = A2T.vidBits.T[2][row];

		memcpy(p1+0x40, p1+0xC0, 0x20*2); // Mouse Text
		memcpy(p1+0xC0, p1+0x80, 0x20*2); // capitals

		memcpy(p0, p1, 0x100*2);
		memcpy(p0+0x40, p0, 0x40*2);
		for (int i = 0x40;  i <= 0x7F;  ++i)
			p0[i] |= 0x2AAA;

		memcpy(p2, p0, 0x100*2);
		memcpy(p2+0xE0, p0+0xC0, 0x20*2);
	}

	for (long i = sizeof(A2T.vidBits.T)/2;  --i >= 0;)
		(A2T.vidBits.T[0][0])[i] <<= 2;

	for (int i = 0x80;  --i >= 0;)
	{
		uint32_t	sb = SpreadBits(i);

		A2T.vidBits.Hs[     i] =  sb           << 6;
		A2T.vidBits.Hs[0x80+i] = (sb | 0x2AAA) << 6;
	}
}

//---------------------------------------------------------------------------

+ (void)_InitVideo
{
	InitBitPatterns();
	InitPixelTables();
}

//---------------------------------------------------------------------------

- (void)RenderScreen:(void*)pixBase:(int32_t)rowBytes
{/*
	Renders a frame of Apple II video into the given 8-bit deep image.

	Argument 'pixBase' points to the upper-left or lower-left pixel;
	'rowBytes' is the stride in memory from one row to the next -- the
	delta between pixels that are vertically adjacent.
*/
	PixelGroup*		pout = (PixelGroup*) pixBase;

	rowBytes /= sizeof(*pout);

	if (mHalts & kfHaltNoPower) // then power is off; render a screen of snow
	{
		for (int v = 192;  --v >= 0;  pout += rowBytes)
		{
			for (int h = 141;  (h -= 4) >= 0;)
			{
				enum {		kWhite4 = 0x2F * 0x01010101 };
				unsigned	r = A2Random16();

				r &= r >> 4 & r >> 8;
				(pout+h)[0] = kWhite4 & -(r&1);  r >>= 1;
				(pout+h)[1] = kWhite4 & -(r&1);  r >>= 1;
				(pout+h)[2] = kWhite4 & -(r&1);  r >>= 1;
				(pout+h)[3] = kWhite4 & -(r&1);
			}
		}
		return;
	}

	//------------------------------------------------------------
	// Otherwise the power is on, so render a real screen of
	// Apple II video.

	#define SETUP_FOR(TYPE) \
		enum {	kMask  = (LENGTH(A2T.vidPix.TYPE) - 1) << 2, \
				kShift = kShift##TYPE }; \
		char*	tpix = (char*)(A2T.vidPix.TYPE);

	#define BAM_(I)		pout[I] = *(PixelGroup*)(tpix + (bits & kMask))

	#define BAM(I)		BAM_(I);  bits >>= kShift

	#define HLOOP \
		for (v -= 21*192;  (v+=192) < 0;  pout += 7, pin += 2)

	#define GCASE(N) \
		case kfUpRow + kfMIXED + (N): \
		case kfUpRow + (N): \
		case kfLoRow + (N)

	#define TCASE(N) \
		case kfLoRow          + kfMIXED + (N): \
		case kfUpRow + kfTEXT           + (N): \
		case kfLoRow + kfTEXT           + (N): \
		case kfUpRow + kfTEXT + kfMIXED + (N): \
		case kfLoRow + kfTEXT + kfMIXED + (N)

	enum
	{
		kAux    = 0x2000,
		kfUpRow = 1 << 5,
		kfLoRow = 0,

		kShiftTs = 4,   kShiftHs = 4,
		kShiftTd = 8,   kShiftHd = 4,
	};

	rowBytes -= 20 * 7;

	for (int v = -1;  ++v < 192;  pout += rowBytes)
	{
		uint32_t	bits = mFlags; //!! mVideoFlags[v];
		uint8_t*	pin = (mMemory->RAM[0][0]) +
						((v<<4 & 0x380) + 40*(v>>6));
		int			dispPage =
						0x400 << (2 >> (bits>>ksPAGE2v & 3) & 1);
						// = either 0x400 or 0x800

		switch ( bits & 0x1F  |  ((v>>5)-5) & 0x20 )
		{
		//------------------------------------- 40-column text

			default:
			TCASE( 0                              ):
			TCASE(                     + kfSINGRES):
			TCASE(          + kfHIRESv            ):
			TCASE(          + kfHIRESv + kfSINGRES):
			{
				SETUP_FOR(Ts)
				uint16_t*		tbits;

				tbits = A2T.vidBits.T[bits>>ksALTCHAR & 1][v&7];
				pin += dispPage;
				*pout++ = 0;

				HLOOP
				{
					bits = tbits[pin[0]];
					BAM(0);  BAM(1);  BAM(2);
					bits |= tbits[pin[1]] << 2;
					BAM(3);  BAM(4);  BAM(5);  BAM_(6);
				}
				*pout-- = 0;
			}	break;

		//------------------------------------- 80-column text

			TCASE(+ kf80COL                       ):
			TCASE(+ kf80COL            + kfSINGRES):
			TCASE(+ kf80COL + kfHIRESv            ):
			TCASE(+ kf80COL + kfHIRESv + kfSINGRES):
			{
				SETUP_FOR(Td)
				uint16_t*		tbits;

				tbits = A2T.vidBits.T[bits>>ksALTCHAR & 1][v&7];
				pin += dispPage;
				*pout++ = 0;

				HLOOP
				{
					bits = tbits[pin[kAux+0]];
					BAM(0);
					bits |= tbits[pin[0]] << 6;
					BAM(1);  BAM(2);
					bits |= tbits[pin[kAux+1]] << 4;
					BAM(3);  BAM(4);
					bits |= tbits[pin[1]] << 2;
					BAM(5);  BAM_(6);
				}
				*pout-- = 0;

			}	break;

		//------------------------------------- 40-column GR

			GCASE( 0                              ):
			GCASE(                     + kfSINGRES):
			GCASE(+ kf80COL            + kfSINGRES):
			{
				pin += dispPage;
				*pout++ = 0;

				HLOOP
				{
					pout[0] = pout[1] = pout[2] = pout[3] =
						A2T.vidPix.G[pin[0] >> (v&4) & 15];

					((uint16_t*)pout)[7] = pout[4] = pout[5] = pout[6] =
						A2T.vidPix.G[pin[1] >> (v&4) & 15];
				}
				*pout-- = 0;

			}	break;

		//------------------------------------- 80-column GR

			GCASE(+ kf80COL                       ):
			{
				pin += dispPage;
				*pout++ = 0;

				HLOOP
				{
					pout[0] = pout[1] =
						A2T.vidPix.G[pin[kAux+0] >> (v&4) & 15];

					((uint8_t*)pout)[7] = pout[2] = pout[3] =
						A2T.vidPix.G[pin[0] >> (v&4) & 15];

					((uint16_t*)pout)[7] = pout[4] = pout[5] =
						A2T.vidPix.G[pin[kAux+1] >> (v&4) & 15];

					((uint8_t*)pout)[21] = ((uint16_t*)pout)[11] = pout[6] =
						A2T.vidPix.G[pin[1] >> (v&4) & 15];
				}
				*pout-- = 0;

			}	break;

		//------------------------------------- HGR

			GCASE(          + kfHIRESv            ):
			GCASE(          + kfHIRESv + kfSINGRES):
			GCASE(+ kf80COL + kfHIRESv + kfSINGRES):
			{
				SETUP_FOR(Hs)

				pin += dispPage<<4 | (v&7)<<10;
				bits = 0;

				HLOOP
				{
					bits |= A2T.vidBits.Hs[pin[0]];
					BAM(0);  BAM(1);  BAM(2);
					bits |= A2T.vidBits.Hs[pin[1]] << 2;
					BAM(3);  BAM(4);  BAM(5);  BAM(6);
				}
				BAM(0);  BAM_(1);

			}	break;

		//------------------------------------- DHGR

			GCASE(+ kf80COL + kfHIRESv            ):
			{
				SETUP_FOR(Hd)

				pin += dispPage<<4 | (v&7)<<10;
				bits = 0;

				HLOOP
				{
					bits |= (pin[kAux+0] & 0x7F) << 6;
					BAM(0);
					bits |= (pin[0] & 0x7F) << 9;
					BAM(1);  BAM(2);
					bits |= (pin[kAux+1] & 0x7F) << 8;
					BAM(3);  BAM(4);
					bits |= (pin[1] & 0x7F) << 7;
					BAM(5);  BAM(6);
				}
				BAM(0);  BAM_(1);

			}	break;

		} // end of switch on video flags

	} // end of for (v...)
}

//---------------------------------------------------------------------------
@end
