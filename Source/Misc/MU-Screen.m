#import "MyUtils.h"

@implementation NSScreen (MyUtils)
//---------------------------------------------------------------------------

+ (NSScreen*)MenuBarScreen
	{ return [[NSScreen screens] objectAtIndex:0]; }

//---------------------------------------------------------------------------
#ifdef __CGDIRECT_DISPLAY_H__

- (CGDirectDisplayID)DirectDisplayID
{
	return [[[self deviceDescription]
		objectForKey:@"NSScreenNumber"] pointerValue];
}

#endif
//---------------------------------------------------------------------------
@end
