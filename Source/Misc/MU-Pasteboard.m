#import "MyUtils.h"

@implementation NSPasteboard (MyUtils)
//---------------------------------------------------------------------------

- (NSString*)GetString
{
	[self types];
	return [self stringForType:NSStringPboardType];
}

//---------------------------------------------------------------------------

- (BOOL)SetString:(NSString*)str
{
	NSString*	type = NSStringPboardType;

	[self declareTypes:[NSArray arrayWithObject:type] owner:nil];
	return [self setString:str forType:type];
}

//---------------------------------------------------------------------------

- (BOOL)SetData:(NSData*)data forType:(NSString*)type
{
	[self declareTypes:[NSArray arrayWithObject:type] owner:nil];
	return [self setData:data forType:type];
}

//---------------------------------------------------------------------------
@end
