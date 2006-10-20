/*	class A2Computer (category Printing)
*/
%option 7bit never-interactive batch noyywrap prefix="A2Printing_"
%x EpsonRX

%{ --------------------------------------------------------------------------
#import "LibAppleII-Priv.h"

#define YY_DECL  static void yylex(unsigned filter)

static int			input(void);
//static uint8_t		gEpsonFontForStyle[0x2FF + 1];

//---------------------------------------------------------------------------

static void EpsonText(BOOL trailingRubouts)
{
	int		n = yyleng;

	fputs("\n(--", yyout);
	for (int i = 0;  i < n;  ++i)
	{
		char	ch = yytext[i];

		if (ch == '('  or  ch == ')'  or  ch == '\\')
			fputc('\\', yyout);
		putc(ch, yyout);
	}
	fputs(") T", yyout);
}

//---------------------------------------------------------------------------

static void EpsonGraphics(int mode)
{
	const char*	hexDigit = "0123456789ABCDEF";
	int			nbytes,
				data;

	nbytes = (yytext[yyleng-1]&7)<<8 | yytext[yyleng-2];
	if (nbytes < 1)
		return;

	fputs("\n<7F80 ", yyout);
	while (--nbytes >= 0  and  EOF != (data = input()))
	{
		putc(hexDigit[data >> 4], yyout);
		putc(hexDigit[data & 15], yyout);
	}
	fprintf(yyout, "> G%c", mode | '0');
}

%} --------------------------------------------------------------------------

ESC			\x1B
ANY			[\0-\x7F]
ANY2		{ANY}{2}
ANY3		{ANY}{3}

%%
%{
	unsigned	charset = 0;
	BOOL		gcharset = NO; // Epson-specific state

	yyrestart(yyin);
	BEGIN(filter);
%}

<EpsonRX>{
	<<EOF>>				fputs("\nshowpage\n", yyout);  return;
	{ESC}[@] {			fputs("\nReset\n", yyout);
						charset = 0;  gcharset = NO;
	}
	{ESC}R[\0-\12]		charset = yytext[2];
	{ESC}m[\0\4]		gcharset = yytext[2] >> 2;
	{ESC}[<]			fputs("  CR", yyout);

	{ESC}K{ANY2}				EpsonGraphics(0);
	{ESC}L{ANY2}				EpsonGraphics(1);
	{ESC}Y{ANY2}				EpsonGraphics(2);
	{ESC}Z{ANY2}				EpsonGraphics(3);
	{ESC}[*][\0-\4\6]{ANY2}		EpsonGraphics(yytext[2]);

	{ESC}[01245EFGHMOPT] {
		fprintf(yyout, "  E-%c", yytext[1]);
	}
	{ESC}?[\x0F\x12\x0E\x14] {
		fprintf(yyout, "  C-%c", yytext[yyleng-1] | '@');
	}
	{ESC}[-SW][01\0\1] {
		fprintf(yyout, "  E-%c%c", yytext[1], yytext[2] | '0');
	}
	{ESC}C\0{ANY} |
	{ESC}[ef][01]{ANY} {
		fprintf(yyout, "  %d E-%c%c", yytext[3], yytext[1], yytext[2]|'0');
	}
	{ESC}[3ACJNQl]{ANY} {
		fprintf(yyout, "  %d E-%c", yytext[2], yytext[1]);
	}

	\x08+|\x09+|\x0A+|\x0B+|\x0C+|\x0D+ {
		fprintf(yyout, "  %d C-%c", yyleng, yytext[0] | '@');
	}

	[\x20-\x7E]+\x18+		; // cancel buffer
	[\x20-\x7E]+\x7F+		EpsonText(YES);
	[\x20-\x7E]+			EpsonText(NO);

	{ESC}[*]{ANY3} |
	{ESC}[ef]{ANY2} |
	{ESC}[-SRUWms]{ANY} |
	{ESC}{ANY}				; // invalid sequences, skipped
}

<INITIAL>{
	[\n\t\v\f]+ |
	[\x20-\x7E]+			ECHO;
}

<*>{
	{ANY}				; // ignored if not handled above
	<<EOF>>				return;
}

%%
@implementation A2Computer (Printing)
//---------------------------------------------------------------------------

+ (void)_InitPrinting
{
#if 0
	enum
	{
	//	Epson text-style flags:

		kEpItalics		= 1,		kEpCompressed	= 1<<4,
		kEpUnderline	= 1<<1,		kEpEmphasized	= 1<<5,
		kEpExpanded		= 1<<2,		kEpElite		= 1<<6,
		kEpExpanded1L	= 1<<3,		kEpDblStrike	= 1<<7,

		kEpSubscript	= 1<<8, // at most one Script bit is ever 1
		kEpSuperscript	= 1<<9,
	};

	// Set up the mapping from Epson style flags to font numbers.

	for (int style = sizeof(gEpsonFontForStyle);  --style >= 0;)
	{
		unsigned	f = style & (kEpItalics | kEpUnderline);

		if (style & (kEpExpanded | kEpExpanded1L))
			f |= 4;
		f |= "\x00\x18\x08\x08\x10\x10\x10\x10"[style>>4 & 7];
		f |= "\x00\x20\x40\x40\x60\x60"[style>>7];

		gEpsonFontForStyle[style] = f;
	}
#endif
}

//---------------------------------------------------------------------------

- (long)SizeOfPrintSession
{/*
	Returns the number of bytes that have accumulated so far in the
	printer session.
*/
	fflush(mPrinter.session); // (probably unnecessary)
	return ftell(mPrinter.session);
}

//---------------------------------------------------------------------------

- (void)ClearPrintSession
{/*
	Clears (purges) the printer session.  All data bytes that this printer
	has received are discarded.
*/
	fflush(mPrinter.session);
	fseek(mPrinter.session, 0, SEEK_SET);
	ftruncate(fileno(mPrinter.session), 0);
}

//---------------------------------------------------------------------------

- (BOOL)SavePrintSessionAs:(unsigned)filter toFile:(NSString*)fpath
{/*
	Write the print session to a file, using the specified processing
	filter.
*/
	yyout = fopen([fpath fileSystemRepresentation], "wb");
	if (yyout == NULL)
		return NO;

//	NSLog(@"Printing to '%@' using filter %d", fpath, filter); //!!
	fflush(yyin = mPrinter.session);
	rewind(yyin);

	switch (filter)
	{
	  default:
	  case kA2PFVerbatim:
		A2WriteEntireFile(fileno(yyout), fileno(yyin));
		break;

	  case kA2PFEpsonToPS:
		A2AppendResourceFile(fileno(yyout), @"Ibsen.pfa");
		A2AppendResourceFile(fileno(yyout), @"IbsenUtils.ps");
		yylex(filter);
		break;

	  case kA2PFPlain:
		yylex(filter);
		break;
	}

	fclose(yyout);
	fseek(yyin, 0, SEEK_END);
	yyin = yyout = NULL;
	return YES;
}

//---------------------------------------------------------------------------
@end
