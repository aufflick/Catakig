#import "MyUtils.h"

@implementation NSObject (MyUtils)
//---------------------------------------------------------------------------

- (id)Release
	{ [self release];  return nil; }

//---------------------------------------------------------------------------
@end
