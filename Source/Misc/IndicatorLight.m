/*	class IndicatorLight

	A view, descended from NSImageView, that displays an "indicator
	light".  The light's visible state is a sub-rectangle of a
	larger image containing all possible light states.  We use
	NSImageView alignment values to shift among the states.
*/
#import "IndicatorLight.h"

@implementation IndicatorLight
//---------------------------------------------------------------------------

- (void)awakeFromNib
{
//	Give these attributes sensible values, regardless of how they're
//	set in the NIB file.

	[self setEditable:NO];
	[self setEnabled:NO];
	[self setAlignment:NSImageAlignTopLeft];
	[self setImageFrameStyle:NSImageFrameNone];
	[self setImageScaling:NSScaleNone];
}

//---------------------------------------------------------------------------

- (int)intValue
{/*
	Returns this light's current state as a value from 0 to 8.

	For my (CK) reference, NSImageAlign and their state values:
		2 1 3   0 4 1
		4 0 8   5 6 7
		6 5 7   2 8 3
*/
	return "\6\4\0\1\5\x8\2\3\7"[[self imageAlignment]];
}

//---------------------------------------------------------------------------

- (void)setIntValue:(int)state
{/*
	Sets this light's state to a value from 0 to 8.
*/
	[self setImageAlignment:(int)("\2\3\6\7\1\4\0\x8\5"[state % 9])];
//  [self setNeedsDisplay];
}

//---------------------------------------------------------------------------

- (void)ToggleState
{/*
	Toggles this light between on and off (assuming the low bit of the
	state value reflects this property).
*/
	[self setIntValue:[self intValue] ^ 1];
}

//---------------------------------------------------------------------------
@end
