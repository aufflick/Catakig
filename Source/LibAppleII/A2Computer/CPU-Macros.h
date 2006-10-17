//	Macros...  So many macros...

// For defining multiple 'case' labels easily:

#define CASE7(B,D) \
	case B      :  case B +   D:  case B + 2*D:  case B + 3*D: \
	case B + 4*D:  case B + 5*D:  case B + 6*D

#define CASE8(B,D)  CASE7(B,D):  case B + 7*D

#define CASE15(B,D)  CASE8(B,D): \
	case B +  8*D:  case B +  9*D:  case B + 10*D:  case B + 11*D: \
	case B + 12*D:  case B + 13*D:  case B + 14*D

#define CASE16(B,D)  CASE15(B,D):  case B + 15*D


// Reading from and writing to memory:

#define REMAP_(F)		(( zp = mMemory->RAM[0][(F)>>ksALTZP & 1] ),\
						 ( rmap = A2T.rmaps[(F) >> ksRMap & kmRMap] ),\
						 ( wmap = A2T.wmaps[(F) >> ksWMap & kmWMap] ))

#define READ(ADDR)		(zp + ADDR)[rmap[ADDR>>9] << 11]
#define WRITE(ADDR)		(zp + ADDR)[wmap[ADDR>>9] << 11]
#define READ_PC			(++pc, READ(pc))

#define PUSH(BYTE)		zp[0x100 | mS--] = (BYTE)
#define PULL			zp[0x100 | ++mS]
#define PHP				PUSH(A2T.tPHP[p & kmPHP] | mI)
#define PLP				mI = 4 & (p = PULL);  p = A2T.tPLP[p]


// Computing effective addresses, into local variable 'ea':

#define EAZ				ea =  READ_PC
#define EAZX			ea = (READ_PC + mX) & 0xFF
#define EAZY			ea = (READ_PC + mY) & 0xFF
#define EAA				EAZ;  ea += READ_PC<<8
#define EAAX			EAA | mX
#define EAAY			EAA | mY
#define EAI				EAZ ;  ea = ((zp+1)[ea]<<8 | zp[ea])
#define EAIX			EAZX;  ea = ((zp+1)[ea]<<8 | zp[ea])
#define EAIY			EAI + mY


// Implementations of most 65c02 instructions:

#define SET_NZ			p = (p & kfCDV) | (d << ksLSB)
#define INC				++d;  SET_NZ
#define DEC				--d;  SET_NZ
#define LDA				mA = d;  SET_NZ
#define LDX				mX = d;  SET_NZ
#define LDY				mY = d;  SET_NZ
#define AND				mA = d &= mA;  SET_NZ
#define EOR				mA = d ^= mA;  SET_NZ
#define ORA				mA = d |= mA;  SET_NZ

#define CP_(REG)		d = REG-d;  p = p&kfDV | d<<ksLSB | (~d>>7 & kfC)
#define CMP				CP_(mA)
#define CPX				CP_(mX)
#define CPY				CP_(mY)

#define AD_SB_C(T,D)	( (mA = d = (long) T[T[mA] + T[D] + (p&kfCD)]), \
						  (p = d >> 8) )
#define ADC				AD_SB_C(mTblADC, d)
#define SBC				AD_SB_C(mTblSBC, d ^ 0xFF)

#define BITZ			p = kfLSB | (d&mA? (p & ~kfZF) : (p | kfZF))
#define BIT				p = p&kfCD | d<<ksLSB | d>>4&kfV;  BITZ
#define TRB				BITZ;  d &= ~mA
#define TSB				BITZ;  d |=  mA
#define Z_SET			( ((p & kmZ8) == 0) | (p & kfZF) )

#define ROSH(REG,T,MASK)	REG = (p = T[REG<<3 | p&MASK]) >> ksLSB
#define ASL(REG)			ROSH(REG, A2T.tROL, kfDV)
#define LSR(REG)			ROSH(REG, A2T.tROR, kfDV)
#define ROL(REG)			ROSH(REG, A2T.tROL, kfCDV)
#define ROR(REG)			ROSH(REG, A2T.tROR, kfCDV)


// Miscellany:

#define CYCLES		(mCycles + t + scanLine + (scanLine<<6))
#define FLOATER		zp[0x400 + t]
	// FLOATER not right yet!!
