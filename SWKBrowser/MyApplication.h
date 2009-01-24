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
}

- (IBAction) showBookmarks:(id) sender;
- (IBAction) singleClick:(id) sender;
- (void) addBookmark:(NSString *) title forURL:(NSString *) str;

@end
