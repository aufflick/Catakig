#import "Catakig-Cocoa.h"
#import "MyDocument.h"

@implementation MyDocument (Actions)
//---------------------------------------------------------------------------

- (IBAction)ClearPrintSession:(id)sender
{/*
	Clears this Apple II's accumulated print session.
*/
	[mA2 ClearPrintSession];
	BeepFor(YES);
}

//---------------------------------------------------------------------------

- (IBAction)CopyScreenImage:(id)sender
{/*
	Copies this screen's content to the general pasteboard as a TIFF
	image.
*/
	NSData*		data;

	[self Pause];
	data = [[mScreen ReadPixels]
		representationUsingType:NSTIFFFileType properties:nil ];
	[G.pboard SetData:data forType:NSTIFFPboardType];
	[self Unpause];
	BeepFor(YES);
}

//---------------------------------------------------------------------------

- (IBAction)PasteScreenText:(id)sender
{/*
	Enters the pasteboard's text string (if one exists) into this Apple II,
	as if all the characters had been typed.
*/
	NSString*	str = [G.pboard GetString];

	if (str)
	{
		[self Pause];
		[mA2 InputChars:str];
		[self Unpause];
	}
	else
		BeepFor(NO);
}

//---------------------------------------------------------------------------

- (IBAction)CopyScreenText:(id)sender
{/*
	Copies the Apple II's text screen content (visible or not) to the
	general pasteboard as one giant string.
*/
	NSString*   str;

	[self Pause];
	str = [mA2 TextScreenAsString:YES];
	[self Unpause];
	[G.pboard SetString:str];
}

//---------------------------------------------------------------------------

- (IBAction)SaveScreenImage:(id)sender
{/*
	Saves this Apple II's screen content to an image file of the user's
	choosing.
*/
	NSSavePanel*	panel = [NSSavePanel savePanel];

//	[mSaveImageView retain]; // need retain??

	[panel setMessage:@"Save Screen Image to File"];
	[panel setAccessoryView:mSaveImageView]; // need retain??
//	[panel setCanSelectHiddenExtension:YES];

	[panel beginSheetForDirectory:nil
		file:				nil // @"screen"
		modalForWindow:		[mScreen window]
		modalDelegate:		self
		didEndSelector:		@selector(_SaveScreenImage2:resp:sender:)
		contextInfo:		sender ];
}

//---------------------------------------------------------------------------

- (void)_SaveScreenImage2:(NSSavePanel*)panel
	resp:(int)userResponse sender:(id)sender
{
	if (userResponse != NSOKButton)
		return;

	NSData*		data;
	NSString*	fpath     = [panel filename];
	int			fileType  = [mSaveImageTypes selectedTag];
	NSString*	extensions[/*NSBitmapImageFileType*/] =
					{ @"tiff", @"bmp", @"gif", @"jpeg", @"png" };

	if ([mSaveImageAddSuffix intValue] == NSOnState)
		fpath = [fpath stringByAppendingPathExtension:
			extensions[fileType]];

	data = [[mScreen ReadPixels]
		representationUsingType:fileType properties:nil];
	if (data == nil)
	{
		ErrorAlert([mScreen window],
			@"Image can't be created.",
			@"Allocation problem??");
		return;
	}

	if (not [data writeToFile:fpath atomically:NO])
		ErrorAlert([mScreen window],
			@"Sorry, cannot save the image file.",
			@"Check that folder write permissions and available disk "
			"space are sufficient.");
}

//---------------------------------------------------------------------------

- (IBAction)printDocument:(id)sender
{
	NSSavePanel*	panel = [NSSavePanel savePanel];

//	[mPrSessionView retain];
	[mPrSessionSize setStringValue:
		[NSString stringWithFormat:@"%lu bytes",
			[mA2 SizeOfPrintSession] ]];

	[panel setAccessoryView:mPrSessionView];
	[panel setMessage:@"Save Print Session to File"];
//	[panel setTitle:@"the title"];

	[panel beginSheetForDirectory:nil
		file:				nil
		modalForWindow:		[mScreen window]
		modalDelegate:		self
		didEndSelector:		@selector(_printDocument2:resp:sender:)
		contextInfo:		sender ];
}

//---------------------------------------------------------------------------

- (void)_printDocument2:(NSSavePanel*)panel
	resp:(int)userResponse sender:(id)sender
{
	if (userResponse != NSOKButton)
		return;

	NSString*	fpath  = [panel filename];
	int			filter = [mPrSessionFilter selectedTag];

	if ([mA2 SavePrintSessionAs:filter toFile:fpath])
	{
		BeepFor(YES);
		return;
	}

	BeepFor(NO); // and alert!!
}

//---------------------------------------------------------------------------

- (IBAction)HitDiskDrive:(id)sender
{/*
	Called when user invokes "Load" or "Unload" on a disk drive.
*/
	int					index = abs([sender tag]) - 1;
	id<A2PrDiskDrive>   ddrive = [mA2 DiskDrive:index];
	NSControl*			dname = (&mDDrive0)[index];

	if ([sender tag] < 0) // then unload drive and return
	{
		[ddrive Unload];
		[dname setStringValue:@""];
		return;
	}


	NSOpenPanel*	panel = [NSOpenPanel openPanel];
	NSString*		dirStart = nil;
	NSString*		headers[/*drive index*/] = {
						@"Load Floppy Drive #1",
						@"Load Floppy Drive #2" };

	mFileFilter = 1; // will filter disk image file names
//	dirStart = [[G.bundle bundlePath]
//		stringByAppendingPathComponent:@"../Disks"];

	[panel setDelegate:self];
	[panel setAllowsMultipleSelection:NO];
	[panel setMessage:headers[index]];
//	[panel setPrompt:@"Load"]; //??
//	[panel setNameFieldLabel:@"Label"];

	[panel beginSheetForDirectory:dirStart
		file:				nil
		types:				nil // (NSArray*)fileTypes
		modalForWindow:		[mScreen window]
		modalDelegate:		self
		didEndSelector:		@selector(_HitDiskDrive2:resp:sender:)
		contextInfo:		sender ];
}

//---------------------------------------------------------------------------

- (void)_HitDiskDrive2:(NSOpenPanel*)panel
	resp:(int)userResponse sender:(id)sender
{
	mFileFilter = 0;
	if (userResponse != NSOKButton)
		return;

	int					index = abs([sender tag]) - 1;
	id<A2PrDiskDrive>   ddrive = [mA2 DiskDrive:index];
	NSTextField*		dname = (&mDDrive0)[index];

	if ([ddrive Load:[panel filename]])
	{
		[dname setTextColor:( [ddrive Content] == kA2DiskReadOnly?
			[NSColor yellowColor] : [NSColor greenColor] )];
		[dname setStringValue:[ddrive Label]];
		return;
	}

	[dname setStringValue:@""];
	ErrorAlert([mScreen window],
		@"Failed to load disk!",
		@"The chosen disk image does not seem to be in a valid format.");
}

//---------------------------------------------------------------------------

- (BOOL)panel:(id)panel shouldShowFilename:(NSString*)path
{
	if (mFileFilter == 0) // then no filtering to be done
		return YES;

	return [A2Computer ShouldShowDiskFilename:path];
}

//---------------------------------------------------------------------------
@end
