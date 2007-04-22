//
//  WebFrameLoadDelegate.h
//  mySTEP
//
//  Created by Dr. H. Nikolaus Schaller on Sat Jan 27 2007.
//  Copyright (c) 2007 DSITRI. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class WebView, WebFrame, WebScriptObject;

// used as frameLoadDelegate of WebView

@interface NSObject (WebFrameLoadDelegate)

- (void) webView:(WebView *) sender didReceiveTitle:(NSString *) title forFrame:(WebFrame *) frame;
- (void) webView:(WebView *) sender didStartProvisionalLoadForFrame:(WebFrame *) frame;
- (void) webView:(WebView *) sender didCommitLoadForFrame:(WebFrame *) frame;
- (void) webView:(WebView *) sender willCloseFrame:(WebFrame *) frame;
- (void) webView:(WebView *) sender didFinishLoadForFrame:(WebFrame *) frame;
- (void) webView:(WebView *) sender willPerformClientRedirectToURL:(NSURL *) url delay:(NSTimeInterval) seconds fireDate:(NSDate *) date forFrame:(WebFrame *) frame;
- (void) webView:(WebView *) sender didCancelClientRedirectForFrame:(WebFrame *) frame;

	// not yet called

- (void) webView:(WebView *) sender didChangeLocationWithinPageForFrame:(WebFrame *) frame;
- (void) webView:(WebView *) sender didFailLoadWithError:(NSError *) error forFrame:(WebFrame *) frame;
- (void) webView:(WebView *) sender didFailProvisionalLoadWithError:(NSError *) error forFrame:(WebFrame *) frame;
- (void) webView:(WebView *) sender didReceiveIcon:(NSImage *) image forFrame:(WebFrame *) frame;
- (void) webView:(WebView *) sender serverRedirectedForDataSource:(WebFrame *) frame;
- (void) webView:(WebView *) sender windowScriptObjectAvailable:(WebScriptObject *) script;

@end

