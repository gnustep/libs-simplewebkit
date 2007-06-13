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
	// JavaScript window
	IBOutlet NSTextField *command;
	IBOutlet NSTextField *result;
	// document source
	IBOutlet NSTextView *docSource;
	// DOM Tree
    NSMutableSet *domNodes;
	IBOutlet NSOutlineView *domTree;
	IBOutlet NSTextView *domSource;
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

@end
