
@interface AboutPanel : NSPanel
{
	IBOutlet	NSControl*		mVersion;
	IBOutlet	NSTextField*	mCursorCover;
	
	NSTimer*	mStrober;
}
@end
