/*  A2DiskImages.h

	Header formats of Apple II disk image files.
*/

typedef struct
{/*
	Header format of 2IMG disk images.  All integer fields are
	little-endian.  Positions and lengths are in bytes.
*/
	char		m2IMG[4],			// "2IMG"
				mCreator[4];		// "CTKG", or other producer
	uint16_t	mHeaderLength,		// 64
				mVersion;			// 0 or 1

	uint8_t		mFormat,			// 0=DO, 1=PO, 2=NIB
				mPad1[3],
				mVolNumber,
				mGotVolume,			// bit 0
				mPad2,
				mLocked;			// bit 7

	uint32_t	mNumBlocks,			// for PO only

				mDataPos, mDataLen,
				mCommentPos, mCommentLen,
				mAppDataPos, mAppDataLen;

	char		mPad3[16];			// pad out to 64 bytes

} A2Header2IMG;


typedef struct
{/*
	Header format of DiskCopy 4.x disk images.  All integer fields are
	big-endian.  Sizes are in bytes.  Data blocks start at offset 84
	from the file's beginning.  Tag data can be ignored.
*/
	char		mDiskName[64];		// Pascal string

	uint32_t	mDataSize,		mTagSize,
				mDataChecksum,	mTagChecksum;

	uint8_t		mDiskFormat,
				mFormatByte,
				mPrivate[2];

} A2HeaderDiskCopy4;

