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

// FIXME: this might need more elaboration to add the national prefix for short numbers

- (void) _processPhoneNumbers:(NSMutableAttributedString *) str;
{
	NSString *raw=[str string];
	NSScanner *sc=[NSScanner scannerWithString:raw];
	[sc setCharactersToBeSkipped:nil];	// don't skip spaces or newlines automatically
	while(![sc isAtEnd])
		{
		unsigned start=[sc scanLocation];	// remember where we did start
		NSRange rng;
		NSDictionary *attr=[str attributesAtIndex:start effectiveRange:&rng];
		if(![attr objectForKey:NSLinkAttributeName])
			{ // we don't yet have a link here
			NSString *number=nil;
			static NSCharacterSet *digits;
			static NSCharacterSet *ignorable;
			if(!digits) digits=[[NSCharacterSet characterSetWithCharactersInString:@"0123456789#*"] retain];
			// FIXME: what about dots? Some countries write a phone number as 12.34.56.78
			if(!ignorable) ignorable=[[NSCharacterSet characterSetWithCharactersInString:@" -()\t"] retain];	// NOTE: does not include \n !
			[sc scanString:@"+" intoString:&number];	// looks like a good start (if followed by any digits)
			while(![sc isAtEnd])
				{
				NSString *segment;
				if([sc scanCharactersFromSet:ignorable intoString:NULL])
					continue;	// skip
				if([sc scanCharactersFromSet:digits intoString:&segment])
					{ // found some (more) digits
					if(number)
						number=[number stringByAppendingString:segment];	// collect
					else
						number=segment;		// first segment
					continue;	// skip
					}
				break;	// no digits
				}
			if([number length] > 6)
				{ // there have been enough digits in sequence so that it looks like a phone number
				NSRange srng=NSMakeRange(start, [sc scanLocation]-start);	// string range
				if(srng.length <= rng.length)
					{ // we have uniform attributes (i.e. rng covers srng) else -> ignore
					NSLog(@"found potential telephone number: %@", number);
					// preprocess number so that it fits into E.164 and DIN 5008 formats
					// how do we handle if someone writes +49 (0) 89 - we must remove the 0?
					if([number hasPrefix:@"00"])
						number=[NSString stringWithFormat:@"+%@", [number substringFromIndex:2]];
					else if([number hasPrefix:@"0"])
						number=[number substringFromIndex:1];
					if(![number hasPrefix:@"+"])
						number=[NSString stringWithFormat:@"+%@%@", @"49", number];
					NSLog(@"  -> %@", number);
					[str setAttributes:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"tel:%@", number]
																   forKey:NSLinkAttributeName] range:srng];	// add link
					continue;
					}
				}
			}
		[sc setScanLocation:start+1];	// skip anything else
		}
}

- (void) layout;
{ // do the layout of subviews
	DOMHTMLHtmlElement *html=(DOMHTMLHtmlElement *) [[[[_dataSource webFrame] DOMDocument] firstChild] firstChild];
	DOMHTMLElement *body=(DOMHTMLElement *) [html lastChild];	// either <body> or could be a <frameset>
	NSString *anchor=[[[_dataSource response] URL] fragment];
	NSString *bg=[body getAttribute:@"background"];
	NSColor *background;
#if 1
	NSLog(@"%@ %@", NSStringFromClass(isa), NSStringFromSelector(_cmd));
#endif
	_needsLayout=NO;
	[body _layout:self];	// process the <body> tag (could also be a <frameset>)
	[self _processPhoneNumbers:[self textStorage]];	// update content
	background=[bg _htmlColor];
	if(!background)
		background=[[body getAttribute:@"bgcolor"] _htmlColor];
//	if(!background)
//		background=[NSColor whiteColor];	// default
	if(background)
		[self setBackgroundColor:background];
	[self setDrawsBackground:background != nil];
	if([anchor length] != 0)
		{ // locate a matching anchor
		NSAttributedString *str=[self textStorage];
		unsigned idx, cnt=[str length];
		for(idx=0; idx < cnt; idx++)
			{
			NSString *attr=[str attribute:@"DOMHTMLAnchorElementAnchorName" atIndex:idx effectiveRange:NULL];
			if(attr && [attr isEqualTo:anchor])
				break;
			}
		if(idx < cnt)
			{
			NSString *target=[str attribute:@"DOMHTMLAnchorElementTargetWindow" atIndex:idx effectiveRange:NULL];
			// decide to open different window? - or do we do that only when clicking a ling?
			[self scrollRangeToVisible:NSMakeRange(idx, 0)];	// jump to anchor
			}
		}
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
{ // make a text attachment that eats up the remaining space up to the end of the current fragment
	fragment.size.width-=pos.x-1.0;
	fragment.size.height=5.0;
	fragment.origin=NSZeroPoint;	// it appears that we must return relative coordinates
	return fragment;
}

- (void) drawWithFrame:(NSRect)cellFrame
				inView:(NSView *)controlView
{ // draw a horizontal line
	NSBezierPath *p=[NSBezierPath bezierPath];
#if 0
	[[NSColor redColor] set];
	NSRectFill(cellFrame);
#endif
	[p setLineWidth:1.0];
	[p moveToPoint:NSMakePoint(NSMinX(cellFrame), NSMidY(cellFrame))];
	[p lineToPoint:NSMakePoint(NSMaxX(cellFrame), NSMidY(cellFrame))];
	[[NSColor blackColor] set];
	[p stroke];
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
