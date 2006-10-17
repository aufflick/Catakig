
@class A2Computer, IndicatorLight, MyDocument;

@interface ScreenView : NSOpenGLView
{
	IBOutlet MyDocument*		mDocument;
	IBOutlet IndicatorLight*	mDDLight0;
	IBOutlet IndicatorLight*	mDDLight1;
	IBOutlet IndicatorLight*	mPrinterLight;

	uint8_t		mVideoStyle; // bits 6-7 used: monochrome, flash
	unsigned	mPrevLights;

@public
	IBOutlet A2Computer*		mA2;

	void		(*mRenderScreen )(id, SEL, void*, int32_t);
	void		(*mRunForOneStep)(id, SEL, uint8_t*);
}

+ (void)		FullScreenOff;
+ (void)		AllNeedDisplay;
- (void)		Flash;
- (IBAction)	ToggleColorVideo:(id)sender;
- (IBAction)	ToggleFullScreen:(id)sender;

@end
