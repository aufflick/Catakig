/*  CPU-Journal.h

	A helper file used to debug the 65c02 interpreter.  Not included
	in released versions of the LibAppleII library.
*/

enum { kPClo = 0x2000, kPChi = 0x3000 };

#define JOURNALING  1
#undef  JOURNAL_OP
#undef  JOURNAL_EA

#define JOURNAL_OP \
	if (not jstop  and  pc >= kPClo  and  pc <= kPChi) { \
		jdata[++jnum].pc = pc;		jdata[  jnum].op = d; \
		jdata[  jnum].p  = p;		jdata[  jnum].a  = mA; \
		jdata[  jnum].x  = mX;		jdata[  jnum].y  = mY; \
		jdata[  jnum].ea = -1; \
	}

#define JOURNAL_EA  jdata[jnum].ea = ea;

static struct
{
	uint16_t	pc, p;
	int			ea;
	uint8_t		op, a, x, y;
}				jdata[256];
static uint8_t	jnum;
static BOOL		jstop; // = NO


static void LogJournal(void)
{
	for (int i = 1, j;  i <= 256;  ++i)
	{
		j = (jnum+i) & 0xFF;
		fprintf(stderr,
			"A=%02X X=%02X Y=%02X p=%03X | %04X- %02X",
			jdata[j].a, jdata[j].x, jdata[j].y, jdata[j].p & 0xFFF,
			jdata[j].pc, jdata[j].op);
		if (jdata[j].ea >= 0)
			fprintf(stderr, " $%04X", jdata[j].ea);
		fputs("\n", stderr);
	}
}
