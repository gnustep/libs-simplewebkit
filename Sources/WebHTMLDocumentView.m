//
//  WebHTMLDocumentRepresentation.m
//  mySTEP
//
//  Created by Dr. H. Nikolaus Schaller on Mon Jan 05 2006.
//  Revised May 2006
//  Copyright (c) 2004 DSITRI. All rights reserved.
//
//  parse HTML document into DOMHTML node structure (using NSXMLParser as the scanner)

#import "Private.h"
#import "WebHTMLDocumentView.h"

@interface NSView (_WebHTMLDocumentView)
- (void) _updateWithDOMHTMLElement:(DOMHTMLElement *) tree;
@end

@implementation NSView (_WebHTMLDocumentView)

- (BOOL) textView:(NSTextView *) tv clickedOnLink:(id) link atIndex:(unsigned) charIndex;
{
	// FIXME: we must make someone else the delegate who knows the baseURL...
	// e.g. the _WebHTMLDocumentView
	//	if(link)
	//		link=[[NSURL URLWithString:link relativeToURL:nil] absoluteString];	// normalize
	NSLog(@"jump to link %@", link);
	return YES;	// handled
}

- (void) _updateWithDOMHTMLElement:(DOMHTMLElement *) tree
{ // adjust subviews so that they display the DOM tree content
	DOMNodeList *children=[tree childNodes];
	NSLog(@"_updateWithDOMHTMLElement: %@", tree);
	NSLog(@"attribs: %@", [tree _attributes]);
	if([tree class] == [DOMHTMLFrameSetElement class])
		{ // handle frameset
		
		}
	else if([tree class] == [DOMHTMLFrameElement class])
		{ // handle frame
		
		}
	else if([tree class] == [DOMHTMLBodyElement class])
		{ // handle view background
		NSTextView *t=[[self subviews] lastObject];
		if(![t isKindOfClass:[NSTextView class]])
			{
			[t removeFromSuperviewWithoutNeedingDisplay];
			t=[[NSTextView alloc] initWithFrame:[self frame]];
			[t setDelegate:self];
//			[t setAutoresizingMask:NSViewWidthSizable|NSViewMaxXMargin|NSViewHeightSizable|NSViewMaxYMargin];
			[t setAutoresizingMask:NSViewWidthSizable|NSViewMaxXMargin|NSViewMinYMargin];
			// set other attributes (selectable, editable etc.)
			[self addSubview:t];
			[t release];
			}
		[[t textStorage] setAttributedString:[tree attributedString]];
		}
	// adjust subview classes/types first - then recursively go down one level
	[self setNeedsDisplay:YES];
}

@end

@implementation _WebHTMLDocumentView

// NSView overrides

// init -> attach defalt context menu

#if OLD
- (void) drawRect:(NSRect) rect;
{
	NSLog(@"%@ drawRect:%@", self, NSStringFromRect(rect));
	if(_needsLayout)
		[self layout];
	[super drawRect:rect];
}
#endif

// @protocol WebDocumentView

- (void) dataSourceUpdated:(WebDataSource *) source;
{
	DOMHTMLHtmlElement *html=(DOMHTMLHtmlElement *) [[[[source webFrame] DOMDocument] firstChild] firstChild];
	if(html)
		[self _updateWithDOMHTMLElement:(DOMHTMLElement *) [html lastChild]];
}

- (void) layout;
{
	NSLog(@"%@ %@", NSStringFromClass(isa), NSStringFromSelector(_cmd));
	_needsLayout=NO;
}

- (void) setDataSource:(WebDataSource *) source;
{
	_dataSource=source;
}

- (void) setNeedsLayout:(BOOL) flag;
{
	_needsLayout=flag;
}

- (void) viewDidMoveToHostWindow;
{
}

- (void) viewWillMoveToHostWindow:(NSWindow *) win;
{
}

// @protocol WebDocumentText

- (NSAttributedString *) attributedString; { return [(DOMHTMLElement *) [[[[[_dataSource webFrame] DOMDocument] firstChild] firstChild] lastChild] attributedString]; }
- (void) deselectAll; { NIMP; }
- (void) selectAll; { NIMP; }
- (NSAttributedString *) selectedAttributedString;  { return NIMP; }
- (NSString *) selectedString;  { return [[self selectedAttributedString] string]; }
- (NSString *) string;  { return [[self attributedString] string]; }
- (BOOL) supportsTextEncoding; { return NO; }	// CHECKME: or YES???

@end

