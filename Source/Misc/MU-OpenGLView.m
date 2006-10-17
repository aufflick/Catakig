#import "MyUtils.h"

@implementation NSOpenGLView (MyUtils)
//---------------------------------------------------------------------------

- (void)FlushBuffer
	{ [[self openGLContext] flushBuffer]; }

- (NSOpenGLContext*)MakeCurrentContext
	{ return [[self openGLContext] MakeCurrentContext]; }

//---------------------------------------------------------------------------

static void FlipVertically(NSBitmapImageRep* imRep)
{
	int			height		= [imRep pixelsHigh];
	int32_t		intsPerRow	= [imRep bytesPerRow] / 4;
	uint32_t	*plo		= (uint32_t*) [imRep bitmapData],
				*phi		= plo + intsPerRow * (height-1),
				temp;

	for (int i = height/2;  --i >= 0;)
	{
		for (int j = intsPerRow;  --j >= 0;)
			temp = plo[j],  plo[j] = phi[j],  phi[j] = temp;
		plo += intsPerRow;
		phi -= intsPerRow;
	}
}

//---------------------------------------------------------------------------

static void ResetContext(void)
{
	const GLfloat	zero = 0.;

	glDisable(GL_COLOR_TABLE);
	glDisable(GL_CONVOLUTION_1D);
	glDisable(GL_CONVOLUTION_2D);
	glDisable(GL_HISTOGRAM);
	glDisable(GL_MINMAX);
	glDisable(GL_POST_COLOR_MATRIX_COLOR_TABLE);
	glDisable(GL_POST_CONVOLUTION_COLOR_TABLE);
	glDisable(GL_SEPARABLE_2D);

	glPixelMapfv(GL_PIXEL_MAP_R_TO_R, 1, &zero);
	glPixelMapfv(GL_PIXEL_MAP_G_TO_G, 1, &zero);
	glPixelMapfv(GL_PIXEL_MAP_B_TO_B, 1, &zero);
	glPixelMapfv(GL_PIXEL_MAP_A_TO_A, 1, &zero);

	glPixelStorei(GL_PACK_SWAP_BYTES, 0);
	glPixelStorei(GL_PACK_LSB_FIRST, 0);
	glPixelStorei(GL_PACK_IMAGE_HEIGHT, 0);
	glPixelStorei(GL_PACK_ALIGNMENT, 4);	// or 3??
	glPixelStorei(GL_PACK_ROW_LENGTH, 0);
	glPixelStorei(GL_PACK_SKIP_PIXELS, 0);
	glPixelStorei(GL_PACK_SKIP_ROWS, 0);
	glPixelStorei(GL_PACK_SKIP_IMAGES, 0);

	glPixelTransferi(GL_MAP_COLOR, 0);
	glPixelTransferf(GL_RED_SCALE, 1.0f);
	glPixelTransferf(GL_RED_BIAS, 0.0f);
	glPixelTransferf(GL_GREEN_SCALE, 1.0f);
	glPixelTransferf(GL_GREEN_BIAS, 0.0f);
	glPixelTransferf(GL_BLUE_SCALE, 1.0f);
	glPixelTransferf(GL_BLUE_BIAS, 0.0f);
	glPixelTransferf(GL_ALPHA_SCALE, 1.0f);
	glPixelTransferf(GL_ALPHA_BIAS, 0.0f);
	glPixelTransferf(GL_POST_COLOR_MATRIX_RED_SCALE, 1.0f);
	glPixelTransferf(GL_POST_COLOR_MATRIX_RED_BIAS, 0.0f);
	glPixelTransferf(GL_POST_COLOR_MATRIX_GREEN_SCALE, 1.0f);
	glPixelTransferf(GL_POST_COLOR_MATRIX_GREEN_BIAS, 0.0f);
	glPixelTransferf(GL_POST_COLOR_MATRIX_BLUE_SCALE, 1.0f);
	glPixelTransferf(GL_POST_COLOR_MATRIX_BLUE_BIAS, 0.0f);
	glPixelTransferf(GL_POST_COLOR_MATRIX_ALPHA_SCALE, 1.0f);
	glPixelTransferf(GL_POST_COLOR_MATRIX_ALPHA_BIAS, 0.0f);
}

//---------------------------------------------------------------------------

- (NSBitmapImageRep*)ReadPixels
{/*
	Returns an auto-released NSBitmapImageRep containing a snapshot of this
	OpenGL view.  (And that's a lot harder than you'd think.)
*/
	NSSize				size = NSIntegralRect([self bounds]).size;
	NSBitmapImageRep*	imRep;

	imRep = [[NSBitmapImageRep alloc]
		initWithBitmapDataPlanes:	nil
		pixelsWide:					size.width
		pixelsHigh:					size.height
		bitsPerSample:				8
		samplesPerPixel:			3
		hasAlpha:					NO
		isPlanar:					NO
		colorSpaceName:				NSDeviceRGBColorSpace
										// NSCalibratedRGBColorSpace??
		bytesPerRow:				0
		bitsPerPixel:				0 ];
	if (imRep == nil)
		return nil;


	NSOpenGLContext*	prevContext = [self MakeCurrentContext];

//	glFinish();	 // finish any pending OpenGL commands
	glPushAttrib(GL_ALL_ATTRIB_BITS);
	ResetContext();
//	glPixelStorei(GL_PACK_ROW_LENGTH, [imRep bytesPerRow]/kSamples);
//	glReadBuffer(GL_BACK); // need??
	glReadPixels(0, 0, size.width, size.height,
		GL_RGB, GL_UNSIGNED_BYTE, [imRep bitmapData]);
	glPopAttrib();

	FlipVertically(imRep);
	[prevContext makeCurrentContext];
	return [imRep autorelease];
}

//---------------------------------------------------------------------------

- (void)PrepareToMiniaturize
{
    NSBitmapImageRep*	image = [self ReadPixels];

	[self lockFocus];
	[image draw];
	[self unlockFocus];
	[[self window] flushWindow]; // need??
}

//---------------------------------------------------------------------------
@end
