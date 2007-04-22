//
//  WebFrameView.h
//  mySTEP
//
//  Created by Dr. H. Nikolaus Schaller on Mon Jan 05 2004.
//  Revised May 2006
//  Copyright (c) 2004 DSITRI. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebDocument.h>

@class WebFrame;

@interface WebFrameView : NSView
{
	NSScrollView *_scrollView;	// the scroll view
	WebFrame *_webFrame;		// the frame we are asked to display
}

// The first level below this WebFrameView is a NSScrollView (if we allow scrolling).
// The elements to be displayed are laid out properly in the subviews of that scroll view.
// They can be e.g. NSTextView, NSPopUpButton, NSTextField, NSButton, or another WebFrameView depending
// on the tags found in the HTML source


- (BOOL) allowsScrolling;
- (NSView *) documentView;
- (WebFrame *) webFrame;
- (void) setAllowsScrolling:(BOOL) flag;
- (void) _setDocumentView:(NSView /* <WebDocumentView> */ *) view;
- (void) _setWebFrame:(WebFrame *) wframe;

@end
