#import "MyUtils.h"

@implementation NSMovie (MyUtils)
//---------------------------------------------------------------------------

- (id)InitWithResource:(NSString*)fname
{
	NSURL*		url = [NSURL fileURLWithPath:[fname PathForResource]];

	if (url == nil)
		return [self Release];

	return [self initWithURL:url byReference:YES];
}

//---------------------------------------------------------------------------
@end
