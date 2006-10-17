#import "MyUtils.h"
#import <bzlib.h>
#import <zlib.h>

@implementation NSData (MyUtils)
//---------------------------------------------------------------------------
#if 0 //broken!!

+ (NSData*)GZCompressBytes:(const void*)src length:(unsigned)srcLen
	level:(int)level
{
	NSMutableData*	dest = nil;

	int				sts;
	uLongf			destLen = compressBound(srcLen);

	if (nil == (dest = [NSMutableData dataWithLength:destLen]))
		return nil;

	sts = compress2([dest mutableBytes], &destLen, src, srcLen, level);
	if (sts != Z_OK)
		return nil;

	[dest setLength:destLen];
	return dest;
}
#endif
//---------------------------------------------------------------------------

+ (NSData*)BZCompressBytes:(const void*)src length:(unsigned)srcLen
	level:(int)level
{
	int				sts;
	unsigned		destLen = srcLen + srcLen/100 + 601;
	NSMutableData*	dest = [NSMutableData dataWithLength:destLen];

	if (dest == nil)
		return nil;

	sts = BZ2_bzBuffToBuffCompress([dest mutableBytes], &destLen,
		(char*)src, srcLen, level, 0, 0);
	if (sts != BZ_OK)
		return nil;

	[dest setLength:destLen];
	return dest;
}

//---------------------------------------------------------------------------
@end
