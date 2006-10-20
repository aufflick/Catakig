/*	Catakig-Cocoa.h

	Primary header for source files of the MacOS X application.  Not used
	by lower-level libraries.
*/
#import "MyUtils.h"
#import "LibAppleII.h"

@class ScreenView;

enum
{
	kJoyMouse = 0, // mechanisms for paddle & joystick control
	kJoyKeypad,
//	kJoyCenteringKeypad, kJoyReal,
};


typedef struct
{
	int32_t		monochromeHue;		// low 24 bits: R, G, B
	BOOL		beepsOn,
				keepBackupFiles,
				firstLaunch;
	uint8_t		joystickControl;	// = kJoyMouse, etc.

#if 0
	BOOL		monochromeGlow;
	BOOL		showHelpTips;
	BOOL		moreAlerts;
	uint8_t		frameRate;			// 20, 30, or 60
	uint8_t		skipLines;
#endif

} Prefs;


extern struct CatakigGlobals
{
	NSBundle*				bundle;
	NSDocumentController*	docMgr;
	NSFileManager*			fileMgr;
	NSHelpManager*			helpMgr;
//	NSNull*					null;
	NSPasteboard*			pboard;
	NSWorkspace*			workspace;

	Prefs			prefs;
	AudioUnit		audioUnit;
//	BOOL			inFullScreenMode;
	ScreenView*		activeScreen;
} G;


void		BeepFor(BOOL);
void		ErrorAlert(NSWindow*, NSString*, NSString*);
void		FatalErrorAlert(NSString*, NSString*);
void		SetMouseRange(void);

OSStatus	AU_Open(AudioUnit*);
OSStatus	AU_SetBufferFrameSize(AudioUnit, UInt32);
void		AU_Close(AudioUnit*);

BOOL		GL_CheckExtension(const char* name);
void		GL_ClearBothBuffers(void);
void		GL_PrepareViewport(int viewWidth, int viewHeight);
void		GL_PreparePalette(void);
