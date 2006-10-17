#import "MyUtils.h"

@implementation NSView (MyUtils)
//---------------------------------------------------------------------------

//+ (void)FillCurrentViewWithColor:(NSColor*)color
//	{ [color set];  [NSBezierPath fillRect:[self bounds]]; }

- (BOOL)MakeFirstResponder
	{ return [[self window] makeFirstResponder:self]; }

//---------------------------------------------------------------------------
@end
