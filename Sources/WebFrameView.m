//
//  WebFrameView.m
//  mySTEP
//
//  Created by Dr. H. Nikolaus Schaller on Mon Jan 05 2004.
//  Revised May 2006
//  Copyright (c) 2004 DSITRI. All rights reserved.
//

#import "Private.h"
#import <WebKit/WebFrameView.h>
#import <WebKit/WebFrame.h>

@implementation WebFrameView

// The first level below this WebFrameView is a NSScrollView (if we allow scrolling).
// The elements to be displayed are laid out properly in the ClipView area of that scroll view.
// They can be e.g. NSTextView, NSPopUpButton, NSTextField, NSButton, and another WebFrameView depending
// on the tags found in the HTML source

- (id) initWithFrame:(NSRect) rect;
{
	if((self=[super initWithFrame:rect]))
		{
		NSScrollView *sv=[[NSScrollView alloc] initWithFrame:rect];
		[sv setAutoresizingMask:(NSViewWidthSizable|NSViewHeightSizable)];	// autoresize if we do
		[sv setAutohidesScrollers:YES];
		[self addSubview:sv];
		[sv release];
		}
	return self;
}

- (void) _setDocumentView:(NSView *) view;
{
	[view setAutoresizingMask:(NSViewWidthSizable|NSViewHeightSizable)];	// autoresize if we do
	[[[self subviews] lastObject] setDocumentView:view];
	[view setNeedsDisplay:YES];
}

- (void) _setWebFrame:(WebFrame *) wframe;
{
	ASSIGN(_webFrame, wframe);
}

- (void) dealloc;
{
	[_webFrame release];
	[super dealloc];
}

- (BOOL) allowsScrolling;
{
	NSScrollView *sv=[[self subviews] lastObject];
	return [sv hasHorizontalScroller] || [sv hasVerticalScroller];
}

- (WebFrame *) webFrame; { return _webFrame; }
- (NSView *) documentView; { return [[[self subviews] lastObject] documentView]; }

- (void) setAllowsScrolling:(BOOL) flag;
{
	NSScrollView *sv=[[self subviews] lastObject];
	[sv setHasHorizontalScroller:flag];
	[sv setHasVerticalScroller:flag];
}

- (void) drawRect:(NSRect) rect;
{
	// should draw frame background here
	[@"WebFrameView" drawAtPoint:NSMakePoint(30,30) withAttributes:nil];
}

@end