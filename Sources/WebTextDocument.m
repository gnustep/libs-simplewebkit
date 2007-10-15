//
//  WebTextDocumentRepresentation.m
//  SimpleWebKit
//
//  Created by Nikolaus Schaller on 27.01.07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "WebTextDocument.h"
#import "Private.h"

@implementation _WebTextDocumentRepresentation

// methods from WebDocumentRepresentation protocol

- (void) receivedData:(NSData *) data withDataSource:(WebDataSource *) source;
{
	[[[[source webFrame] DOMDocument] _visualRepresentation] setNeedsLayout:YES];
}

@end

@implementation _WebTextDocumentView

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
		[self layout];
	[super drawRect:rect];
}

// @protocol WebDocumentView

- (void) dataSourceUpdated:(WebDataSource *) source;
{ // try to show new content
	NSDictionary *options=nil;
	NSDictionary *attribs=nil;
	NSError *error;
	NSTextStorage *ts=[[NSTextStorage alloc] initWithData:[source data] options:options documentAttributes:&attribs error:&error];
	if(!ts)
		{ // if data source is completed, show error message
		return;	// ignore
		}
	// save attributes
	[[self layoutManager] replaceTextStorage:ts];
	[ts release];
}

- (void) layout;
{ // do the layout
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