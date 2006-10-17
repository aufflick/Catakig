#import "MyUtils.h"

@implementation NSUserDefaults (MyUtils)
//---------------------------------------------------------------------------

- (BOOL)RegisterBool:(BOOL)value forKey:(NSString*)key
{
	[self registerDefaults:[NSDictionary dictionaryWithObject:
		[NSNumber numberWithBool:value] forKey:key]];

	return [self boolForKey:key];
}

//---------------------------------------------------------------------------

- (int)RegisterInteger:(int)value forKey:(NSString*)key
{
	[self registerDefaults:[NSDictionary dictionaryWithObject:
		[NSNumber numberWithInt:value] forKey:key]];

	return [self integerForKey:key];
}

//---------------------------------------------------------------------------

- (float)RegisterFloat:(float)value forKey:(NSString*)key
{
	[self registerDefaults:[NSDictionary dictionaryWithObject:
		[NSNumber numberWithFloat:value] forKey:key]];

	return [self floatForKey:key];
}

//---------------------------------------------------------------------------
@end
