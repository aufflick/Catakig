#import "ShieldWindow.h"

@implementation ShieldWindow
//---------------------------------------------------------------------------

- (id)initWithContentRect:(NSRect)contentRect
	styleMask: (unsigned)styleMask_IGNORED
	backing:   (NSBackingStoreType)backingType
	defer:     (BOOL)flag
{
	self = [super
		initWithContentRect:	contentRect
		styleMask:				NSBorderlessWindowMask
		backing:				backingType
		defer:					flag ];
	if (self == nil)
		return nil;

	[self setLevel:CGShieldingWindowLevel()];
	[self setMovableByWindowBackground:NO];
//	[self setBackgroundColor:[NSColor blackColor]]; // clearColor??

	[self setReleasedWhenClosed:NO];
	[self setHasShadow:NO];
//	[self setHidesOnDeactivate:YES];
//	[self setAcceptsMouseMovedEvents:YES];
//	[self setDelegate:self];
//	[self setOpaque:NO];

	return self;
}

//---------------------------------------------------------------------------

- (BOOL)canBecomeKeyWindow
	{ return YES; }

//---------------------------------------------------------------------------
@end
