/* simplewebkit
   WebHTMLDocumentRepresentation.m

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

//  parse HTML document into DOMHTML node structure (using NSXMLParser as the scanner)

#import "Private.h"
#import "WebHTMLDocumentRepresentation.h"
#import <WebKit/WebDocument.h>

#if defined(__mySTEP__) || defined(GNUSTEP)
#define USE_FOUNDATION_XML_PARSER 1	// yes - don't include twice since we have it in our own Foundation
#else
#define USE_FOUNDATION_XML_PARSER 0	// no - Apple Foundation's NSXMLParser does not support -_setEncoding and _tagPath and other HTML compatibility extensions
#endif

#if USE_FOUNDATION_XML_PARSER

#import <Foundation/NSXMLParser.h>

#else		// always make mySTEP XMLParser available

#define NSXMLParser WebKitXMLParser				// rename to avoid linker conflicts with Foundation
#define __WebKit__ 1							// this disables some includes in mySTEP NSXMLParser.h/.m

#include "NSXMLParser.h"	// directly include header here - note that the class is renamed!
#include "NSXMLParser.m"	// directly include source here - note that the class is renamed!

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
					[DOMHTMLHtmlElement class], @"html",
					[DOMHTMLHeadElement class], @"head",
					[DOMHTMLTitleElement class], @"title",
					[DOMHTMLMetaElement class], @"meta",
					[DOMHTMLLinkElement class], @"link",
					[DOMHTMLStyleElement class], @"style",
					[DOMHTMLScriptElement class], @"script",
					[DOMHTMLFrameSetElement class], @"frameset",
					[DOMHTMLFrameElement class], @"frame",
					[DOMHTMLIFrameElement class], @"iframe",
					[DOMHTMLObjectElement class], @"object",
					[DOMHTMLParamElement class], @"param",
					[DOMHTMLObjectElement class], @"applet",
					[DOMHTMLBodyElement class], @"body",
					[DOMHTMLDivElement class], @"div",
					[DOMHTMLSpanElement class], @"span",
					[DOMHTMLFontElement class], @"font",
					[DOMHTMLAnchorElement class], @"a",
					[DOMHTMLImageElement class], @"img",
					[DOMHTMLBRElement class], @"br",
					[DOMHTMLElement class], @"nobr",
					[DOMHTMLParagraphElement class], @"p",
					[DOMHTMLHRElement class], @"hr",
					[DOMHTMLTableElement class], @"table",
					[DOMHTMLTableRowElement class], @"tr",
					[DOMHTMLTableCellElement class], @"th",
					[DOMHTMLTableCellElement class], @"td",
					[DOMHTMLFormElement class], @"form",
					[DOMHTMLInputElement class], @"input",
					[DOMHTMLButtonElement class], @"button",
					[DOMHTMLSelectElement class], @"select",
					[DOMHTMLOptionElement class], @"option",
					[DOMHTMLOptGroupElement class], @"optgroup",
					[DOMHTMLLabelElement class], @"label",
					[DOMHTMLTextAreaElement class], @"textarea",
				
				// FIXME: - should be implemented (?as special classes?)
					[DOMHTMLElement class], @"caption",
					[DOMHTMLElement class], @"col",
					[DOMHTMLElement class], @"colgroup",
					[DOMHTMLElement class], @"tfoot",
					[DOMHTMLElement class], @"thead",
					[DOMHTMLElement class], @"ul",
					[DOMHTMLElement class], @"ol",
					[DOMHTMLElement class], @"dl",
					[DOMHTMLElement class], @"li",
					[DOMHTMLElement class], @"dd",
					[DOMHTMLElement class], @"dt",
				
				// stored in standard elements
					[DOMHTMLElement class], @"tbody",
					[DOMHTMLElement class], @"noframes",
					[DOMHTMLElement class], @"noscript",
					[DOMHTMLElement class], @"center",
					[DOMHTMLElement class], @"bdo",
					[DOMHTMLElement class], @"big",
					[DOMHTMLElement class], @"small",
					[DOMHTMLElement class], @"sub",
					[DOMHTMLElement class], @"sup",
					[DOMHTMLElement class], @"em",
					[DOMHTMLElement class], @"b",
					[DOMHTMLElement class], @"i",
					[DOMHTMLElement class], @"u",
					[DOMHTMLElement class], @"s",
					[DOMHTMLElement class], @"tt",
					[DOMHTMLElement class], @"strike",
					[DOMHTMLElement class], @"h1",
					[DOMHTMLElement class], @"h2",
					[DOMHTMLElement class], @"h3",
					[DOMHTMLElement class], @"h4",
					[DOMHTMLElement class], @"h5",
					[DOMHTMLElement class], @"h6",
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
	return [NSString stringWithFormat:@"%@\n%@", [super description], _doc];
}

// methods from WebDocumentRepresentation protocol

- (void) setDataSource:(WebDataSource *) dataSource;
{
	Class viewclass;
	WebFrame *frame=[dataSource webFrame];
	WebFrameView *frameView=[frame frameView];
	NSView <WebDocumentView> *view;
	[super setDataSource:dataSource];
	// well, we should know that...
	viewclass=[WebView _viewClassForMIMEType:[[dataSource response] MIMEType]];
	view=[[viewclass alloc] initWithFrame:[frameView frame]];
	[frameView _setDocumentView:view];
	[[frame DOMDocument] _setVisualRepresentation:view];	// make the view receive change notifications
	[view release];
}

- (void) finishedLoadingWithDataSource:(WebDataSource *) source;
{
#if 1
	NSLog(@"WebHTMLDocumentRepresentation finishedLoadingWithDataSource");
#endif
	// FIXME: if we are still loading - prefer provisionalDataSource
	[[[[source webFrame] parentFrame] dataSource] addSubresource:[source mainResource]];	// frame has been loaded
	[[source webFrame] _finishedLoading];	// notify
}

- (void) receivedError:(NSError *) error withDataSource:(WebDataSource *) source;
{
#if 1
	NSLog(@"WebHTMLDocumentRepresentation receivedError: %@", error);
#endif
}

- (void) receivedData:(NSData *) data withDataSource:(WebDataSource *) source;
{ // we are repeatedly called!
	DOMHTMLHtmlElement *html;
#if 1
	NSLog(@"WebHTMLDocumentRepresentation receivedData");
//	NSLog(@"document source: %@", [self documentSource]);
#endif
	_parser=[[NSXMLParser alloc] initWithData:data];
	// FIXME: translate encoding from dataSource/response settings
//	[_parser _setEncoding:NSUTF8StringEncoding];
	[_parser setDelegate:self];
	_doc=[[source webFrame] DOMDocument];
	[_doc removeChild:[_doc lastChild]];	// remove current HTML DOM tree to build up a new one
	_root=[[DOMHTMLDocument alloc] _initWithName:@"#document" namespaceURI:nil document:_doc];	// a new root
	[(DOMHTMLDocument *) _root _setWebFrame:[source webFrame]];
	[(DOMHTMLDocument *) _root _setWebDataSource:source];
	[_doc appendChild:_root];
	html=[[DOMHTMLHtmlElement alloc] _initWithName:@"HTML" namespaceURI:nil document:_doc];
	[_root appendChild:html];
	_head=[[DOMHTMLHeadElement alloc] _initWithName:@"HEAD" namespaceURI:nil document:_doc];
	[html appendChild:_head];
	_body=[[DOMHTMLBodyElement alloc] _initWithName:@"BODY" namespaceURI:nil document:_doc];
	[html appendChild:_body];
	[_elementStack release];
	_elementStack=[[NSMutableArray alloc] initWithCapacity:20];
	[_elementStack addObject:_body];	// append whatever is parsed to body
	[_root release];
#if 0
	NSLog(@"parser: %@", _parser);
#endif
	// FIXME: we should have incremental parsing...
	if(![_parser parse])	// as far as we come :-)
		{ // partial load
#if 1
		NSLog(@"parse failed due to %@", [_parser parserError]);	// shouldn't be printed...
#endif
		}
	[_parser release];
	[[source webFrame] _receivedData:source];	// notify a new DOM tree
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

- (void) parser:(NSXMLParser *) parser foundComment:(NSString *) comment;
{
	if([comment length] > 0)
		{
		DOMComment *r=[[DOMComment alloc] _initWithName:@"#comment" namespaceURI:nil document:_doc];
#if 0
		NSLog(@"%@ foundComment: %@", NSStringFromClass(isa), string);
#endif
		[r setData:comment];
		[[_elementStack lastObject] appendChild:r];
		[r release];
		}
}

- (void) parser:(NSXMLParser *) parser foundCData:(NSData *) cdata;
{
	DOMCDATASection *r=[[DOMCDATASection alloc] _initWithName:@"#CDATA" namespaceURI:nil document:_doc];
#if 0
	NSLog(@"%@ foundCDATA: %@", NSStringFromClass(isa), string);
#endif
// FIXME:		[r setData:string];
	[[_elementStack lastObject] appendChild:r];
	[r release];
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
	newElement=[[c alloc] _initWithName:[tag uppercaseString] namespaceURI:uri document:_doc];
	if(!newElement)
		{
		NSLog(@"did not alloc?");
		return;	// ignore if we can't allocate
		}
	e=[attributes keyEnumerator];
	while((key=[e nextObject]))
		{ // attach attributes
		NSString *val=[attributes objectForKey:key];
		if([val class] == [NSNull class])
			val=nil;
		[newElement setAttribute:key :val];
		}
	/* handle some special cases -> should be moved to a private method of the elements whose default implementation does nothing */
	if(c == [DOMHTMLFrameSetElement class] && !_frameSet)
		{ // first level <frameset>
		[[_body parentNode] appendChild:newElement];	// make sibling
		_frameSet=newElement;
		}
	[newElement _awakeFromDocumentRepresentation:self];
	// FIXME: create a <TBODY> for a <TABLE> on the first <tr> and ignore the <TBODY> tag
	// FIXME: if we are a H tag and the lastObject as well, make us a sibling not a child of the header
	// nesting rules
	// <p> is not nested, <h> is not nested, <table> is only nested within a <td> or <th>
	if([c _goesToHead])
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
