/*	MyUtils.h

	My own (CK's) generally useful additions to the Cocoa/GNUstep classes
	-- not specific to any particular project.
*/
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#import <sys/types.h>
//mport <fcntl.h>
#import <stdint.h>
#import <unistd.h>

//---------------------------------------------------------------------------
@interface NSData (MyUtils)

+ (NSData*)		BZCompressBytes:(const void*)src length:(unsigned)srcLen
					level:(int)level;

@end
//---------------------------------------------------------------------------
@interface NSMovie (MyUtils)

- (id)			InitWithResource:(NSString*)fname;

@end
//---------------------------------------------------------------------------
@interface NSObject (MyUtils)

- (id)			Release;

@end
//---------------------------------------------------------------------------
@interface NSOpenGLContext (MyUtils)

- (void)				SetSwapInterval:(long)interval;
- (NSOpenGLContext*)	MakeCurrentContext;

@end
//---------------------------------------------------------------------------
@interface NSOpenGLView (MyUtils)

- (NSOpenGLContext*)	MakeCurrentContext;
- (void)				FlushBuffer;
- (NSBitmapImageRep*)	ReadPixels;
- (void)				PrepareToMiniaturize;

@end
//---------------------------------------------------------------------------
@interface NSPanel (MyUtils)

- (int)			RunModal;
- (IBAction)	StopModal:(id)sender;

@end
//---------------------------------------------------------------------------
@interface NSPasteboard (MyUtils)

- (NSString*)	GetString;
- (BOOL)		SetString:(NSString*)str;
- (BOOL)		SetData:(NSData*)data forType:(NSString*)type;

@end
//---------------------------------------------------------------------------
@interface NSScreen (MyUtils)

+ (NSScreen*)			MenuBarScreen;

#ifdef __CGDIRECT_DISPLAY_H__
- (CGDirectDisplayID)	DirectDisplayID;
#endif

@end
//---------------------------------------------------------------------------
@interface NSString (MyUtils)

- (BOOL)		IsReadableFile;
- (BOOL)		Matches:(const regex_t*)rex;
- (BOOL)		ExtensionMatches:(const regex_t*)rex;
- (BOOL)		SetFileCreator:(uint32_t)cCode andType:(uint32_t)tCode;
- (BOOL)		SetFileExtension:(NSString*)ext;
- (uint32_t)	FileTypeCode;
- (BOOL)		Stat:(struct stat*)st;
- (NSString*)	PathForResource;
- (BOOL)		Truncate:(size_t)length;

@end
//---------------------------------------------------------------------------
@interface NSUserDefaults (MyUtils)

- (BOOL)		RegisterBool:(BOOL)value forKey:(NSString*)key;
- (int)			RegisterInteger:(int)value forKey:(NSString*)key;
- (float)		RegisterFloat:(float)value forKey:(NSString*)key;

@end
//---------------------------------------------------------------------------
@interface NSView (MyUtils)

- (BOOL)		MakeFirstResponder;

@end
//---------------------------------------------------------------------------
