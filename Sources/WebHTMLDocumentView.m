/* simplewebkit
   WebHTMLDocumentView.m

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
#import <WebKit/WebFrameLoadDelegate.h>
#import "WebHTMLDocumentView.h"


@implementation _WebHTMLDocumentView

// NSView overrides

- (id) initWithFrame:(NSRect) rect;
{
	if((self=[super initWithFrame:rect]))
		{
		[self setAutoresizingMask:(NSViewWidthSizable|NSViewHeightSizable)];
		// set other attributes (selectable, editable etc.)
		[self setEditable:NO];
		[self setSelectable:YES];
		[self setHorizontallyResizable:NO];
		[self setVerticallyResizable:YES];
		[self setTextContainerInset:NSMakeSize(2.0, 4.0)];	// leave some margin
	//	[self setLinkTextAttributes: ]
	//	[self setMarkedTextAttributes: ]
		// attach a defalt context menu (Back, Forward etc.) for HTML pages
		}
	return self;
}

- (void) drawRect:(NSRect) rect;
{
#if 0
	NSLog(@"%@ drawRect:%@", self, NSStringFromRect(rect));
#endif
	if(_needsLayout)
		{
		// is it safe to call this here? It needs very precise tracking of dirty rects...
		// well, we can move th subviews since they are usually drawn afterwards
		// but changing the layout may call setFrame:
		[self layout];
		}
	[super drawRect:rect];
}

// @protocol WebDocumentView

- (void) dataSourceUpdated:(WebDataSource *) source;
{
#if 1
	NSLog(@"dataSourceUpdated: %@", source);
#endif
//	[self setDataSource:source];
//	[self setDelegate:[source webFrame]];	// should be someone who can handle clicks on links and knows the base URL
#if 1	// show view hierarchy
	while(self)
		NSLog(@"%p: %@", self, self), self=(_WebHTMLDocumentView *) [self superview];
#endif	
}

- (void) layout;
{ // do the layout of subviews
	DOMHTMLHtmlElement *html=(DOMHTMLHtmlElement *) [[[[_dataSource webFrame] DOMDocument] firstChild] firstChild];
	DOMHTMLElement *body=(DOMHTMLElement *) [html lastChild];	// either <body> or could be a <frameset>
#if 1
	NSLog(@"%@ %@", NSStringFromClass(isa), NSStringFromSelector(_cmd));
#endif
	_needsLayout=NO;
	[body _layout:self];	// process the <body> tag (could also be a <frameset>)
	// check if we did load with an anchor (dataSource request has an anchor part) and it is already defined
	// if possible scroll us to the anchor position
}

- (void) setDataSource:(WebDataSource *) source;
{
	_dataSource=source;
}

- (void) setNeedsLayout:(BOOL) flag;
{
#if 1
	NSLog(@"setNeedsLayout");
#endif
	_needsLayout=flag;
	[self setNeedsDisplay:YES];
}

- (void) viewDidMoveToHostWindow;
{
}

- (void) viewWillMoveToHostWindow:(NSWindow *) win;
{
}

// @protocol WebDocumentText

- (NSAttributedString *) attributedString; { return [self textStorage]; }
- (void) deselectAll; { NIMP; }
- (void) selectAll; { NIMP; }
- (NSAttributedString *) selectedAttributedString;  { return NIMP; }
- (NSString *) selectedString;  { return [[self selectedAttributedString] string]; }
- (NSString *) string;  { return [[self attributedString] string]; }
- (BOOL) supportsTextEncoding; { return NO; }	// CHECKME: or YES???

@end

@implementation _WebHTMLDocumentFrameSetView

// NSView overrides

- (id) initWithFrame:(NSRect) rect;
{
	if((self=[super initWithFrame:rect]))
		{
		[self setAutoresizingMask:(NSViewWidthSizable|NSViewHeightSizable)];
		}
	return self;
}

- (void) drawRect:(NSRect) rect;
{
#if 1
	NSLog(@"%@ drawRect:%@", self, NSStringFromRect(rect));
#endif
	if(_needsLayout)
		[self layout];
	[super drawRect:rect];
}

// @protocol WebDocumentView

- (void) dataSourceUpdated:(WebDataSource *) source;
{
}

- (void) layout;
{ // do the layout especially of subviews
	DOMHTMLHtmlElement *html=(DOMHTMLHtmlElement *) [[[[_dataSource webFrame] DOMDocument] firstChild] firstChild];
	DOMHTMLElement *frameset=(DOMHTMLElement *) [html lastChild];	// should be a <frameset>
#if 1
	NSLog(@"%@ %@", NSStringFromClass(isa), NSStringFromSelector(_cmd));
#endif
	_needsLayout=NO;
	[frameset _layout:self];	// process the <frameset> tag
}

- (void) setDataSource:(WebDataSource *) source;
{
	_dataSource=source;
}

- (void) setNeedsLayout:(BOOL) flag;
{
	_needsLayout=flag;
	[self setNeedsDisplay:YES];
}

- (void) viewDidMoveToHostWindow;
{
}

- (void) viewWillMoveToHostWindow:(NSWindow *) win;
{
}

// @protocol WebDocumentText

- (NSAttributedString *) attributedString;
{ // collect from all subviews...
	return NIMP;
}

- (void) deselectAll; { NIMP; }
- (void) selectAll; { NIMP; }
- (NSAttributedString *) selectedAttributedString;  { return NIMP; }
- (NSString *) selectedString;  { return [[self selectedAttributedString] string]; }
- (NSString *) string;  { return [[self attributedString] string]; }
- (BOOL) supportsTextEncoding; { return NO; }	// CHECKME: or YES???

@end

@implementation NSText (NSTextAttachment)

- (NSText *) currentEditor;
{
	return nil;	// someone calls that...
}

@end

@implementation NSTextAttachmentCell (NSTextAttachment)

+ (NSTextAttachment *) textAttachmentWithCellOfClass:(Class) class;
{
	NSTextAttachment *attachment=[[[NSTextAttachment alloc] initWithFileWrapper:nil] autorelease];
	[attachment setAttachmentCell:[[[class alloc] init] autorelease]];		
	return attachment;
}

@end

@implementation NSButtonCell (NSTextAttachment)

- (NSPoint) cellBaselineOffset; { return NSMakePoint(0.0, -10.0); }
- (BOOL) wantsToTrackMouse; { return YES; }

// add missing methods

@end

@implementation NSActionCell (NSTextAttachment)

- (NSPoint) cellBaselineOffset; { return NSMakePoint(0.0, -10.0); }
- (BOOL) wantsToTrackMouse; { return YES; }

	// add missing methods

@end

@implementation NSTextFieldCell (NSTextAttachment)

- (NSSize) cellSize; { return NSMakeSize(200.0, 22.0); }		// should depend on font&SIZE parameter

- (NSPoint) cellBaselineOffset; { return NSMakePoint(0.0, -10.0); }
- (BOOL) wantsToTrackMouse; { return YES; }

// add missing methods

@end

@implementation NSPopUpButtonCell (NSTextAttachment)

- (NSSize) cellSize; { return NSMakeSize(200.0, 22.0); }		// should depend on font&SIZE parameter

- (NSPoint) cellBaselineOffset; { return NSMakePoint(0.0, -10.0); }
- (BOOL) wantsToTrackMouse; { return YES; }

	// add missing methods

@end
