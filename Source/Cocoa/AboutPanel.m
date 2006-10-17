/*	class AboutPanel

	Catakig's About box.  Only one instance exists at runtime.
*/
#import "Catakig-Cocoa.h"
#import "AboutPanel.h"
#import "ScreenView.h"

@implementation AboutPanel
//---------------------------------------------------------------------------

- (void)_Strobe:(NSTimer*)timer
{
	static int	counter = 0;

	if (--counter > 0)
		[G.activeScreen setNeedsDisplay:YES];
	else
	{
		[G.activeScreen Flash];
		counter = 7;

		if ([self isKeyWindow])
		{
			[mCursorCover setDrawsBackground:
				[mCursorCover drawsBackground] ^ 1];
			[mCursorCover setNeedsDisplay];
		}
	}
}

//---------------------------------------------------------------------------

- (void)awakeFromNib
{
//	Set version string in the About box to value of CFBundleVersion
//	entry in the Info.plist dictionary.

	NSString*	vstr;

	vstr = [[G.bundle infoDictionary] objectForKey:@"CFBundleVersion"];
	if (vstr != nil)
		[mVersion setStringValue:vstr];

//	Turn on the cursor flasher.

	mStrober = [NSTimer scheduledTimerWithTimeInterval:	1./30
		target:			self
		selector:		@selector(_Strobe:)
		userInfo:		nil
		repeats:		YES ];

//	[self setDelegate:self];
	if (G.prefs.firstLaunch)
		[self makeKeyAndOrderFront:self];
}

//---------------------------------------------------------------------------
#if 0
- (void)close
{
	[mStrober invalidate];
}
#endif
//---------------------------------------------------------------------------

- (void)makeKeyAndOrderFront:(id)sender
{
	if (not [self isVisible])
		[self center];

	[super makeKeyAndOrderFront:sender];
}

//---------------------------------------------------------------------------
@end
