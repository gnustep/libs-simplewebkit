/* simplewebkit
   WebXMLDocumentRepresentation.m

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
#import "WebXMLDocument.h"
#import <WebKit/WebDocument.h>

#if __mySTEP__	// don't include twice since we have it in our own Foundation

#import <Foundation/NSXMLParser.h>

#else		// always use our own NSXMLParser that supports -_parseData: -_setEncoding: and _tagPath and other HTML compatibility extensions

#define NSXMLParser WebKitXMLParser								// rename class to avoid linker conflicts with Foundation
#define parser Webparser										// rename methods to avoid compiler conflicts with Foundation
#define parserDidStartDocument WebparserDidStartDocument		// rename methods to avoid compiler conflicts with Foundation

#define __WebKit__ 1							// this disables some includes in mySTEP NSXMLParser.h/.m

#include "NSXMLParser.h"	// directly include header here - note that the class is renamed!
// class interface and implementation is already compiled in WebHTMLDocumentRepresentation.m
// #include "NSXMLParser.m"	// directly include source here - note that the class is renamed!

@interface NSXMLParser (Private)
- (void) _parseData:(NSData *) data;
@end

#endif

@implementation _WebXMLDocumentRepresentation

// methods from WebDocumentRepresentation protocol

- (void) setDataSource:(WebDataSource *) dataSource;
{
	Class viewclass;
	WebFrame *frame=[dataSource webFrame];
	WebFrameView *frameView=[frame frameView];
	NSView <WebDocumentView> *view;
	viewclass=[WebView _viewClassForMIMEType:[[dataSource response] MIMEType]];	// well, we should know that...
	view=[[viewclass alloc] initWithFrame:[frameView frame]];
	[view setDataSource:dataSource];
	[frameView _setDocumentView:view];
	[view release];
	_doc=[frame DOMDocument];
	[_doc _setVisualRepresentation:view];	// make the view receive change notifications
	[_doc removeChild:[_doc firstChild]];	// if there is one from the last load
	_root=[[[RENAME(DOMDocument) alloc] _initWithName:@"#document" namespaceURI:nil document:_doc] autorelease];	// a new root
	[_doc appendChild:_root];
	_current=(DOMElement *) _root;		// append all to this root
	_parser=[[NSXMLParser alloc] init];	// initialize for incremental parsing
	[_parser setDelegate:self];
#if 0
	NSLog(@"parser: %@", _parser);
#endif
	[super setDataSource:dataSource];
}

- (void) finishedLoadingWithDataSource:(WebDataSource *) source;
{
#if 1
	NSLog(@"WebXMLDocumentRepresentation finishedLoadingWithDataSource:%@", source);
#endif
	[_parser _parseData:nil];	// finish parsing
}

- (void) receivedError:(NSError *) error withDataSource:(WebDataSource *) source;
{
#if 1
	NSLog(@"WebXMLDocumentRepresentation receivedError: %@", error);
#endif
}

- (void) receivedData:(NSData *) data withDataSource:(WebDataSource *) source;
{ // we are repeatedly called for each data fragment!
	NSString *title;
	NSAutoreleasePool *arp;
#if 0
	NSLog(@"WebXMLDocumentRepresentation receivedData %@", data);
	//	NSLog(@"document source: %@", [self documentSource]);
#endif
	arp=[NSAutoreleasePool new];
	[_parser _parseData:data];	// parse next fragment
	[arp release];	// immediately clean up all temporaries
	if((title=[self title]))
		{
		WebFrame *webFrame=[source webFrame];
		WebView *webView=[webFrame webView];
#if 1
		NSLog(@"notify delegate for title %@: %@", title, [webView frameLoadDelegate]);
#endif
		[[webView frameLoadDelegate] webView:webView didReceiveTitle:title forFrame:webFrame];	// update title
		}
	[(NSView <WebDocumentView> *)[[[source webFrame] frameView] documentView] dataSourceUpdated:source];	// notify frame view
}

- (NSString *) title; { return [[[_dataSource response] URL] absoluteString]; }

- (BOOL) canProvideDocumentSource; { return YES; }

- (NSString *) documentSource;
{ // XML should be in UTF8...
	return [[[NSString alloc] initWithData:[_dataSource data] encoding:NSUTF8StringEncoding] autorelease];
}

// XML Parser delegate methods for parsing HTML

- (void) parser:(NSXMLParser *) parser parseErrorOccurred:(NSError *) parseError;
{
	NSLog(@"%@ parseErrorOccurred: %@", NSStringFromClass(isa), parseError);
}

- (void) parser:(NSXMLParser *) parser foundCharacters:(NSString *) string;
{
	if([string length] > 0)
		{
		DOMText *r=[[DOMText alloc] _initWithName:@"#text" namespaceURI:nil document:_doc];
#if 0
		NSLog(@"%@ foundCharacters: %@", NSStringFromClass(isa), string);
#endif
		[r setData:string];
		[_current appendChild:r];
		[r release];
		}
}

- (void) parser:(NSXMLParser *) parser foundComment:(NSString *) comment;
{
	if([comment length] > 0)
		{
		DOMComment *r=[[DOMComment alloc] _initWithName:@"#comment" namespaceURI:nil document:_doc];
#if 0
		NSLog(@"%@ foundComment: %@", NSStringFromClass(isa), comment);
#endif
		[r setData:comment];
		[_current appendChild:r];
		[r release];
		}
}

- (void) parser:(NSXMLParser *) parser foundCData:(NSData *) cdata;
{
	DOMCDATASection *r=[[DOMCDATASection alloc] _initWithName:@"#CDATA" namespaceURI:nil document:_doc];
	NSString *string=[[NSString alloc] initWithData:cdata encoding:NSUTF8StringEncoding];	// which encoding???
#if 0
	NSLog(@"%@ foundCDATA: %@", NSStringFromClass(isa), string);
#endif
	[r setData:string];
	[_current appendChild:r];
	[r release];
	[string release];
}

- (void) parser:(NSXMLParser *) parser foundIgnorableWhitespace:(NSString *) whitespaceString;
{
#if 0	// ignore ignorable text
	if([whitespaceString length] > 0)
		{
		DOMText *r=[[DOMText alloc] _initWithName:@"#text" namespaceURI:nil document:_doc];
#if 0
		NSLog(@"%@ foundIgnorableWhitespace: %@", NSStringFromClass(isa), whitespaceString);
#endif
		[r setData:whitespaceString];
		[_current appendChild:r];
		[r release];
		}
#endif
}

- (void) parser:(NSXMLParser *) parser didStartElement:(NSString *) tag namespaceURI:(NSString *) uri qualifiedName:(NSString *) name attributes:(NSDictionary *) attributes;
{ // handle opening tags
	NSEnumerator *e;
	NSString *key;
	DOMElement *newElement;
	newElement=[[[DOMElement alloc] _initWithName:tag namespaceURI:uri document:_doc] autorelease];
	if(!newElement)
		{
		NSLog(@"XMLDocument could not alloc element for tag <%@>", tag);
		return;	// ignore if we can't allocate
		}
	[_current appendChild:newElement];	// make child
	e=[attributes keyEnumerator];
	while((key=[e nextObject]))
		{ // attach (merge) attributes
		NSString *val=[attributes objectForKey:key];
		if([val class] == [NSNull class])
			val=nil;
		if(![newElement hasAttribute:key])
			[newElement setAttribute:key :val];	// like Safari: merges only not-yet-existing attributes from a repeated tag (e.g. <body attr1></body><body attr2></body>) 
		}
	_current=newElement;	// go down
}

- (void) parser:(NSXMLParser *) parser didEndElement:(NSString *) tag namespaceURI:(NSString *) uri qualifiedName:(NSString *) name;
{ // handle closing tags
	_current=(DOMElement *) [_current parentNode];
}

- (void) parserDidEndDocument:(NSXMLParser *) parser
{ // done
#if 1
	NSLog(@"WebXMLDocumentRepresentation parserDidEndDocument:%@", parser);
#endif
	[_parser release];
	_parser=nil;
	[[_dataSource webFrame] _finishedLoading];	// notify
	
	/*
	 check if we have a tree that looks like:
	 
	 <?xml version="1.0"?>
	 <rss version="2.0">
	 
	 if yes:
	 
	 NSURL *url=[[source initialRequest] URL];
	 NSURL *feed=[[[NSURL alloc] initWithScheme:@"feed" host:[url host] path:[url path]] autorelease];
	 [[_dataSource webFrame] _performClientRedirectToURL:feed delay:0.0];
	 */
}

@end

@interface DOMNode (_WebXMLDocumentView)
- (void) _layoutXML:(NSMutableAttributedString *) str;
@end

@implementation DOMNode (_WebXMLDocumentView)

- (void) _layoutXML:(NSMutableAttributedString *) str;
{ // recurse through tree
	DOMNodeList *list=[self childNodes];
	unsigned int i, cnt=[list length];
	for(i=0; i<cnt; i++)
		[[list item:i] _layoutXML:str];
}

@end

@implementation DOMText (_WebXMLDocumentView)

- (void) _layoutXML:(NSMutableAttributedString *) str;
{
	NSMutableString *s=[[[self data] mutableCopy] autorelease];
	[s replaceOccurrencesOfString:@"\r" withString:@"" options:0 range:NSMakeRange(0, [s length])];	// remove
	[s replaceOccurrencesOfString:@"\n" withString:@" " options:0 range:NSMakeRange(0, [s length])];	// convert to space
	[s replaceOccurrencesOfString:@"\t" withString:@" " options:0 range:NSMakeRange(0, [s length])];	// convert to space
	while([s replaceOccurrencesOfString:@"  " withString:@" " options:0 range:NSMakeRange(0, [s length])])	// convert double spaces into single ones
		;	// trim multiple spaces as long as we find them
	if([str length] > 0 && [[str string] characterAtIndex:[str length]-1] != ' ' && ![s hasPrefix:@" "])	// last was not a space
		[s insertString:@" " atIndex:0];
	[str appendAttributedString:[[[NSAttributedString alloc] initWithString:s attributes:nil] autorelease]];	
}

@end

@implementation _WebXMLDocumentView

- (id) initWithFrame:(NSRect) rect
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
		}
	return self;
}

- (void) dataSourceUpdated:(WebDataSource *) source;
{
}

- (void) layout;
{ // go through tree and collect all text values into a single string
	DOMNode *root=[[[_dataSource webFrame] DOMDocument] firstChild];
	NSTextStorage *ts=[self textStorage];
#if 0
	NSLog(@"layout %@", root);
#endif
	[ts replaceCharactersInRange:NSMakeRange(0, [ts length]) withString:@""];	// clear
	[root _layoutXML:ts];
}

- (void) setDataSource:(WebDataSource *) source;
{
	_dataSource=source;
}

- (void) setNeedsLayout:(BOOL) flag;
{ // getImage from our rep.
	_needsLayout=flag;
}

- (void) viewDidMoveToHostWindow;
{
	// FIXME:
}

- (void) viewWillMoveToHostWindow:(NSWindow *) win;
{
	// FIXME:
}

- (void) drawRect:(NSRect) rect
{
	if(_needsLayout)
		[self layout];
	[super drawRect:rect];
}

@end
