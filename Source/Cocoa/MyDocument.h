
@class A2Computer, ScreenView, IndicatorLight;

@interface MyDocument : NSDocument <NSCoding>
{
	IBOutlet A2Computer*		mA2;
	IBOutlet ScreenView*		mScreen;
	IBOutlet IndicatorLight*	mSpeedLight;
	IBOutlet NSTextField*		mModelEmblem;
	IBOutlet NSTextField*		mDDrive0;
	IBOutlet NSTextField*		mDDrive1;

	IBOutlet NSView*			mSaveImageView;
	IBOutlet NSControl*			mSaveImageTypes;
	IBOutlet NSControl*			mSaveImageAddSuffix;

	IBOutlet NSView*			mPrSessionView;
	IBOutlet NSControl*			mPrSessionFilter;
	IBOutlet NSTextField*		mPrSessionSize;
	IBOutlet NSControl*			mPrSessionAddSuffix;

	int		mRunState; // low 2 bits: speed;  higher bits: pause level
	int		mFileFilter;
}

+ (void)		AllNeedDisplay;

@end

@interface MyDocument (Audio)

- (void)		Pause;
- (void)		Unpause;
- (BOOL)		IsRunning;
- (IBAction)	HitSpeedControl:(id)sender;

@end

@interface MyDocument (Actions)

- (IBAction)	ClearPrintSession:(id)sender;
- (IBAction)	CopyScreenImage:(id)sender;
- (IBAction)	PasteScreenText:(id)sender;
- (IBAction)	CopyScreenText:(id)sender;
- (IBAction)	SaveScreenImage:(id)sender;
- (IBAction)	HitDiskDrive:(id)sender;

@end
