//
//  MyDocument.h
//  SimpleWebKit
//
//  Created by H. Nikolaus Schaller on 07.04.07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface MyDocument : NSDocument
{
	NSMutableArray *destinations;
	IBOutlet NSComboBoxCell *currentURL;	// web address/Google search field
	IBOutlet WebView *webView;			// the Web view
	IBOutlet NSTextField *status;		// the Web view
	IBOutlet NSButton *backButton;
	IBOutlet NSButton *forwardButton;	
	// JavaScript window
	IBOutlet NSTextField *command;
	IBOutlet NSTextView *result;
	// document source
	IBOutlet NSTextView *docSource;
	// DOM Hierarchy
	NSMutableSet *domNodes;
	IBOutlet NSOutlineView *domTree;
	IBOutlet NSTextView *domSource;
	id currentItem;
	IBOutlet NSTableView *domAttribs;
	id currentCSS;
	IBOutlet NSTableView *domCSS;
	// Style Sheets
	NSMutableSet *styleNodes;
	IBOutlet NSOutlineView *styleSheets;
	// View Hierarchy
	IBOutlet NSOutlineView *viewTree;
	IBOutlet NSTextView *viewSource;
	NSView *currentView;
	NSMutableArray *viewAttribNames;
	NSMutableArray *viewAttribValues;
	IBOutlet NSTableView *viewAttribs;
	// History View
	IBOutlet NSTableView *historyTable;
	IBOutlet NSTableView *backForwardTable;
	// Add Bookmarks
	IBOutlet NSPanel *addBookmarkWindow;
	IBOutlet NSFormCell *bookmarkURL;
	IBOutlet NSFormCell *bookmarkTitle;
	// Misc
	NSURL *openfile;		// used only during Open...
	BOOL hasToolbar;
	BOOL hasStatusBar;
}

- (WebView *) webView;
- (void) showStatus:(NSString *) str;
- (void) setLocationAndLoad:(NSURL *) url;
- (void) setLocation:(NSURL *) url;

- (IBAction) home:(id) Sender;
- (IBAction) script:(id) sender;
- (IBAction) loadPageFromComboBox:(id) sender;
- (IBAction) loadPageFromMenuItem:(id) sender;
- (IBAction) scriptFromMenuItem:(id) sender;
- (IBAction) openJavaScriptConsole:(id) sender;
- (IBAction) showSource:(id) sender;
- (IBAction) showDOMTree:(id) sender;
- (IBAction) showStyleSheets:(id) sender;
- (IBAction) showViewTree:(id) sender;
- (IBAction) goBack:(id) sender;
- (IBAction) goForward:(id) sender;
- (IBAction) addBookmark:(id) sender;
- (IBAction) cancelBookmark:(id) sender;
- (IBAction) saveBookmark:(id) sender;

- (IBAction) singleClick:(id) sender;
- (IBAction) doubleClick:(id) sender;

@end
