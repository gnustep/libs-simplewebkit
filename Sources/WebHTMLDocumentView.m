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
		[self setHorizontallyResizable:NO];	// for proper line breaks
		[self setTextContainerInset:NSMakeSize(2.0, 4.0)];	// leave some margin
		[[self textContainer] setWidthTracksTextView:YES];
		[[self textContainer] setHeightTracksTextView:NO];
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
#if 0
	NSLog(@"dataSourceUpdated: %@", source);
#endif
#if 0	// show view hierarchy
	while(self)
		NSLog(@"%p: %@", self, self), self=(_WebHTMLDocumentView *) [self superview];
#endif	
}

- (void) layout;
{ // do the layout of subviews - NOTE: this is called from within drawRect!
	DOMHTMLHtmlElement *html=(DOMHTMLHtmlElement *) [[[_dataSource webFrame] DOMDocument] firstChild];
	DOMHTMLElement *body=(DOMHTMLElement *) [html lastChild];	// either <body> or could be a <frameset>
#if 0
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
#if 0
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
#if 0
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

// NSSplitView overrides

- (id) initWithFrame:(NSRect) rect;
{
	if((self=[super initWithFrame:rect]))
		{
		[self setAutoresizingMask:(NSViewWidthSizable|NSViewHeightSizable)];
		[self setIsPaneSplitter:NO];
		}
	return self;
}

- (float) dividerThickness
{
	return 6.0;
}

- (void) drawDividerInRect:(NSRect) aRect
{
	// draw splitter background
	// if this splitter is moveable:
	[super drawDividerInRect:aRect];
}

- (void) drawRect:(NSRect) rect;
{
#if 0
	NSLog(@"%@ drawRect:%@", self, NSStringFromRect(rect));
#endif
	if(_needsLayout)
		[self layout];
	[[NSColor lightGrayColor] set];
	NSRectFill(rect);	// draw a splitter background
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
#if 0
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
#if 0
	NSLog(@"attachment cell=%@", [attachment attachmentCell]);
#endif
	return attachment;
}

@end

// abstract extensions for NSCell so that we can use *any* subclass as an attachment cell - unless overridden explicity in a subclass

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
	BOOL done=NO;
//	NSLog(@"mouse in view %@", NSStringFromPoint([controlTextView convertPoint:[event locationInWindow] fromView:nil]));
//	NSLog(@"trackMouse: %@ inRect: %@ ofView: %@ atCharacterIndex: %u untilOp: %d", event, NSStringFromRect(cellFrame), controlTextView, index, flag);
	while([event type] != NSLeftMouseUp)	// loop outside until mouse goes up 
		{
			NSPoint p = [controlTextView convertPoint:[event locationInWindow] fromView:nil];
			if(NSMouseInRect(p, cellFrame, [controlTextView isFlipped]))
				{ // highlight cell
					[self setHighlighted:YES];	
					[controlTextView setNeedsDisplay:YES];
					done=[self trackMouse:event
									inRect:cellFrame
									ofView:controlTextView
							 untilMouseUp:NO];
					[self setHighlighted:NO];	
					[controlTextView setNeedsDisplay:YES];
					if(done)
						break;
				}
			if(!flag)
				break;	// don't wait until mouse is up, i.e. exit if we leave the rect
			event = [NSApp nextEventMatchingMask:NSLeftMouseDownMask | NSLeftMouseUpMask | NSMouseMovedMask | NSLeftMouseDraggedMask
									   untilDate:[NSDate distantFuture]						// get next event
										  inMode:NSEventTrackingRunLoopMode 
										 dequeue:YES];			
  		}
	return done;
}

- (BOOL) wantsToTrackMouse;
{
	return YES;
}

- (BOOL) wantsToTrackMouseForEvent:(NSEvent *) event
							inRect:(NSRect) rect
							ofView:(NSView *) controlView
				  atCharacterIndex:(unsigned) index;
{ // this could make tracking only on parts of the cell or depend on the attributes of the character
	return [self wantsToTrackMouse];
}

@end

@implementation NSActionCell (NSTextAttachment)

- (NSPoint) cellBaselineOffset; { return NSMakePoint(0.0, -30.0); }

@end

@implementation NSButtonCell (NSTextAttachment)

- (NSPoint) cellBaselineOffset; { return NSMakePoint(0.0, -20.0); }

// add missing methods

@end

@implementation NSTextFieldCell (NSTextAttachment)

- (NSSize) cellSize; { return NSMakeSize(200.0, 22.0); }		// should depend on font&SIZE parameter

- (NSPoint) cellBaselineOffset; { return NSMakePoint(0.0, -10.0); }

- (BOOL) trackMouse:(NSEvent *)event 
						 inRect:(NSRect)cellFrame 
						 ofView:(NSView *)controlTextView 
   atCharacterIndex:(unsigned) index
			 untilMouseUp:(BOOL)flag;
{ // click into text field
	if(![self isEditable])
		return NO;
	if([[controlTextView window] makeFirstResponder:controlTextView])
			{
				[self editWithFrame:cellFrame
										 inView:controlTextView
										 editor:[self setUpFieldEditorAttributes:[[controlTextView window] fieldEditor:YES forObject:controlTextView]]
									 delegate:[self target]
											event:event];
				return YES;	// field editor should now be in editing mode
			}
	return NO;
}

// add missing methods

@end

@interface NSInputTextFieldCell : NSTextFieldCell
{
	int lines;
	int cols;
}

@end

@implementation NSInputTextFieldCell

- (void) textDidEndEditing:(NSNotification *)aNotification
{
	NSNumber *code = [[aNotification userInfo] objectForKey:@"NSTextMovement"];
	[self setStringValue:[[aNotification object] string]];	// copy value to cell
	[self endEditing:[aNotification object]];	
	switch([code intValue])
		{
			case NSReturnTextMovement:
				[NSApp sendAction:[self action] to:[self target] from:self];
				break;
			case NSTabTextMovement:
				break;
			case NSBacktabTextMovement:
				break;
			case NSIllegalTextMovement:
				break;
		}
}

@end

@implementation NSPopUpButtonCell (NSTextAttachment)

- (NSSize) cellSize; { return NSMakeSize(200.0, 22.0); }		// should depend on font&SIZE parameter

- (NSPoint) cellBaselineOffset; { return NSMakePoint(0.0, -10.0); }

	// add missing methods

@end

@implementation NSViewAttachmentCell

// show a generic view as an attachment cell (e.g. an WebFrameView for <iframe>)
// or an embedded NSTextView

// is the view a subview of our control view???

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

- (BOOL) trackMouse:(NSEvent *)event 
						 inRect:(NSRect)cellFrame 
						 ofView:(NSView *)controlTextView 
   atCharacterIndex:(unsigned) index
			 untilMouseUp:(BOOL)flag;
{ // click into text field
	if(![[controlTextView window] makeFirstResponder:view])
		return NO;
	[view mouseDown:event];	// tracking loop of embedded view
	return YES;
}

@end

@implementation NSHRAttachmentCell

- (id)init
{
    if((self=[super initTextCell:@"<hr>"]))
		{
		_shaded = NO;
		_size = 2;
		_width = 100;
		_widthIsPercent = YES;
		}
    return self;
}

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
    _shaded = shaded;
}

- (void) setSize:(int)size
{
    _size = size;
}

- (void) setWidth:(int)width
{
    _width = width;
}

- (void) setIfWidthIsPercent:(BOOL)flag
{
    _widthIsPercent = flag;
}
    
- (void) drawWithFrame:(NSRect)cellFrame
				inView:(NSView *)controlView
{ // draw a horizontal line
	NSPoint upLeft;
	NSPoint lowRight;
	NSRect bar;
	NSBezierPath *p;
	NSBezierPath *shadow;
	float lineWidth;
		
	lineWidth = _size;
	
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
		[shadow lineToPoint:NSMakePoint(lowRight.x, lowRight.y+1)];
		[shadow lineToPoint:NSMakePoint(lowRight.x, upLeft.y)];
		[[NSColor lightGrayColor] set];
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

- (BOOL) wantsToTrackMouse; { return NO; }

@end

@implementation WebView (NSAttributedString)

// FIXME: inherit bei Attributen verarbeiten und Wert aus parentAttribs Ÿbernehmen

- (void) _spliceNode:(DOMNode *) node to:(NSMutableAttributedString *) str pseudoElement:(NSString *) pseudoElement parentStyle:(DOMCSSStyleDeclaration *) parent parentAttributes:(NSDictionary *) parentAttributes;
{ // recursively splice this node and any subnodes, taking end of last fragment into account
	id val;
	unsigned i, cnt;
	WebPreferences *preferences=[self preferences];
	NSMutableDictionary *attributes;
	DOMCSSStyleDeclaration *style;
	DOMNodeList *childNodes;
	NSString *display;
	NSString *visibility;
	BOOL lastIsInline;
	BOOL isInline;
	NSTextAttachment *attachment;
	NSString *string;
	if(![node isKindOfClass:[DOMElement class]])
		{ // inherit all style for DOMText nodes
			style=parent;					// inherit style
			attributes=parentAttributes;	// inherit attributes
			childNodes=nil;					// no children
		}
	else
		{ // calculate/apply new style
			style=[self _styleForElement:node pseudoElement:pseudoElement];
			attributes=[NSMutableDictionary dictionaryWithCapacity:10];	// we will create new ones
			childNodes=[node childNodes];
			cnt=[style length];
			for(i=0; i<cnt; i++)
				{ // evaluate inheritance (attr() has already been processed)
					NSString *property=[style item:i];
					DOMCSSValue *val=[style getPropertyCSSValue:property];
					if(parent && [val cssValueType] == DOM_CSS_INHERIT)
						[style setProperty:property CSSvalue:[parent getPropertyCSSValue:property] priority:[parent getPropertyPriority:property]];	// inherit
				}
		}
	display=[[style getPropertyCSSValue:@"display"] _toString];
	visibility=[[style getPropertyCSSValue:@"visibility"] _toString];	
	lastIsInline=([str length] != 0 && ![[str string] hasSuffix:@"\n"]);	// did not end with block
	isInline=style == parent || !display || [display isEqualToString:@"inline"];	// plain text counts as inline
	
	// hm. _range is only known for DOMHTMLElements!
	//	_range.location=[str length];
	//	_range.length=0;
	
	if([visibility isEqualToString:@"collapse"])
		return;
	
	// FIXME: handle all display: styles here!
	
	if([display isEqualToString:@"none"])
		return;
	// FIXME: move this at the end of the style calculation
	if([display isEqualToString:@"inline-block"])
		{ // create an inline-block
			NSMutableAttributedString *value=[[[NSMutableAttributedString alloc] init] autorelease];
			NSCell *cell;
			childNodes=[node childNodes];
			for(i=0; i<[childNodes length]; i++)
				{ // add child nodes
					// NSLog(@"splice child %@", [_childNodes item:i]);
					[self _spliceNode:[childNodes item:i] to:str pseudoElement:pseudoElement parentStyle:style parentAttributes:attributes];
				}
			attachment=[NSTextAttachmentCell textAttachmentWithCellOfClass:[NSCell class]];
			cell=(NSCell *) [attachment attachmentCell];	// get the real cell
			[cell setAttributedStringValue:value];	// formatted by contents between <buton> and </button>
			// set other attributes like background etc.
#if 0
			NSLog(@"  cell: %@", cell);
#endif
		}
	else
		attachment=[node _attachment];	// may be nil
	string=[node _string];	// may be nil
	
	// FIXME: handle inherit and default values!
	// handle (ignore) incompatible/unknown values, i.e. specifying a list as the font size
	
	if(childNodes && ([childNodes length] > 0 || [string length] > 0 || attachment))
		{ // calculate (new) attributes to apply and pass down to children
			NSMutableParagraphStyle *p=[[attributes objectForKey:NSParagraphStyleAttributeName] mutableCopy];	// start with inherited paragraph style
			NSFont *f=[parentAttributes objectForKey:NSFontAttributeName];	// start with inherited font
			NSFont *ff;	// temporary converted font
			if(!p) p=[[[NSMutableParagraphStyle alloc] init] autorelease];	// some default paragraph style
			if(!f) f=[NSFont systemFontOfSize:0.0];	// default system font (should be overridden by <body> in default CSS)
			val=[style getPropertyCSSValue:@"font-family"];
			if(val)
				{ // scan through all fonts defined by font-family until we find one that exists and provides the font-style
					NSEnumerator *e=[[val _toStringArray] objectEnumerator];	// get as string array
					NSString *fname;
					while((fname=[e nextObject]))
						{ // modify font family
							if([fname isEqualToString:@"sans-serif"])
								fname=[preferences sansSerifFontFamily];
							else if([fname isEqualToString:@"serif"])
								fname=[preferences serifFontFamily];
							else if([fname isEqualToString:@"monospace"])
								fname=[preferences fixedFontFamily];
							else if([fname isEqualToString:@"cursive"])
								fname=[preferences cursiveFontFamily];
							else if([fname isEqualToString:@"fantasy"])
								fname=[preferences fantasyFontFamily];
							else if([fname isEqualToString:@"default"])
								fname=[preferences standardFontFamily];
							if(fname)
								{
								ff=[[NSFontManager sharedFontManager] fontWithFamily:fname traits:0 weight:5 size:12.0];
								if(ff)
									{ // first matching font found!
									f=ff;
									break;									
									}
								}
						}
				}
			val=[style getPropertyCSSValue:@"font-size"];
			if(val)
				{
				float sz;
				sz=[[parentAttributes objectForKey:NSFontAttributeName] pointSize]/[self textSizeMultiplier];	// inherited size
				if([val primitiveType] == DOM_CSS_IDENT || [val primitiveType] == DOM_CSS_STRING)
					{
					val=[val _toString];
					if([val isEqualToString:@"smaller"])
						sz/=1.2;
					else if([val isEqualToString:@"larger"])
						sz*=1.2;
					else if([val isEqualToString:@"medium"])
						sz=12.0;
					else if([val isEqualToString:@"large"])
						sz=14.0;
					else if([val isEqualToString:@"x-large"])
						sz=18.0;
					else if([val isEqualToString:@"xx-large"])
						sz=24.0;
					else if([val isEqualToString:@"small"])
						sz=10.0;
					else if([val isEqualToString:@"x-small"])
						sz=8.0;
					else if([val isEqualToString:@"xx-small"])
						sz=6.0;					
					if(sz < [preferences minimumLogicalFontSize])
						sz=[preferences minimumLogicalFontSize];
					}
				else
					{
					sz=[val getFloatValue:DOM_CSS_PT relativeTo100Percent:sz andFont:[parentAttributes objectForKey:NSFontAttributeName]];
					// for relative specs:	if(sz < [preferences minimumLogicalFontSize])
					//							sz=[preferences minimumLogicalFontSize];
					}
				if(sz < [preferences minimumFontSize])
					sz=[preferences minimumFontSize];
				ff=[[NSFontManager sharedFontManager] convertFont:f toSize:sz*[self textSizeMultiplier]];	// try to convert
				if(ff) f=ff;
				}
			// FiXME: handle defaultFixedFontSize 
			// else apply [preferences defaultFontSize];
			val=[style getPropertyCSSValue:@"font-style"];
			if(val)
				{
				val=[val _toString];
				if([val isEqualToString:@"normal"])
					ff=[[NSFontManager sharedFontManager] convertFont:f toNotHaveTrait:NSItalicFontMask];
				else if([val isEqualToString:@"italic"])
					ff=[[NSFontManager sharedFontManager] convertFont:f toHaveTrait:NSItalicFontMask];
				else if([val isEqualToString:@"oblique"])
					;
				if(ff) f=ff;
				}
			val=[style getPropertyCSSValue:@"font-weight"];
			if(val)
				{
				val=[val _toString];
				if([val isEqualToString:@"normal"])
					ff=[[NSFontManager sharedFontManager] convertFont:f toNotHaveTrait:NSBoldFontMask];
				else if([val isEqualToString:@"bold"])
					ff=[[NSFontManager sharedFontManager] convertFont:f toHaveTrait:NSBoldFontMask];
				else if([val isEqualToString:@"bolder"])
					ff=[[NSFontManager sharedFontManager] convertWeight:YES ofFont:f];
				else if([val isEqualToString:@"lighter"])
					ff=[[NSFontManager sharedFontManager] convertWeight:NO ofFont:f];
				// handle numeric values (how? we may have to loop over convertWeight until we get close enough...)
				// - (NSFont *)fontWithFamily:[f family] traits:[f traits] weight:15*weight/10 size:[f size]
				if(ff) f=ff;
				}
			val=[style getPropertyCSSValue:@"font-variant"];
			if(val)
				{
				val=[val _toString];
				if([val isEqualToString:@"normal"])
					ff=[[NSFontManager sharedFontManager] convertFont:f toNotHaveTrait:NSSmallCapsFontMask];
				else if([val isEqualToString:@"small-caps"])
					ff=[[NSFontManager sharedFontManager] convertFont:f toHaveTrait:NSSmallCapsFontMask];
				if(ff) f=ff;
				}
			[attributes setObject:f forKey:NSFontAttributeName];
			val=[style getPropertyCSSValue:@"text-decoration"];
			if(val)
				{ // set underline, overline, strikethrough - try to blink
					NSEnumerator *e=[[val _toStringArray] objectEnumerator];
					NSString *deco;
					while((deco=[e nextObject]))
						{
						if([deco isEqualToString:@"underline"])
							{ // make underlined
#if defined(__mySTEP__) || MAC_OS_X_VERSION_10_2 < MAC_OS_X_VERSION_MAX_ALLOWED
							[attributes setObject:[NSNumber numberWithInt:NSUnderlineStyleSingle] forKey:NSUnderlineStyleAttributeName];
#else	// MacOS X < 10.3 and GNUstep
							[attributes setObject:[NSNumber numberWithInt:NSSingleUnderlineStyle] forKey:NSUnderlineStyleAttributeName];
#endif					
							}
						else if([deco isEqualToString:@"overline"])
							;	// FIXME: not available as NSAttributedString attribute
						else if([deco isEqualToString:@"line-through"])
							{ // make strike-through
#if defined(__mySTEP__) || MAC_OS_X_VERSION_10_2 < MAC_OS_X_VERSION_MAX_ALLOWED
							[attributes setObject:[NSNumber numberWithInt:NSUnderlineStyleSingle] forKey:NSStrikethroughStyleAttributeName];
#else	// MacOS X < 10.3 and GNUstep
							// [attributes setObject:[NSNumber numberWithInt:NSSingleUnderlineStyle] forKey:NSStrikethroughStyleAttributeName];
#endif
							}
						}
				}
			val=[style getPropertyCSSValue:@"color"];
			if(val)
				{
				NSColor *color;
				if([val cssValueType] == DOM_CSS_PRIMITIVE_VALUE && [(DOMCSSPrimitiveValue *) val primitiveType] == DOM_CSS_RGBCOLOR)
					{ // special optimization
						unsigned hex=[(DOMCSSPrimitiveValue *) val getFloatValue:DOM_CSS_RGBCOLOR];
						color=[NSColor colorWithCalibratedRed:((hex>>16)&0xff)/255.0 green:((hex>>8)&0xff)/255.0 blue:(hex&0xff)/255.0 alpha:1.0];
					}
				else
					color=[[val _toString] _htmlNamedColor];	// look up by color name
				[attributes setObject:color forKey:NSForegroundColorAttributeName];
				}
			val=[style getPropertyCSSValue:@"cursor"];
			if(val)
				{
				NSCursor *cursor=nil;
				val=[val _toString];
				if([val isEqualToString:@"auto"])
					cursor=[NSCursor arrowCursor];
				else if([val isEqualToString:@"default"])
					cursor=[NSCursor arrowCursor];
				else if([val isEqualToString:@"pointer"])
					cursor=[NSCursor pointingHandCursor];
				else if([val isEqualToString:@"crosshair"])
					cursor=[NSCursor crosshairCursor];
				// FIXME: decode more cursor names
				if(cursor)
					[attributes setObject:cursor forKey:NSCursorAttributeName];
				}
			val=[style getPropertyCSSValue:@"x-link"];
			if(val)
				{
				val=[val _toString];
				[attributes setObject:val forKey:NSLinkAttributeName];	// set the link
				}
			val=[style getPropertyCSSValue:@"x-tooltip"];
			if(val)
				{
				val=[val _toString];
				[attributes setObject:val forKey:NSToolTipAttributeName];	// set the tooltip
				}
			val=[style getPropertyCSSValue:@"x-target-window"];
			if(val)
				{
				val=[val _toString];
				[attributes setObject:val forKey:DOMHTMLAnchorElementTargetWindow];	// set the target window
				}
			val=[style getPropertyCSSValue:@"x-anchor"];
			if(val)
				{
				val=[val _toString];
				[attributes setObject:val forKey:DOMHTMLAnchorElementAnchorName];	// set the anchor
				}
			/* paragraph style */
			val=[style getPropertyCSSValue:@"text-align"];
			if(val)
				{
				val=[val _toString];
				if([val isEqualToString:@"left"])
					[p setAlignment:NSLeftTextAlignment];
				else if([val isEqualToString:@"center"])
					[p setAlignment:NSCenterTextAlignment];
				else if([val isEqualToString:@"right"])
					[p setAlignment:NSRightTextAlignment];
				else if([val isEqualToString:@"justify"])
					[p setAlignment:NSJustifiedTextAlignment];
				// if([align isEqualToString:@"char"])
				//    [p setAlignment:NSNaturalTextAlignment];
				}
			val=[style getPropertyCSSValue:@"vertical-align"];
			if(val)
				{
				val=[val _toString];
				if([val isEqualToString:@"super"])
					[attributes setObject:[NSNumber numberWithInt:1] forKey:NSSuperscriptAttributeName];
				else if([val isEqualToString:@"sub"])
					[attributes setObject:[NSNumber numberWithInt:-1] forKey:NSSuperscriptAttributeName];
				else if([val isEqualToString:@"top"])
					; // modify table cell if possible
				}
			val=[style getPropertyCSSValue:@"direction"];
			if(val)
				{		
					val=[val _toString];
					if([val isEqualToString:@"ltr"])
						[p setBaseWritingDirection:NSWritingDirectionLeftToRight];
					else if([val isEqualToString:@"rtl"])
						[p setBaseWritingDirection:NSWritingDirectionRightToLeft];
					// else NSWritingDirectionNatural?
				}
#if MAC_OS_X_VERSION_10_4 <= MAC_OS_X_VERSION_MAX_ALLOWED
			val=[style getPropertyCSSValue:@"x-header-level"];
			if(val)
				{
				val=[val _toString];
				[p setHeaderLevel:[val intValue]];	// if someone wants to convert the attributed string back to HTML...					
				}
#endif
			[attributes setObject:p forKey:NSParagraphStyleAttributeName];
		}
	/* text modification */
	val=[style getPropertyCSSValue:@"white-space"];
	if(val)
		{ // must this be defined!? What is the defalult?
			BOOL nowrap=NO;
			BOOL nobrk=NO;
			BOOL trim=NO;
			NSMutableString *s;
			val=[val _toString];
			if([val isEqualToString:@"normal"])
				trim=YES, nobrk=YES;
			else if([val isEqualToString:@"nowrap"])
				trim=YES, nobrk=YES, nowrap=YES;
			else if([val isEqualToString:@"pre"])
				nowrap=YES;
			else if([val isEqualToString:@"pre-wrap"])
				nobrk=YES, nowrap=YES;
			else if([val isEqualToString:@"pre-line"])
				trim=YES, nowrap=YES;
			s=[[string mutableCopy] autorelease];

/* we have no access to p here!
			if(nowrap)
				[p setLineBreakMode:NSLineBreakByClipping];
*/
			if(nobrk)
				{ // don't break where html says
					[s replaceOccurrencesOfString:@"\t" withString:@" " options:0 range:NSMakeRange(0, [s length])];	// convert to space
					[s replaceOccurrencesOfString:@"\r" withString:@" " options:0 range:NSMakeRange(0, [s length])];	// convert to space
					[s replaceOccurrencesOfString:@"\n" withString:@" " options:0 range:NSMakeRange(0, [s length])];	// convert to space				
				}
			if(trim)
				{ // trim multiple spaces
#if 1	// QUESTIONABLE_OPTIMIZATION
					while([s replaceOccurrencesOfString:@"        " withString:@" " options:0 range:NSMakeRange(0, [s length])])	// convert long space sequences into single one
						;
#endif
					while([s replaceOccurrencesOfString:@"  " withString:@" " options:0 range:NSMakeRange(0, [s length])])	// convert double spaces into single one
						;	// trim multiple spaces to single ones as long as we find them
					if([s hasPrefix:@" "])
						{ // new fragment starts with a space
							NSString *ss=[str string];	// previous string
							if([ss length] == 0 || [ss hasSuffix:@"\n"] || [ss hasSuffix:@" "])
								s=(NSMutableString *) [s substringFromIndex:1];	// strip off leading spaces if last fragment indicates that						
						}
				}
			string=s;
		}
	val=[style getPropertyCSSValue:@"text-transform"]; 
	if(val)
		{
		val=[val _toString];
		if([val isEqualToString:@"uppercase"])
			string=[string uppercaseString];
		else if([val isEqualToString:@"lowercase"])
			string=[string lowercaseString];
		else if([val isEqualToString:@"capitalize"])
			string=[string capitalizedString];
		}
	val=[style getPropertyCSSValue:@"quotes"];
	if(val)
		{
		val=[val _toString];
		// handle "quotes: "
		}
	if([visibility isEqualToString:@"hidden"])
		{
		// replace by string with spaces of same length
		}
	val=[style getPropertyCSSValue:@"x-before"];
	if(val)
		{ // special case to implement <br>
			string=[[val _toString] stringByAppendingString:string];
		}
	val=[style getPropertyCSSValue:@"x-after"];
	if(val)
		{
			string=[string stringByAppendingString:[val _toString]];
		}
	if(lastIsInline && !isInline)
		{ // we need to close the last inline segment and prefix new block mode segment
			if([[str string] hasSuffix:@" "])
				[str replaceCharactersInRange:NSMakeRange([str length]-1, 1) withString:@"\n"];	// replace if it did end with a space
			else
				[str replaceCharactersInRange:NSMakeRange([str length], 0) withString:@"\n"];	// this operation inherits attributes of the previous section
		}
	if(attachment)
		{ // add attribute attachment (if available)
			NSMutableAttributedString *astr=(NSMutableAttributedString *)[NSMutableAttributedString attributedStringWithAttachment:attachment];
			[astr addAttributes:attributes range:NSMakeRange(0, [astr length])];
			[str appendAttributedString:astr];
		}
	if([string length] > 0)	
		{ // add attributed string
			[str appendAttributedString:[[[NSAttributedString alloc] initWithString:string attributes:attributes] autorelease]];
		}
	for(i=0; i<[childNodes length]; i++)
		{ // add child nodes
			// NSLog(@"splice child %@", [_childNodes item:i]);
			[self _spliceNode:[childNodes item:i] to:str pseudoElement:pseudoElement parentStyle:style parentAttributes:attributes];
		}
	// stringAfter?
	if(!isInline)
		{ // close our block
			if([[str string] hasSuffix:@" "])
				[str replaceCharactersInRange:NSMakeRange([str length]-1, 1) withString:@""];	// strip off any trailing space
			[str appendAttributedString:[[[NSAttributedString alloc] initWithString:@"\n" attributes:attributes] autorelease]];	// close this block
		}
	//	_range.length=[str length]-_range.location;	// store resulting range
	//	[_style release];
	//	_style=nil;
}


@end