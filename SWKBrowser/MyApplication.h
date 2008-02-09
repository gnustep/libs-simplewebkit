//
//  MyApplication.h
//
//  Created by Dr. H. Nikolaus Schaller on Sun Aug 17 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

#define HISTORY_PATH [NSHomeDirectory() stringByAppendingPathComponent:@"Library/SWKBrowser/History.plist"]
#define BOOKMARKS_PATH [NSHomeDirectory() stringByAppendingPathComponent:@"Library/SWKBrowser/Bookmarks.plist"]
#define DOWNLOADS_PATH [NSHomeDirectory() stringByAppendingPathComponent:@"Library/SWKBrowser/Downloads.plist"]

@interface MyApplication : NSObject
{
	IBOutlet NSOutlineView *activity;
	IBOutlet NSMenuItem *separatorBeforeHistory;
	IBOutlet NSMenuItem *separatorAfterHistory;
	NSMutableArray *activities;		// array of subresources
}

@end
