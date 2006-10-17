
@interface A2DiskDrive : NSObject <A2PrDiskDrive>
{
	fd_t		mOrigFD,		// open FD to original disk image
				mWorkFD;		// open FD to nybblized version
@public
	NSString*	mFilePath;		// path to disk image file
	uint8_t		mContent;		// kA2DiskNone, etc.
	BOOL		mDiskModified;	// any writes since disk was loaded?

	uint8_t*	mTrackBase;		// base of active track (circular buffer)
	unsigned	mTheta,			// current byte position in active track
				mTrackSize;		// total number of bytes in track
	int			mTrackIndex,	// index of active track
				mTrackMax;		// largest allowed track index
}

- (id)			InitUsingBuffer:(uint8_t [])buffer;
- (BOOL)		SeekTrack:(unsigned)reqTrack;
+ (BOOL)		ShouldShowFilename:(NSString*)path;

@end
