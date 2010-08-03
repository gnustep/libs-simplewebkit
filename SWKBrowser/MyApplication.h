//
//  MyApplication.h
//
//  Created by Dr. H. Nikolaus Schaller on Sun Aug 17 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface MyApplication : NSObject
{
	IBOutlet NSOutlineView *activity;
	IBOutlet NSMenuItem *separatorBeforeHistory;
	IBOutlet NSMenuItem *separatorAfterHistory;
	NSMutableArray *activities;		// array of subresources
	IBOutlet NSPanel *bookmarksPanel;
	IBOutlet NSOutlineView *bookmarksTable;
	NSMutableDictionary *bookmarks;
	IBOutlet NSWindow *prefsWindow;
	IBOutlet NSFormCell *homePref;
	IBOutlet NSButtonCell *loadImagesPref;
	IBOutlet NSButtonCell *enableJavaScriptPref;
	IBOutlet NSButtonCell *popupBlockerPref;
	IBOutlet NSButtonCell *privateBrowsingPref;
	IBOutlet NSButtonCell *enableCSSPref;
}

- (IBAction) openLocation:(id) sender;
- (IBAction) showBookmarks:(id) sender;
- (IBAction) showPreferences:(id) sender;
- (IBAction) prefChanged:(id) sender;
- (IBAction) singleClick:(id) sender;
- (void) addBookmark:(NSString *) title forURL:(NSString *) str;
- (void) removeSubresourcesForFrame:(WebFrame *) frame;	// used in activity window

@end
