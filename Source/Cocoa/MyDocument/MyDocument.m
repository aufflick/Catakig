#import "Catakig-Cocoa.h"
#import "MyDocument.h"

enum
{
	kDocCreatorCode		= 'Ctkg',
	kDocTypeCode		= 'A2st',
};

@implementation MyDocument
//---------------------------------------------------------------------------

+ (void)AllNeedDisplay
{/*
	Requests a redraw of all Apple II screens.
*/
	NSEnumerator*	e = [[G.docMgr documents] objectEnumerator];
	MyDocument*		doc;

	while ((doc = [e nextObject]))
	{
		[doc->mScreen MakeCurrentContext];
		GL_PreparePalette();
		[doc->mScreen setNeedsDisplay:YES];
	}
}

//---------------------------------------------------------------------------

- (NSString*)windowNibName
{/*
	"Override returning the nib file name of the document.
	If you need to use a subclass of NSWindowController or if your document
	supports multiple NSWindowControllers, you should remove this method
	and override -makeWindowControllers instead."
*/
    return @"MyDocument";
}

//---------------------------------------------------------------------------

- (NSDictionary*)fileAttributesToWriteToFile:(NSString*)fpath
	ofType:(NSString*)docType
	saveOperation:(NSSaveOperationType)saveOp
{/*
	Tells the OS our preferred HFS type and creator codes for saved
	documents.
*/
	NSMutableDictionary*   dict;

	dict = [NSMutableDictionary dictionaryWithDictionary:
		[super fileAttributesToWriteToFile:fpath
			ofType:docType saveOperation:saveOp]];

	[dict setObject:[NSNumber numberWithUnsignedLong:kDocCreatorCode]
		forKey:NSFileHFSCreatorCode];
	[dict setObject:[NSNumber numberWithUnsignedLong:kDocTypeCode]
		forKey:NSFileHFSTypeCode];

	return dict;
}

//---------------------------------------------------------------------------
#if 0
- (BOOL)writeToFile:(NSString *)fileName ofType:(NSString *)docType
{
}

- (BOOL)readFromFile:(NSString *)fileName ofType:(NSString *)docType
{
}

#endif
//---------------------------------------------------------------------------

- (NSData*)dataRepresentationOfType:(NSString*)docType
{/*
	"Insert code here to write your document from the given data.  You can
	also choose to override -fileWrapperRepresentationOfType: or
	-writeToFile:ofType: instead."
    
	"For applications targeted for Tiger or later systems, you should use
	the new Tiger API -dataOfType:error:.  In this case you can also choose
	to override -writeToURL:ofType:error:, -fileWrapperOfType:error:, or
	-writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead."
*/
//	return [NSArchiver archivedDataWithRootObject:self];
	return [NSKeyedArchiver archivedDataWithRootObject:self];
}

//---------------------------------------------------------------------------

- (BOOL)loadDataRepresentation:(NSData*)data ofType:(NSString*)docType
{/*
	"Insert code here to read your document from the given data.  You can
	also choose to override -loadFileWrapperRepresentation:ofType: or
	-readFromFile:ofType: instead."
    
	"For applications targeted for Tiger or later systems, you should use
	the new Tiger API readFromData:ofType:error:.  In this case you can also
	choose to override -readFromURL:ofType:error: or
	-readFromFileWrapper:ofType:error: instead."
*/
	MyDocument*		doc = [NSKeyedUnarchiver unarchiveObjectWithData:data];

	if (doc == nil)
		return NO;

	return YES;
}

//---------------------------------------------------------------------------

- (void)encodeWithCoder:(NSCoder*)enc
{
	[enc encodeObject:mA2 forKey:@"AppleII"];
}

//---------------------------------------------------------------------------

- (id)initWithCoder:(NSCoder*)dec
{
	[super init]; // or [super initWithCoder:dec] if subclassing

	return self;
}

//---------------------------------------------------------------------------
@end
