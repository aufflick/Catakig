/*	class A2Computer (category Audio)
*/
#import "LibAppleII-Priv.h"

@implementation A2Computer (Audio)
//---------------------------------------------------------------------------

static struct
{
	int		silence;			// = 0 or 128
	double	FIR[kFilterSize];	// partial sums of FIR coefficients

} g =
{
	.silence = 128,
};


static double Sinc(double x)
	{ return x? sin(x)/x : 1.; }

//---------------------------------------------------------------------------

+ (void)_InitAudio
{/*
	Called once at startup, from '+initialize'.  Prepares the digital filter
	coefficients, and sets a default volume level.
*/
	const double	pi   = 4. * atan(1.),
					c    = pi * 0.4 / kFilterRes;
	double			psum = 0.,
					norm = 0.;

	for (int j = kFilterSize;  --j >= 0;)
	{
		int		i = 2*j - kFilterSize + 1;
		double	h = Sinc(c * i);
	//	double	x = i * (pi / kFilterSize);

	//	h *= 42 + 50*cos(x) + 8*cos(2*x);	// Blackman
	//	h *= 54 + 46*cos(x);				// Hamming
	//	h *= 50 + 50*cos(x);				// Hann

		norm += ( g.FIR[j] = h );
	//	NSLog(@"h[%4d] = %f", j, h);
	}

	for (int j = kFilterSize;  --j >= 0;)
		g.FIR[j] = ( psum += (g.FIR[j] / norm) );

	[A2Computer SetAudioVolume:40];
}

//---------------------------------------------------------------------------

+ (void)SetAudioVolume:(unsigned)volume
{/*
	Sets the volume level for audio production.  Parameter 'volume' should
	be between 0 and 100.
*/
	if (volume > 100)
		volume = 100;
	A2T.audio.flat = (g.silence - volume - 1L) << 24;

	long	range = -256L * (2 * (int)volume + 1);

	for (int i = kFilterSize;  --i >= 0;)
		A2T.audio.delta[i] =
			((long)(g.FIR[i] * range + 0.5)) << 16;

#if 0
	for (int i = LENGTH(gSpkrOut);  --i >= 0;)
		gSpkrOut[i] = A2T.audio.flat; //??
#endif
}

//---------------------------------------------------------------------------

- (void)_DefaultAudio:(uint8_t [])audioOut :(unsigned)nSamples
{
	if (mHalts & kfHaltNoPower) // then power is off; emit hiss
	{
		for (int i = nSamples/4;  --i >= 0;)
			((uint32_t*)audioOut)[i] = 0x01010101 *
				( (g.silence - 8) + (A2Random16() & 15) );
	}
	else // power is on, but execution still halted; emit silence
	{
		memset(audioOut, g.silence, nSamples);
	}
}

//---------------------------------------------------------------------------
@end
