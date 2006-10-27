#import "MyUtils.h"

@implementation NSOpenGLContext (MyUtils)
//---------------------------------------------------------------------------

- (void)SetSwapInterval:(long)interval
	{ [self setValues:&interval forParameter:NSOpenGLCPSwapInterval]; }

//---------------------------------------------------------------------------

- (NSOpenGLContext*)MakeCurrentContext
{/*
	Makes this context the current one, returning whatever was the previous
	current context.
*/
	NSOpenGLContext*	prev = [NSOpenGLContext currentContext];

	[self makeCurrentContext];
	return prev;
}

//---------------------------------------------------------------------------
@end
