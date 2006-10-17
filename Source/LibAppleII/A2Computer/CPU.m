/*	class A2Computer (category CPU)

	Routines and tables for emulating the 65c02 microprocessor, and the
	low-level I/O behavior of the Apple II.
*/
#import "LibAppleII-Priv.h"
#import "CPU-Macros.h"
//mport "CPU-Journal.h"

@implementation A2Computer (CPU)
//---------------------------------------------------------------------------

#if !JOURNALING
	#define JOURNAL_OP
	#define JOURNAL_EA
#endif

enum
{
	DFLAG(0, D)
	DFLAG(1, C)
	DFLAG(2, V)
	DFLAG(3, ZF)		// when ZF = 1, forces Z = 1
	DFLAG(4, LSB)

	kfCD	= kfC | kfD,
	kfDV	= kfD | kfV,
	kfCDV	= kfC | kfDV,

	kfN		= 0x80 << ksLSB,
	kmZ8	= 0xFF << ksLSB,
	kmPHP	= LENGTH(A2T.tPHP) - 1,

//	kCyclesPerStep	= 17030, // CPU cycles in one time step (262 * 65)
};

static uint8_t		gOldTimer,		// residual cycles from last step
					gSpkrState;		// speaker state: 0 or 0xFF

static uint32_t		gSpkrOut[kA2SamplesPerStep + kTapRatio - 1];

//---------------------------------------------------------------------------

static void FillMemoryMapRow(int8_t map[0x81], uint32_t f, BOOL wmap)
{/*
	Utility function used by +_InitCPU (below) to initialize one row of a
	memory mapping table -- either 'A2T.rmaps' or 'A2T.wmaps'.
*/
#define ORAM(BANK) \
	offsetof(A2Memory, RAM[page>>5][BANK][page<<8 & 0x1F00])

#define OROM(BANK) \
	offsetof(A2Memory, ROM[BANK][(page-0xC0)*256L])

#define PUT_PAGES(PGLO, PGHI, OFFSET) \
	for (int page = PGLO;  page <= PGHI;  page += 2) \
		map[page/2] = ((OFFSET) - ozp - 256L*page) / kChunkSize

	enum {		kChunkSize = 1L << 11, // = 0x800
				OWOM = offsetof(A2Memory, WOM),
	};
	int			ramrw	= f>>(wmap? ksRAMWRT : ksRAMRD) & 1,
				altzp	= f>>ksALTZP & 1,
				cxrom	= f>>ksCXROM & 1,
				hotSlot	= f>>ksHotSlot & 7;
	long		ozp		= offsetof(A2Memory, RAM[0][altzp][0]);

	map[0] = 0;
	map[0x80] = -(k64KB / kChunkSize);

	PUT_PAGES(0x02, 0xBF, ORAM(ramrw));
	if (f & kf80STOREm)
	{
		int		page2 = f>>ksPAGE2m & 1;

		PUT_PAGES(0x04, 0x07, ORAM(page2));
		if (f & kfHIRESm)
			PUT_PAGES(0x20, 0x3F, ORAM(page2));
	}

	if (wmap) // then setting write-map
	{
		PUT_PAGES(0xC0, 0xFF, OWOM);
	}
	else if (hotSlot == 0) // then setting read-map on IIc
	{
		PUT_PAGES(0xC0, 0xFF, OROM(cxrom));
	}
	else // setting read-map on IIe or earlier
	{
		int		c3rom = f>>ksC3ROM & 1;
		BOOL	c8_internal;

		PUT_PAGES(0xD0, 0xFF, OROM(0));
		PUT_PAGES(0xC0, 0xC7, OROM(!cxrom));
		PUT_PAGES(0xC3, 0xC3, OROM(!cxrom & c3rom));

		if (cxrom) // CXROM on, C3ROM irrelevant
			c8_internal = YES;
		else if (c3rom) // CXROM off, C3ROM on
			c8_internal = NO;
		else // CXROM and C3ROM both off
			c8_internal = YES; //!! (hotSlot == 3);

		if (c8_internal)
			PUT_PAGES(0xC8, 0xCF, OROM(0));
		else
			PUT_PAGES(0xC8, 0xCF, OROM(1) + 0x800*(hotSlot-1));
	}

	if (f & (wmap? kfLCWRThi : kfLCRD)) // then $D0-FF sees LC RAM
	{
		int		shiftDx = (f & kfLCBANK2)? 0x1000 : 0;

		PUT_PAGES(0xD0, 0xDF, ORAM(altzp) - shiftDx);
		PUT_PAGES(0xE0, 0xFF, ORAM(altzp));
	}

#undef ORAM
#undef OROM
#undef PUT_PAGES
}

//---------------------------------------------------------------------------

static int16_t FixAP(uint16_t oap)
{
	unsigned	p = kfLSB;

	if (oap & 0x80)		p |= 0x80;
	if (oap & 0x40)		p |= kfV;
	if (oap & 0x08)		p |= kfD;
	if (oap & 0x02)		p |= kfZF;
	if (oap & 0x01)		p |= kfC;

	return (p << 8) | (oap >> 8);
}

//---------------------------------------------------------------------------

static BOOL InitADC_SBC(void)
{
//	Fill in the ADC and SBC lookup tables in global structure 'A2T'.

	static uint8_t tbl
		[2/*D*/][2/*C*/][256/*B*/][2/*ADC,SBC*/][2/*A,P*/][256/*A*/];
	static uint16_t		tadc[0xD00], tsbc[0xD00];
	BOOL				adc_good = YES, sbc_good = YES;
	FILE*				fin;

	fin = fopen([[[[NSBundle mainBundle] bundlePath]
		stringByAppendingPathComponent:@"../ADSBC.dat"]
		fileSystemRepresentation], "rb");
	if (fin == NULL)
		return NO;

	fread(tbl, 1, sizeof(tbl), fin);
	fclose(fin);
	memset(tadc, 0xFF, sizeof(tadc));
	memset(tsbc, 0xFF, sizeof(tsbc));

	for (int i = 256;  --i >= 0;)
		tadc[i] = tsbc[i] = 128 + 2 *
			( (i & 0x80)*15/4 + (i & 0x70)*2 + (i & 0xF) );

	for (int d = 2;  --d >= 0;)
		for (int c = 2;  --c >= 0;)
			for (int b = 256;  --b >= 0;)
				for (int a = 256;  --a >= 0;)
				{
					unsigned	adc, sbc, i;

					adc = tbl[d][c][b][0][0][a] << 8
						| tbl[d][c][b][0][1][a] & 0xCB;
					sbc = tbl[d][c][b][1][0][a] << 8
						| tbl[d][c][b][1][1][a] & 0xCB;

					i = tadc[a] + tadc[b] + 2*c + d;
					if (tadc[i] == 0xFFFF)
						tadc[i] = adc;
					else if (tadc[i] != adc)
						adc_good = NO;

					i = tsbc[a] + tsbc[b^0xFF] + 2*c + d;
					if (tsbc[i] == 0xFFFF)
						tsbc[i] = sbc;
					else if (tsbc[i] != sbc)
						sbc_good = NO;
				}

	NSLog(@"adc_good? %c  sbc_good? %c", "ny"[adc_good], "ny"[sbc_good]);

	if (adc_good  and  sbc_good)
	{
		memcpy(A2T.tADC, tadc, 2*256);
		memcpy(A2T.tSBC, tsbc, 2*256);

		for (int i = 256;  i < LENGTH(A2T.tADC);  ++i)
		{
			A2T.tADC[i] = FixAP(tadc[i]);
			A2T.tSBC[i] = FixAP(tsbc[i]);
		}

		memcpy(A2T.tADCo, A2T.tADC, sizeof(A2T.tADC));
		memcpy(A2T.tSBCo, A2T.tSBC, sizeof(A2T.tSBC));

		if (NO) for (int i = 256;  i < LENGTH(A2T.tADCo);  i += 2)
		{
			A2T.tADCo[i+1] =
				A2T.tADCo[i  ] & 0xFF00 |
				A2T.tADCo[i+1] & 0x00FF;

			A2T.tSBCo[i+1] =
				A2T.tSBCo[i  ] & 0xFF00 |
				A2T.tSBCo[i+1] & 0x00FF;
		}
	}

	return YES;
}

//---------------------------------------------------------------------------

+ (void)_InitCPU
{/*
	Initializes various lookup tables used in method '-RunForOneStep',
	defined below.  Called only once, from '+initialize'.
*/

#if JOURNALING
	atexit(LogJournal);
#endif

#if 0
	for (int p = LENGTH(A2T.tPHP);  --p >= 0;)
	{
		uint8_t		php = 0x30; // the true P reg: NV1BDIZC

		if (p & kfC)	php |= 0x01;
		if (Z_SET)		php |= 0x02;
		if (p & kfD)	php |= 0x08;
		if (p & kfV)	php |= 0x40;
		if (p & kfN)	php |= 0x80;

		A2T.tPHP[p] = php;
	}

	for (int i = LENGTH(A2T.tPLP);  --i >= 0;)
	{
		unsigned  plp = kfLSB; // assume Z = 0 (datum non-zero)

		if (i & 0x01)	plp |= kfC;
		if (i & 0x02)	plp |= kfZF;
		if (i & 0x08)	plp |= kfD;
		if (i & 0x40)	plp |= kfV;
		if (i & 0x80)	plp |= kfN;

		A2T.tPLP[i] = plp;
	}

	for (long i = LENGTH(A2T.tROR), j;  --i >= 0;)
	{
		j = i>>3 | (i&kfC)<<7;
		j = (j<<9 | j) << 3;
		A2T.tROR[i] = j&0xFF0 | i&kfDV | j>>2&kfC;
		j >>= 7;
		A2T.tROL[i] = j&0xFF0 | i&kfDV | j>>2&kfC;
	}

	InitADC_SBC();

	for (long i = kmRMap+1;  --i >= 0;)
		FillMemoryMapRow(A2T.rmaps[i], i<<ksRMap, NO);
	for (long i = kmWMap+1;  --i >= 0;)
		FillMemoryMapRow(A2T.wmaps[i], i<<ksWMap, YES);

	A2DumpArray("tADC", A2T.tADC, sizeof(A2T.tADC), -2);
	A2DumpArray("tSBC", A2T.tSBC, sizeof(A2T.tSBC), -2);
	A2DumpArray("tADCo", A2T.tADCo, sizeof(A2T.tADCo), -2);
	A2DumpArray("tSBCo", A2T.tSBCo, sizeof(A2T.tSBCo), -2);
	A2DumpArray("tROL", A2T.tROL, sizeof(A2T.tROL),  2);
	A2DumpArray("tROR", A2T.tROR, sizeof(A2T.tROR),  2);
	A2DumpArray("tPLP", A2T.tPLP, sizeof(A2T.tPLP),  2);
	A2DumpArray("tPHP", A2T.tPHP, sizeof(A2T.tPHP),  1);
	A2DumpArray("rmaps", A2T.rmaps, sizeof(A2T.rmaps), -1);
	A2DumpArray("wmaps", A2T.wmaps, sizeof(A2T.wmaps), -1);
#endif
}

//---------------------------------------------------------------------------

- (void)RunForOneStep:(uint8_t [])audioOut
{/*
	Executes 65c02 instructions for one time step: about 17,030 CPU cyles,
	or 1/60th of an emulated second.  Also computes the 8-bit audio waveform
	for the time step and writes it to the array 'audioOut'.

	No attempt is made here to keep emulation time in sync with real time.
	It's up to the library user to call this method every 60th of a second,
	and keep the audio stream playing.
*/
	if (mHalts) // != 0, then emulation is forbidden just now
	{
		[self _DefaultAudio:audioOut:kA2SamplesPerStep];
		return;
	}

	unsigned	p  = mP;
	unsigned	pc = mPC;
	int32_t		t = gOldTimer;
	uint8_t		*zp;
	int8_t		*rmap, *wmap;

	REMAP_(mFlags);
	mCycles += 17030; // CPU cycles per step

	for (int scanLine = 0;  scanLine < 262;)
	{
		uint32_t	d;
		unsigned	ea;
		uint8_t		curOp;

		mVideoFlags[scanLine++] = mFlags;
		t -= 65;
		--pc;

	//----------------------------------------------------------------
	  NewOpcode:

		d = READ_PC; // = next opcode to interpret
		JOURNAL_OP

		switch (t >> 7 & d)
		{
		/*--------------------------------------------------------
			BRK, JSR, JMP, RTI, and RTS.
		*/
		#define PHPC2	ea = pc+2;  PUSH(ea>>8);  PUSH(ea)
		#define PLPC	pc = PULL;  pc |= PULL<<8

		case 0x00:	if (t >= 0)
						continue; // next scan line
		/* BRK */	PHPC2;  PHP;
					mI = 4;  ea = 0xFFFE;  ++t;
					goto IndirJMP;

		case 0x7C:	EAAX;  goto IndirJMP;
		case 0x6C:	EAA; // and fall into IndirJMP
		IndirJMP:   pc  = READ(ea) - 1;  ++ea;  t += 6;
					pc += READ(ea) << 8;
					goto NewOpcode;

		case 0x20:  PHPC2;  t += 3; // and fall into JMP-abs
		case 0x4C:	EAA;  pc = ea - 1;  t += 3;  goto NewOpcode;

		case 0x60:	PLPC;  t += 6;  goto NewOpcode;
		case 0x40:	PLP;  PLPC;  --pc;  t += 6;  goto NewOpcode;

		#undef PHPC2
		#undef PLPC

		/*--------------------------------------------------------
			No-op instructions.
		*/
		case 0x54: case 0xD4: case 0xF4:	++t;
		case 0x44:							++t;
		case 0x02: case 0x22: case 0x42:
		case 0x62: case 0x82: case 0xC2:
		case 0xE2:							++pc;
		case 0xEA:							t += 2;  goto NewOpcode;

		case 0x5C:				t += 4;
		case 0xDC: case 0xFC:	t += 4;  pc += 2;  goto NewOpcode;

		default:
		CASE16(0x03,16):  CASE16(0x07,16):
		CASE16(0x0B,16):  CASE16(0x0F,16):  ++t;  goto NewOpcode;

		/*--------------------------------------------------------
			Relative branches.
		*/
		#define BRANCHES(OP, COND) \
			case OP:  if (COND) goto DoBRA; \
				++pc;  t += 2;  goto NewOpcode; \
			case OP ^ 0x20:  if (not (COND)) goto DoBRA; \
				++pc;  t += 2;  goto NewOpcode;

		BRANCHES(0xB0, p & kfC) // BCS & BCC
		BRANCHES(0x70, p & kfV) // BVS & BVC
		BRANCHES(0x30, p & kfN) // BMI & BPL
		BRANCHES(0xF0,  Z_SET ) // BEQ & BNE

		DoBRA:  case 0x80:
			pc += (signed char) READ_PC;
			t += 3;
			goto NewOpcode;

		#undef BRANCHES

		/*--------------------------------------------------------
			Implied- and Accumulator-mode instructions:
		*/
		#define IMPI(OP, DT, STMT) \
			case OP:  t += DT;  STMT;  goto NewOpcode;
		#define LD_(REG,VAL)  REG = d = (VAL);  SET_NZ

		IMPI(0xB8, 2, p &= ~kfV)
		IMPI(0x18, 2, p &= ~kfC)		IMPI(0x38, 2, p |= kfC)
		IMPI(0xD8, 2, p &= ~kfD)		IMPI(0xF8, 2, p |= kfD)
		IMPI(0x58, 2, mI = 0)			IMPI(0x78, 2, mI = 4)

		IMPI(0x1A, 2, LD_(mA, mA+1))	IMPI(0x3A, 2, LD_(mA, mA-1))
		IMPI(0xE8, 2, LD_(mX, mX+1))	IMPI(0xCA, 2, LD_(mX, mX-1))
		IMPI(0xC8, 2, LD_(mY, mY+1))	IMPI(0x88, 2, LD_(mY, mY-1))

		IMPI(0x8A, 2, LD_(mA, mX))		IMPI(0xAA, 2, LD_(mX, mA))
		IMPI(0x98, 2, LD_(mA, mY))		IMPI(0xA8, 2, LD_(mY, mA))
		IMPI(0xBA, 2, LD_(mX, mS))		IMPI(0x9A, 2, mS = mX)

		IMPI(0x08, 3, PHP)				IMPI(0x28, 4, PLP)
		IMPI(0x48, 3, PUSH(mA))			IMPI(0x68, 4, LD_(mA, PULL))
		IMPI(0xDA, 3, PUSH(mX))			IMPI(0xFA, 4, LD_(mX, PULL))
		IMPI(0x5A, 3, PUSH(mY))			IMPI(0x7A, 4, LD_(mY, PULL))

		IMPI(0x0A, 2, ASL(mA))			IMPI(0x4A, 2, LSR(mA))
		IMPI(0x2A, 2, ROL(mA))			IMPI(0x6A, 2, ROR(mA))

		#undef IMPI
		#undef LD_

		/*--------------------------------------------------------
			Read and modify instructions of the Immediate and
			Zero-Page addressing modes.
		*/
		#define RIMM(OP, STMT)  case 0x##OP: \
			d = READ_PC;  t += 2;  STMT;  goto NewOpcode;
		#define RZP(OP, STMT)  case 0x##OP: \
			EAZ;   t += 3;  d = zp[ea];  STMT;  goto NewOpcode;
		#define RZPX(OP, STMT)  case 0x##OP: \
			EAZX;  t += 4;  d = zp[ea];  STMT;  goto NewOpcode;

		#define MZP(OP, STMT)  case 0x##OP: \
			EAZ;  t+=5;  d=zp[ea];  STMT;  zp[ea]=d;  goto NewOpcode;
		#define MZPX(OP, STMT)  case 0x##OP: \
			EAZX; t+=6;  d=zp[ea];  STMT;  zp[ea]=d;  goto NewOpcode;

		RIMM(69, ADC)		RZP(65, ADC)		RZPX(75, ADC)
		RIMM(29, AND)		RZP(25, AND)		RZPX(35, AND)
							MZP(06, ASL(d))		MZPX(16, ASL(d))
		RIMM(89, BITZ)		RZP(24, BIT)		RZPX(34, BIT)
		RIMM(C9, CMP)		RZP(C5, CMP)		RZPX(D5, CMP)
		RIMM(E0, CPX)		RZP(E4, CPX)
		RIMM(C0, CPY)		RZP(C4, CPY)
							MZP(C6, DEC)		MZPX(D6, DEC)
		RIMM(49, EOR)		RZP(45, EOR)		RZPX(55, EOR)
							MZP(E6, INC)		MZPX(F6, INC)
		RIMM(A9, LDA)		RZP(A5, LDA)		RZPX(B5, LDA)
		RIMM(A2, LDX)		RZP(A6, LDX)
		RIMM(A0, LDY)		RZP(A4, LDY)		RZPX(B4, LDY)
							MZP(46, LSR(d))		MZPX(56, LSR(d))
		RIMM(09, ORA)		RZP(05, ORA)		RZPX(15, ORA)
							MZP(26, ROL(d))		MZPX(36, ROL(d))
							MZP(66, ROR(d))		MZPX(76, ROR(d))
		RIMM(E9, SBC)		RZP(E5, SBC)		RZPX(F5, SBC)
							MZP(14, TRB)
							MZP(04, TSB)

		case 0xB6: // LDX zp,Y
			EAZY;  t += 4;  d = zp[ea];  LDX;  goto NewOpcode;

		#undef RIMM
		#undef RZP
		#undef RZPX
		#undef MZP
		#undef MZPX

		/*--------------------------------------------------------
			STA, STX, STY, and STZ
		*/
		case 0x85:  EAZ ;  t += 3;  zp[ea] = mA;  goto NewOpcode;
		case 0x86:  EAZ ;  t += 3;  zp[ea] = mX;  goto NewOpcode;
		case 0x84:  EAZ ;  t += 3;  zp[ea] = mY;  goto NewOpcode;
		case 0x64:  EAZ ;  t += 3;  zp[ea] =  0;  goto NewOpcode;

		case 0x95:  EAZX;  t += 4;  zp[ea] = mA;  goto NewOpcode;
		case 0x96:  EAZY;  t += 4;  zp[ea] = mX;  goto NewOpcode;
		case 0x94:  EAZX;  t += 4;  zp[ea] = mY;  goto NewOpcode;
		case 0x74:  EAZX;  t += 4;  zp[ea] =  0;  goto NewOpcode;

		case 0x8D:  EAA ;  t += 4;  d = mA;  goto Write;
		case 0x8E:  EAA ;  t += 4;  d = mX;  goto Write;
		case 0x8C:  EAA ;  t += 4;  d = mY;  goto Write;
		case 0x9C:  EAA ;  t += 4;  d =  0;  goto Write;

		case 0x9D:  EAAX;  t += 5;  d = mA;  goto Write;
		case 0x99:  EAAY;  t += 5;  d = mA;  goto Write;
		case 0x92:  EAI ;  t += 5;  d = mA;  goto Write;
		case 0x81:  EAIX;  t += 6;  d = mA;  goto Write;
		case 0x91:  EAIY;  t += 6;  d = mA;  goto Write;

		case 0x9E:  EAAX;  t += 5;  d =  0;  goto Write;

		/*--------------------------------------------------------
			"Prologs" for read and modify instructions that work
			on general addresses.  The effective address is
			computed, and the clock is bumped.  Execution then
			proceeds to the Read and Epilog phases below.
		*/
		case 0x6D: case 0x2D: case 0x0E: case 0x2C: case 0xCD:
		case 0xEC: case 0xCC: case 0xCE: case 0x4D: case 0xEE:
		case 0xAD: case 0xAE: case 0xAC: case 0x4E: case 0x0D:
		case 0x2E: case 0x6E: case 0xED: case 0x1C: case 0x0C:
			EAA;  t += 4;  break;

		case 0x7D: case 0x3D: case 0x1E: case 0x3C: case 0xDD:
		case 0xDE: case 0x5D: case 0xFE: case 0xBD: case 0xBC:
		case 0x5E: case 0x1D: case 0x3E: case 0x7E: case 0xFD:
			EAAX;  t += 4;  break;

		case 0x79: case 0x39: case 0xD9: case 0x59: case 0xB9:
		case 0xBE: case 0x19: case 0xF9:
			EAAY;  t += 4;  break;

		case 0x72: case 0x32: case 0xD2: case 0x52: case 0xB2:
		case 0x12: case 0xF2:
			EAI;  t += 5;  break;

		case 0x61: case 0x21: case 0xC1: case 0x41: case 0xA1:
		case 0x01: case 0xE1:
			EAIX;  t += 6;  break;

		case 0x71: case 0x31: case 0xD1: case 0x51: case 0xB1:
		case 0x11: case 0xF1:
			EAIY;  t += 5;  break;

		} // end of switch (t>>16 & d)

	//----------------------------------------------------------------
	  Read:

		curOp = d;
		JOURNAL_EA

		#define READ_PHASE  1
		#include "CPU-RW.h"
		#undef READ_PHASE

		d = READ(ea); // default read behavior, when 'ea' not in I/O area
		// fall into Epilog...

	//----------------------------------------------------------------
	  Epilog:

		switch (curOp)
		{
		#define OP_ACC(OP, STMT)  case OP+0x12: \
			case OP+0x01: case OP+0x05: case OP+0x09: case OP+0x0D: \
			case OP+0x11: case OP+0x15: case OP+0x19: case OP+0x1D: \
			STMT;  goto NewOpcode;

		OP_ACC(0x00, ORA)  OP_ACC(0x20, AND)  OP_ACC(0x40, EOR)
		OP_ACC(0x60, ADC)  OP_ACC(0xA0, LDA)  OP_ACC(0xC0, CMP)
		OP_ACC(0xE0, SBC)

		case 0x2C: case 0x3C:	BIT;  goto NewOpcode;
		case 0xEC:				CPX;  goto NewOpcode;
		case 0xCC:				CPY;  goto NewOpcode;
		case 0xAE: case 0xBE:	LDX;  goto NewOpcode;
		case 0xAC: case 0xBC:	LDY;  goto NewOpcode;

		case 0x0E: case 0x1E:	ASL(d);  break;
		case 0x4E: case 0x5E:	LSR(d);  break;
		case 0x2E: case 0x3E:	ROL(d);  break;
		case 0x6E: case 0x7E:	ROR(d);  break;
		case 0xCE: case 0xDE:	DEC;     break;
		case 0xEE: case 0xFE:	INC;     break;
		case 0x0C:				TSB;     break;
		case 0x1C:				TRB;     break;

		case 0x4C: case 0x5C: case 0x6C: case 0x7C: case 0x8C:
		case 0x9C: case 0xDC: case 0xFC: case 0x8E: case 0x9E:
		CASE16(0x00, 0x10):  CASE8 (0x02, 0x20):  CASE16(0x03, 0x10):
		CASE16(0x04, 0x10):  CASE16(0x06, 0x10):  CASE16(0x07, 0x10):
		CASE16(0x08, 0x10):  CASE16(0x0A, 0x10):  CASE16(0x0B, 0x10):
		CASE16(0x0F, 0x10):  default:
			OP_ACC(0x80, ;) // goto NewOpcode

		#undef OP_ACC
		}

		// Modify instructions reach here.  We need to burn 2 more
		// cycles before falling into Write.
		t += 2;

	//----------------------------------------------------------------
	  Write:

		#include "CPU-RW.h"

		JOURNAL_EA
		WRITE(ea) = d; // default write, when 'ea' not in I/O area
		goto NewOpcode;

	} // end of for (scanLine ...)


	mPC			= pc;
	mP			= p;
	gOldTimer	= t;

	p = gSpkrState;
	for (int i = 0;  i < kA2SamplesPerStep;  ++i)
	{
		t = gSpkrOut[i];
		p ^= t>>8;
		audioOut[i] = p ^ t>>24;
		p ^= t;
	}
	gSpkrState = p;

	for (int i = kTapRatio-1;  --i >= 0;)
		gSpkrOut[i] = (gSpkrOut + kA2SamplesPerStep)[i];
	t = A2T.audio.flat;
	for (int i = kA2SamplesPerStep;  --i >= 0;)
		(gSpkrOut + kTapRatio - 1)[i] = t;
}

//---------------------------------------------------------------------------
@end
