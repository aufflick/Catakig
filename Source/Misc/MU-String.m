#import "MyUtils.h"
#import <regex.h>
#import <sys/stat.h>

@implementation NSString (MyUtils)
//---------------------------------------------------------------------------

- (BOOL)SetFileCreator:(uint32_t)creatorCode andType:(uint32_t)typeCode
{/*
	Sets the HFS creator and type codes for the file given by this string's
	path.  Passing 0 for either parameter indicates no change is to be made
	for that attribute.  Returns whether successful.
*/
	NSFileManager*			fileMgr = [NSFileManager defaultManager];
	NSDictionary*			prevAttr;
	NSMutableDictionary*	attr;

	prevAttr = [fileMgr fileAttributesAtPath:self traverseLink:YES];
	if (prevAttr == nil)
		return NO;

	attr = [NSMutableDictionary dictionaryWithDictionary:prevAttr];
	if (creatorCode != 0)
		[attr setObject:[NSNumber numberWithUnsignedLong:creatorCode]
			forKey:NSFileHFSCreatorCode];
	if (typeCode != 0)
		[attr setObject:[NSNumber numberWithUnsignedLong:typeCode]
			forKey:NSFileHFSTypeCode];

	return [fileMgr changeFileAttributes:attr atPath:self];
}

//---------------------------------------------------------------------------

- (BOOL)SetFileExtension:(NSString*)extension
{/*
	Renames this file's extension to the given one, or if 'extension' is
	nil, to an empty extension.
*/
	NSString*	newPath;

	newPath = [self stringByDeletingPathExtension];
	if (extension != nil)
		newPath = [newPath stringByAppendingPathExtension:extension];

	return [[NSFileManager defaultManager]
		movePath:self toPath:newPath handler:nil];
}

//---------------------------------------------------------------------------

- (uint32_t)FileTypeCode
{/*
	Returns the HFS type code of this file, or 0 if the type is
	unavailable.
*/
	NSDictionary*	attr;
	NSNumber*		type;

	attr = [[NSFileManager defaultManager]
		fileAttributesAtPath:self traverseLink:YES];
	if (attr == nil)
		return 0;

	type = [attr objectForKey:NSFileHFSTypeCode];
	return type? [type unsignedLongValue] : 0;
}

//---------------------------------------------------------------------------

- (BOOL)IsReadableFile
	{ return [[NSFileManager defaultManager] isReadableFileAtPath:self]; }

- (BOOL)Matches:(const regex_t*)rex
	{ return 0 == regexec(rex, [self UTF8String], 0, nil, 0); }

- (BOOL)ExtensionMatches:(const regex_t*)rex
	{ return [[self pathExtension] Matches:rex]; }

- (BOOL)Stat:(struct stat*)st
	{ return 0 == stat([self fileSystemRepresentation], st); }

- (BOOL)Truncate:(size_t)length
	{ return 0 == truncate([self fileSystemRepresentation], length); }

- (NSString*)PathForResource
	{ return [[NSBundle mainBundle] pathForResource:self ofType:nil]; }

//---------------------------------------------------------------------------
@end
