/*	class PrefsPanel

	Catakig's Preferences panel.  Only one instance exists at runtime.
*/
#import "Catakig-Cocoa.h"
#import "PrefsPanel.h"
#import "ScreenView.h"

@implementation PrefsPanel
//---------------------------------------------------------------------------

static void SyncDefaults(BOOL registering)
{
#define PREF(NAME, TYPE, IVALUE) \
	if (registering) \
		G.prefs.NAME = [sud Register##TYPE:IVALUE forKey:@ #NAME]; \
	else \
		[sud set##TYPE:G.prefs.NAME forKey:@ #NAME];

	NSUserDefaults*	sud = [NSUserDefaults standardUserDefaults];

	PREF(firstLaunch, Bool, YES)
	PREF(beepsOn, Bool, YES)
	PREF(keepBackupFiles, Bool, NO)
	PREF(monochromeHue, Integer, 0x33FF33)
	PREF(joystickControl, Integer, kJoyMouse)

	if (not registering)
		[sud synchronize];

#undef PREF
}

//---------------------------------------------------------------------------

+ (void)initialize
{
	SyncDefaults(YES);
}

//---------------------------------------------------------------------------

- (void)close
{
	G.prefs.firstLaunch = NO;
	SyncDefaults(NO);

//	NSLog(@"PrefPanel -close called"); //!!
//	[NSUserDefaults resetStandardUserDefaults];
	[super close];
}

//---------------------------------------------------------------------------

- (void)awakeFromNib
{
	[mJoystickControl selectCellWithTag:G.prefs.joystickControl];

	[mMonochromeHue setColor:[NSColor
		colorWithDeviceRed:	((G.prefs.monochromeHue>>16) & 255)/255.
		green:				((G.prefs.monochromeHue>> 8) & 255)/255.
		blue:				((G.prefs.monochromeHue    ) & 255)/255.
		alpha:				1. ]];
	[self HitMonochromeHue:mMonochromeHue];
}

//---------------------------------------------------------------------------

- (void)makeKeyAndOrderFront:(id)sender
{
	if (not [self isVisible])
		[self center];

	[super makeKeyAndOrderFront:sender];
}

//---------------------------------------------------------------------------

- (IBAction)HitJoystickControl:(id)sender
{/*
	Responds to user changing the joystick (and paddle) control mechanism.
*/
	G.prefs.joystickControl = [sender selectedTag];
}

//---------------------------------------------------------------------------

- (IBAction)HitMonochromeHue:(id)sender
{/*
	Responds to user changing the monochrome video hue preference.

	First ensure color is in RGB space??
*/
	float		r, g, b;

	[[sender color] getRed:&r green:&g blue:&b alpha:nil];
	G.prefs.monochromeHue =
		(uint32_t)(255. * r) << 16 |
		(uint32_t)(255. * g) <<  8 |
		(uint32_t)(255. * b);
	[ScreenView AllNeedDisplay];
}

//---------------------------------------------------------------------------
@end
