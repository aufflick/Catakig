
@interface PrefsPanel : NSPanel
{
	IBOutlet	NSColorWell*	mMonochromeHue;
	IBOutlet	NSMatrix*		mJoystickControl;
}

- (IBAction)	HitJoystickControl:(id)sender;
- (IBAction)	HitMonochromeHue:(id)sender;

@end
