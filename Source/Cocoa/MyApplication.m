/*	class MyApplication
*/
#import "MyApplication.h"
#import "Catakig-Cocoa.h"

@implementation MyApplication
//---------------------------------------------------------------------------

- (void)sendEvent:(NSEvent*)event
{
	uint32_t	mods = [event modifierFlags];
	unsigned	b = 0;

	if (mods & NSCommandKeyMask)
		b |= kfA2KeyOpenApple;
	if (mods & NSAlternateKeyMask)
		b |= kfA2KeySolidApple;
	if (mods & NSShiftKeyMask)
		b |= kfA2KeyShift;
	A2G.buttons = b;

	if (G.prefs.joystickControl == kJoyMouse)
		[A2Computer InputPaddlesByMouse];

#if 0
	if (mods & NSControlKeyMask)
	{
		NSPoint	mloc = [NSEvent mouseLocation];
		NSLog(@"mouse loc = %d, %d", (int)mloc.x, (int)mloc.y);
		NSBeep();
	}
#endif

	[super sendEvent:event];
}

//---------------------------------------------------------------------------
@end
