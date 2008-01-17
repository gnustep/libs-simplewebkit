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
		{ // set other attributes (selectable, editable etc.)
		[self setEditable:NO];
		[self setSelectable:YES];
		[self setVerticallyResizable:YES];
		[self setHorizontallyResizable:YES];
		[self setTextContainerInset:NSMakeSize(2.0, 4.0)];	// leave some margin
		[[self textContainer] setWidthTracksTextView:YES];
		[self setAutoresizingMask:(NSViewWidthSizable|NSViewHeightSizable)];
	//	[self setLinkTextAttributes:blue ]
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
		[self layout];
	if(_backgroundImage)
		; // draw
	[super drawRect:rect];
}

// @protocol WebDocumentView

- (void) dataSourceUpdated:(WebDataSource *) source;
{
#if 1
	NSLog(@"dataSourceUpdated: %@", source);
#endif
#if 0	// show view hierarchy
	while(self)
		NSLog(@"%p: %@", self, self), self=(_WebHTMLDocumentView *) [self superview];
#endif	
}

- (void) layout;
{ // do the layout of subviews - NOTE: this is called from within drawRect!
	DOMHTMLHtmlElement *html=(DOMHTMLHtmlElement *) [[[[_dataSource webFrame] DOMDocument] firstChild] firstChild];
	DOMHTMLElement *body=(DOMHTMLElement *) [html lastChild];	// either <body> or could be a <frameset>
#if 1
	NSLog(@"%@ %@", NSStringFromClass(isa), NSStringFromSelector(_cmd));
#endif
	_needsLayout=NO;
	[body performSelector:@selector(_layout:) withObject:self afterDelay:0.0];	// process the <body> tag (could also be a <frameset>) from the runloop
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
	if(_needsLayout == flag)
		return;	// we already know
	_needsLayout=flag;
	if(flag)
		[self setNeedsDisplay:YES];	// trigger a drawRect
}

- (void) viewDidMoveToHostWindow;
{
	NIMP;
}

- (void) viewWillMoveToHostWindow:(NSWindow *) win;
{
	NIMP;
}

- (void) setLinkColor:(NSColor *) color
{
#if 1
	NSLog(@"setLinkColor: %@", color);
#endif
#if defined(__mySTEP__) || MAC_OS_X_VERSION_10_3 < MAC_OS_X_VERSION_MAX_ALLOWED
	if(color)
		[self setLinkTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:color, NSUnderlineColorAttributeName,
			[NSNumber numberWithInt:NSUnderlineStyleSingle], NSUnderlineStyleAttributeName,
			[NSCursor pointingHandCursor], NSCursorAttributeName,
			nil]];		// define link color
	else
		[self setLinkTextAttributes:nil];	// default
#endif
}

- (void) setBackgroundImage:(NSImage *) img
{
	ASSIGN(_backgroundImage, img);
	[self setNeedsDisplay:YES];
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
#if 1
	NSLog(@"attachment cell=%@", [attachment attachmentCell]);
#endif
	return attachment;
}

@end

#if 1 // dummy implementations so that we can use *any* NSCell as an attachment cell - unless overridden explicity in a subclass

@implementation NSCell (NSTextAttachment)

- (void) setAttachment:(NSTextAttachment *) anAttachment;	 { return; }
- (NSTextAttachment *) attachment; { return nil; }

- (NSRect) cellFrameForTextContainer:(NSTextContainer *) container
								proposedLineFragment:(NSRect) fragment
											 glyphPosition:(NSPoint) pos
											characterIndex:(unsigned) index;
{
	return (NSRect){ NSZeroPoint, [self cellSize] };
}

- (void) drawWithFrame:(NSRect)cellFrame
								inView:(NSView *)controlView
				characterIndex:(unsigned) index;
{
	[self drawWithFrame:cellFrame inView:controlView];
}

- (void) drawWithFrame:(NSRect)cellFrame
								inView:(NSView *)controlView
				characterIndex:(unsigned) index
				 layoutManager:(NSLayoutManager *) manager;
{
	[self drawWithFrame:cellFrame inView:controlView];
}

- (BOOL) trackMouse:(NSEvent *)event 
						 inRect:(NSRect)cellFrame 
						 ofView:(NSView *)controlTextView 
   atCharacterIndex:(unsigned) index
			 untilMouseUp:(BOOL)flag;
{
	return [self trackMouse:event inRect:cellFrame ofView:controlTextView untilMouseUp:flag];
}

- (BOOL) wantsToTrackMouse;
{
	return YES;
}

- (BOOL) wantsToTrackMouseForEvent:(NSEvent *) event
														inRect:(NSRect) rect
														ofView:(NSView *) controlView
									atCharacterIndex:(unsigned) index;
{
	return [self wantsToTrackMouse];
}

@end
#endif

@implementation NSButtonCell (NSTextAttachment)

- (NSPoint) cellBaselineOffset; { return NSMakePoint(0.0, -10.0); }
- (BOOL) wantsToTrackMouse; { return YES; }

// add missing methods

@end

@implementation NSActionCell (NSTextAttachment)

- (NSPoint) cellBaselineOffset; { return NSMakePoint(0.0, -10.0); }
- (BOOL) wantsToTrackMouse; { return YES; }

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

@implementation NSViewAttachmentCell

// show a generic view as an attachment cell (e.g. an WebFrameView for <iframe>)

- (void) dealloc;
{
	[view release];
	[super dealloc];
}

- (void) setView:(NSView *) v; { ASSIGN(view, v); }
- (NSView *) view; { return view; }

- (void) setAttachment:(NSTextAttachment *) anAttachment;	 { attachment=anAttachment; }
- (NSTextAttachment *) attachment; { return attachment; }

- (NSPoint) cellBaselineOffset; { return view?[view frame].origin:NSZeroPoint; }
- (NSSize) cellSize; { return view?[view frame].size:NSZeroSize; }

- (void) drawWithFrame:(NSRect)cellFrame
				inView:(NSView *)controlView
{
	[view setNeedsDisplayInRect:cellFrame];
	[view drawRect:cellFrame];
}

- (void) drawWithFrame:(NSRect)cellFrame
				inView:(NSView *)controlView
		characterIndex:(unsigned) index;
{
	[self drawWithFrame:cellFrame inView:controlView];
}

- (void) drawWithFrame:(NSRect)cellFrame
				inView:(NSView *)controlView
		characterIndex:(unsigned) index
		 layoutManager:(NSLayoutManager *) manager;
{
	[self drawWithFrame:cellFrame inView:controlView];
}

- (BOOL) trackMouse:(NSEvent *)event 
			 inRect:(NSRect)cellFrame 
			 ofView:(NSView *)controlTextView 
   atCharacterIndex:(unsigned) index
	   untilMouseUp:(BOOL)flag;
{
	return [self trackMouse:event inRect:cellFrame ofView:controlTextView untilMouseUp:flag];
}

- (BOOL) wantsToTrackMouse;
{
	return NO;
}

- (BOOL) wantsToTrackMouseForEvent:(NSEvent *) event
							inRect:(NSRect) rect
							ofView:(NSView *) controlView
				  atCharacterIndex:(unsigned) index;
{
	return [self wantsToTrackMouse];
}

@end

@implementation NSHRAttachmentCell

- (void) setAttachment:(NSTextAttachment *) anAttachment;	 { attachment=anAttachment; }
- (NSTextAttachment *) attachment; { return attachment; }

- (NSPoint) cellBaselineOffset; { return NSMakePoint(0.0, 1.0); }

- (NSRect) cellFrameForTextContainer:(NSTextContainer *) container
				proposedLineFragment:(NSRect) fragment
					   glyphPosition:(NSPoint) pos
					  characterIndex:(unsigned) index;
{ // make a text attachment cell that eats up the remaining space up to the end of the current fragment (minus line padding)
	fragment.size.width-=pos.x+2*[container lineFragmentPadding];	// should be the same as the containerInset.width
	fragment.size.height=5.0;
	fragment.origin=NSZeroPoint;	// it appears that we must return relative coordinates
	return fragment;
}

- (void) setShaded:(BOOL)shaded
{
    _shaded=shaded;
}

- (void) drawWithFrame:(NSRect)cellFrame
				inView:(NSView *)controlView
{ // draw a horizontal line
	NSPoint upLeft;
	NSPoint lowRight;
	NSRect bar;
	NSBezierPath *p;
	NSBezierPath *shadow;
	BOOL shaded;
	
	float lineWidth;
	
	shaded = YES;
//	if ([[element style] objectForKey:@"noshade"] != nil)
//		shaded = NO;	
	
	lineWidth = 5; // should get the interpreted attribute
	
	upLeft = NSMakePoint(NSMinX(cellFrame)+4, NSMidY(cellFrame)- lineWidth/2);
	lowRight = NSMakePoint(NSMaxX(cellFrame)-4, NSMidY(cellFrame)+lineWidth/2);
	

	
	if (_shaded)
	{
		lowRight = NSMakePoint(lowRight.x-1, lowRight.y-1);
		bar = NSMakeRect(upLeft.x, upLeft.y, lowRight.x-upLeft.x, lowRight.y-upLeft.y);
	
		p = [NSBezierPath bezierPath];
		[p setLineWidth:1.0];
		[p appendBezierPathWithRect: bar];
		[[NSColor blackColor] set];
		[p fill];
	
		shadow = [NSBezierPath bezierPath];
		[shadow moveToPoint:NSMakePoint(upLeft.x+1, lowRight.y+1)];
		[shadow lineToPoint:NSMakePoint(lowRight.x+1, lowRight.y+1)];
		[shadow lineToPoint:NSMakePoint(lowRight.x+1, upLeft.y-1)];
		[[NSColor redColor] set];
		[shadow stroke];
	}
	else
	{
		bar = NSMakeRect(upLeft.x, upLeft.y, lowRight.x-upLeft.x, lowRight.y-upLeft.y);
	
		p = [NSBezierPath bezierPath];
		[p setLineWidth:1.0];
		[p appendBezierPathWithRect: bar];
		[[NSColor blackColor] set];
		[p stroke];
	}
#if 0
	[[NSColor redColor] set];
	NSRectFill(cellFrame);
#endif

}

- (void) drawWithFrame:(NSRect)cellFrame
				inView:(NSView *)controlView
		characterIndex:(unsigned) index;
{
	[self drawWithFrame:cellFrame inView:controlView];
}

- (void) drawWithFrame:(NSRect)cellFrame
				inView:(NSView *)controlView
		characterIndex:(unsigned) index
		 layoutManager:(NSLayoutManager *) manager;
{
	[self drawWithFrame:cellFrame inView:controlView];
}

- (BOOL) trackMouse:(NSEvent *)event 
			 inRect:(NSRect)cellFrame 
			 ofView:(NSView *)controlTextView 
   atCharacterIndex:(unsigned) index
	   untilMouseUp:(BOOL)flag;
{
	return [self trackMouse:event inRect:cellFrame ofView:controlTextView untilMouseUp:flag];
}

- (BOOL) wantsToTrackMouse;
{
	return NO;
}

- (BOOL) wantsToTrackMouseForEvent:(NSEvent *) event
							inRect:(NSRect) rect
							ofView:(NSView *) controlView
				  atCharacterIndex:(unsigned) index;
{
	return [self wantsToTrackMouse];
}

@end
