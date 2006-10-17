#import "MyUtils.h"

@implementation NSOpenGLContext (MyUtils)
//---------------------------------------------------------------------------

- (void)SetSwapInterval:(long)interval
	{ [self setValues:&interval forParameter:NSOpenGLCPSwapInterval]; }

//---------------------------------------------------------------------------

- (NSOpenGLContext*)MakeCurrentContext
{
	NSOpenGLContext*	prev = [NSOpenGLContext currentContext];

	[self makeCurrentContext];
	return prev;
}

//---------------------------------------------------------------------------
@end
