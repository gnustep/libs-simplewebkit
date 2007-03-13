/* simplewebkit
   WebHTMLDocumentRepresentation.m

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

//  parse HTML document into DOMHTML node structure (using NSXMLParser as the scanner)

#import "Private.h"
#import "WebHTMLDocumentRepresentation.h"
#import <WebKit/WebDocument.h>

#ifdef __APPLE__ 
#define USE_FOUNDATION_XML_PARSER 0	// no - Apple Foundation's NSXMLParser does not support -_setEncoding and _tagPath
#else
#define USE_FOUNDATION_XML_PARSER 1	// yes - don't include twice
#endif

// temporary for GNUstrep too
// #### FIXME
#define USE_FOUNDATION_XML_PARSER 0

#if USE_FOUNDATION_XML_PARSER

#import <Foundation/NSXMLParser.h>

#else		// always make mySTEP XMLParser available

#define NSXMLParser WebKitXMLParser				// rename to avoid linker conflicts with Foundation
#define __WebKit__ 1							// this disables some includes in mySTEP NSXMLParser.h/.m

#include "NSXMLParser.h"	// directly include header here
#include "NSXMLParser.m"	// directly include sources here

#endif

@interface NSXMLParser (NSPrivate)
- (NSArray *) _tagPath;					// path of all tags
- (void) _setEncoding:(NSStringEncoding) enc;
@end

@implementation _WebHTMLDocumentRepresentation

static NSDictionary *tagtable;

- (id) init;
{
	if((self=[super init]))
		{
		if(!tagtable)
			tagtable=[[NSDictionary dictionaryWithObjectsAndKeys:
					[DOMHTMLHtmlElement class], @"HTML",
					[DOMHTMLHeadElement class], @"HEAD",
					[DOMHTMLTitleElement class], @"TITLE",
					[DOMHTMLMetaElement class], @"META",
					[DOMHTMLLinkElement class], @"LINK",
					[DOMHTMLStyleElement class], @"STYLE",
					[DOMHTMLScriptElement class], @"SCRIPT",
					[DOMHTMLFrameSetElement class], @"FRAMESET",
					[DOMHTMLFrameElement class], @"FRAME",
					[DOMHTMLIFrameElement class], @"IFRAME",
					[DOMHTMLBodyElement class], @"BODY",
					[DOMHTMLDivElement class], @"DIV",
					[DOMHTMLSpanElement class], @"SPAN",
					[DOMHTMLFontElement class], @"FONT",
					[DOMHTMLAnchorElement class], @"A",
					[DOMHTMLImageElement class], @"IMG",
					[DOMHTMLBRElement class], @"BR",
					[DOMHTMLParagraphElement class], @"P",
					[DOMHTMLHRElement class], @"HR",
					[DOMHTMLTableElement class], @"TABLE",
					[DOMHTMLTableRowElement class], @"TR",
					[DOMHTMLTableCellElement class], @"TD",
					[DOMHTMLFormElement class], @"FORM",
					[DOMHTMLInputElement class], @"INPUT",
					[DOMHTMLButtonElement class], @"BUTTON",
					[DOMHTMLLabelElement class], @"LABEL",
					[DOMHTMLTextAreaElement class], @"TEXTAREA",
				
					[DOMHTMLElement class], @"CENTER",
					[DOMHTMLElement class], @"TBODY",
					[DOMHTMLElement class], @"BIG",
					[DOMHTMLElement class], @"SMALL",
					[DOMHTMLElement class], @"B",
					[DOMHTMLElement class], @"I",
					[DOMHTMLElement class], @"H1",
					[DOMHTMLElement class], @"H2",
					[DOMHTMLElement class], @"H3",
					[DOMHTMLElement class], @"H4",
					[DOMHTMLElement class], @"H5",
					[DOMHTMLElement class], @"H6",
					nil
				] retain];
		}
	return self;
}

- (void) dealloc;
{
#if 0
	NSLog(@"dealloc %@: %@", NSStringFromClass(isa), self);
#endif
	[_elementStack release];
	[super dealloc];
}

- (NSString *) description;
{
	return [NSString stringWithFormat:@"%@: %@\n%@", [super description], _dataSource, _doc];
}
// methods from WebDocumentRepresentation protocol

- (void) finishedLoadingWithDataSource:(WebDataSource *) source;
{
	NSLog(@"WebHTMLDocumentRepresentation finishedLoadingWithDataSource");
	[[source webFrame] _finishedLoading];	// notify
}

- (void) receivedError:(NSError *) error withDataSource:(WebDataSource *) source;
{
	NSLog(@"WebHTMLDocumentRepresentation receivedError: %@", error);
}

- (void) receivedData:(NSData *) data withDataSource:(WebDataSource *) source;
{
	DOMHTMLHtmlElement *html;
#if 0
	NSLog(@"WebHTMLDocumentRepresentation receivedData");
	NSLog(@"document source: %@", [self documentSource]);
#endif
	_parser=[[NSXMLParser alloc] initWithData:data];
	// FIXME:  install the HTML entity translation table
	// FIXME: translate encoding from dataSource/response settings
//	[_parser _setEncoding:NSUTF8StringEncoding];
	[_parser setDelegate:self];
	_doc=[[source webFrame] DOMDocument];
	[_doc removeChild:[_doc lastChild]];	// remove current HTML DOM tree to build up a new one
	_root=[[DOMHTMLElement alloc] _initWithName:@"#document" namespaceURI:nil document:_doc];	// a new root
	[_doc appendChild:_root];
	html=[[DOMHTMLHtmlElement alloc] _initWithName:@"HTML" namespaceURI:nil document:_doc];
	[_root appendChild:html];
	_head=[[DOMHTMLHeadElement alloc] _initWithName:@"HEAD" namespaceURI:nil document:_doc];
	[html appendChild:_head];
	_body=[[DOMHTMLBodyElement alloc] _initWithName:@"BODY" namespaceURI:nil document:_doc];
	[html appendChild:_body];
	[[source webFrame] _startedLoading];	// notify first call
	[_elementStack release];
	_elementStack=[[NSMutableArray alloc] initWithCapacity:20];
	[_elementStack addObject:_body];	// append whatever is parsed to body
	[_root release];
#if 0
	NSLog(@"parser: %@", _parser);
#endif
	// FIXME: we should have incremental parsing...
	if(![_parser parse])	// as far as we come :-)
		NSLog(@"parse failed due to %@", [_parser parserError]);	// shouldn't be printed...
	[_parser release];
	[[source webFrame] _receivedData:source];	// notify a new DOM tree
}

- (void) setDataSource:(WebDataSource *) dataSource;
{
	_dataSource=dataSource;
}

- (NSString *) title;
{ // return the value of the first DOMHTMLTitleElement's #text
	DOMNodeList *children=[_head childNodes];
	int i, cnt=[children length];
	for(i=0; i<cnt; i++)
		{
		DOMHTMLTitleElement *n=(DOMHTMLTitleElement *)[children item:i];
		if([n isKindOfClass:[DOMHTMLTitleElement class]])
			{ // is really a title element
			DOMText *t=(DOMText *)[n firstChild];
			if([t isKindOfClass:[DOMText class]])
				{ // is really a text element
#if 1
				NSLog(@"found <title> %@", [t data]);
#endif
				return [t data];	// found!
				}
			}
		}
#if 1
	NSLog(@"no <title> found in %@", _head);
#endif
	return nil;
}

- (BOOL) canProvideDocumentSource; { return YES; }

- (NSString *) documentSource;
{
	[_dataSource textEncodingName];
	// translate encoding name to constant...
	// FIXME: what do we do if encoding is not valid?
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
		[[_elementStack lastObject] appendChild:r];
		[r release];
		}
}

- (void) parser:(NSXMLParser *) parser foundIgnorableWhitespace:(NSString *) whitespaceString;
{
#if 0
	if([string length] > 0)
		{
		DOMText *r=[[DOMText alloc] _initWithName:@"#text" namespaceURI:nil document:_doc];
#if 0
		NSLog(@"%@ foundIgnorableWhitespace: %@", NSStringFromClass(isa), whitespaceString);
#endif
		[r setData:whitespaceString];
		[[_elementStack lastObject] appendChild:r];
		[r release];
		}
#endif
}

- (void) parser:(NSXMLParser *) parser didStartElement:(NSString *) tag namespaceURI:(NSString *) uri qualifiedName:(NSString *) name attributes:(NSDictionary *) attributes;
{ // handle opening tags
	Class c=[tagtable objectForKey:tag];
	id newElement;
	NSEnumerator *e;
	NSString *key;
#if 0
	NSLog(@"%@ %@: <%@> -> %@", NSStringFromClass(isa), [parser _tagPath], tag, NSStringFromClass(c));
#endif
	
	if(!c)
		{
#if 1
		NSLog(@"%@ %@: <%@> ignored", NSStringFromClass(isa), [parser _tagPath], tag);
#endif
		return;	// ignore
		}
	if([c _ignore])
		{
		// in case of <html>, <head>, <body>, copy attributes to existing element and throw away current
		return;	// ignore
		}
	newElement=[[c alloc] _initWithName:tag namespaceURI:uri document:_doc];
	e=[attributes keyEnumerator];
	while((key=[e nextObject]))
		{ // attach attributes
		NSString *val=[attributes objectForKey:key];
		if([val class] == [NSNull class])
			val=nil;
		[newElement setAttribute:key :val];
		}
	if(!newElement)
		{
		NSLog(@"did not alloc?");
		return;	// ignore if we can't allocate
		}
	// if([currentElement _streamline] - add <tag> to the current element
	if(c == [DOMHTMLFrameSetElement class] && !_frameSet)
		{ // first level <frameset>
		[[_body parentNode] appendChild:newElement];	// make sibling
		_frameSet=newElement;
		}
	// FIXME: create a <TBODY> for a <TABLE> on the first <tr> and ignore the <TBODY> tag
	// FIXME: if we are a H tag and the lastObject as well, make us a sibling not a child of the header
	// nesting rules
	// <p> is not nested, <h> is not nested, <table> is only nested within a <td> or <th>
	else if([c _goesToHead])
		[_head appendChild:newElement];	// add to top level of _head
	else
		// FIXME: if we are a H tag and the lastObject as well, make us a sibling not a child of the existing header
		[[_elementStack lastObject] appendChild:newElement];	// add to next level
	if(![c _closeNotRequired])
		[_elementStack addObject:newElement];	// go down one level
	[newElement release];
}

- (void) parser:(NSXMLParser *) parser didEndElement:(NSString *) tag namespaceURI:(NSString *) uri qualifiedName:(NSString *) name;
{ // handle closing tags
	Class c=[tagtable objectForKey:tag];
#if 0
	NSLog(@"%@ %@: </%@> -> %@", NSStringFromClass(isa), [parser _tagPath], tag, NSStringFromClass(c));
#endif
	if(!c)
		return;	// ignore
	if([c _ignore])
		return;	// ignore
	// if([currentElement _streamline] - add </tag> to the current element
	if(![c _closeNotRequired])
		[_elementStack removeLastObject];	// go up one level
}

@end
