#import "MyUtils.h"

@implementation NSPanel (MyUtils)
//---------------------------------------------------------------------------

- (int)RunModal
{
	int		response;

///	[self center]; // always center??
	response = [NSApp runModalForWindow:self];
	[self close]; // or call 'orderOut'??
	return response;
}

//---------------------------------------------------------------------------

- (IBAction)StopModal:(id)sender
	{ [NSApp stopModalWithCode:[sender tag]]; }

//---------------------------------------------------------------------------
@end
