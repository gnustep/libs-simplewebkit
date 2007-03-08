/* simplewebkit
   WebFrameView.m

   Copyright (C) 2007 Free Software Foundation, Inc.

   Author: Dr. H. Nikolaus Schaller

   This file is part of the GNUstep Database Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
*/


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
