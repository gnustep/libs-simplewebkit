/* simplewebkit
   WebFrameView.m

   Copyright (C) 2007 Free Software Foundation, Inc.

   Author: Dr. H. Nikolaus Schaller

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

// - (BOOL) isFlipped; { return YES; }

// The first level below this WebFrameView is a NSScrollView.
// The elements to be displayed are the documentView of that scroll view.
// They can be e.g. NSTextView, NSImageView or another WebFrameView depending on the tags found in the HTML source

- (id) initWithFrame:(NSRect) rect;
{
	if((self=[super initWithFrame:rect]))
		{
		NSScrollView *scrollView=[[[NSScrollView alloc] initWithFrame:[self bounds]] autorelease];
		[self setAutoresizingMask:(NSViewWidthSizable|NSViewHeightSizable)];	// autoresize
		[scrollView setAutoresizingMask:(NSViewWidthSizable|NSViewHeightSizable)];	// autoresize
		[scrollView setBorderType:NSNoBorder];
		[scrollView setHasHorizontalScroller:YES];
		[scrollView setHasVerticalScroller:YES];
#if defined(__mySTEP__) || defined(GNUSTEP) || MAC_OS_X_VERSION_10_2 < MAC_OS_X_VERSION_MAX_ALLOWED
		[scrollView setAutohidesScrollers:YES];	// default
#endif
		[self addSubview:scrollView];
		}
	return self;
}

- (void) _setDocumentView:(NSView *) view;
{
	// FIXME: due to some strange settings, this toggles visibility of the horizontal scroller
	[[[self subviews] lastObject] setDocumentView:view];
}

- (void) _setWebFrame:(WebFrame *) wframe;
{
	ASSIGN(_webFrame, wframe);
}

- (void) dealloc;
{
	[_webFrame release];
	// FIXME: when do we do [[_webFrame parentFrame] _removeChild:_webFrame];	// ???
	[super dealloc];
}

- (BOOL) allowsScrolling;
{
	NSScrollView *sv=[[self subviews] lastObject];
	return [sv hasHorizontalScroller] || [sv hasVerticalScroller];
}

- (WebFrame *) webFrame; { return _webFrame; }
- (NSView <WebDocumentView> *) documentView; { return [(WebFrameView *) [[self subviews] lastObject] documentView]; }

- (NSRect) _recommendedDocumentFrame;
{
	return (NSRect) { NSZeroPoint, [[(WebFrameView *) [[self subviews] lastObject] contentView] bounds].size };
}

- (void) setAllowsScrolling:(BOOL) flag;
{
	NSScrollView *sv=[[self subviews] lastObject];
	[sv setHasHorizontalScroller:flag];
	[sv setHasVerticalScroller:flag];
}

// - (void) drawRect:(NSRect) rect;
// {
	// should draw any frame background here
// }

@end
