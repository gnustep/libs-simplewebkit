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

#if __mySTEP__
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
- (void) _parseData:(NSData *) data;	// incremental parsing
- (void) _stall:(BOOL) flag;
- (BOOL) _isStalled;
@end

@implementation _WebHTMLDocumentRepresentation

static NSDictionary *tagtable;

- (id) init;
{
	if((self=[super init]))
		{
		if(!tagtable)
			// FIXME: read from a resources .plist file
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
				
				[DOMHTMLNoFramesElement class], @"noframes",
				[DOMHTMLPreElement class], @"pre",
				[DOMHTMLCenterElement class], @"center",
				[DOMHTMLHeadingElement class], @"h1",
				[DOMHTMLHeadingElement class], @"h2",
				[DOMHTMLHeadingElement class], @"h3",
				[DOMHTMLHeadingElement class], @"h4",
				[DOMHTMLHeadingElement class], @"h5",
				[DOMHTMLHeadingElement class], @"h6",

				// stored in standard elements
					[DOMHTMLElement class], @"tbody",
					[DOMHTMLElement class], @"noscript",
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
				[DOMHTMLElement class], @"strong",
				[DOMHTMLElement class], @"var",
				[DOMHTMLElement class], @"code",
				[DOMHTMLElement class], @"samp",
				[DOMHTMLElement class], @"kbd",
				[DOMHTMLElement class], @"cite",
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

- (void) abortParsing;
{
	[_parser abortParsing];
}

// methods from WebDocumentRepresentation protocol

- (void) setDataSource:(WebDataSource *) dataSource;
{
	Class viewclass;
	DOMHTMLHtmlElement *html;
	WebFrame *frame=[dataSource webFrame];
	WebFrameView *frameView=[frame frameView];
	NSView <WebDocumentView> *view;
	// well, we should know that...
	viewclass=[WebView _viewClassForMIMEType:[[dataSource response] MIMEType]];
	view=[[viewclass alloc] initWithFrame:[frameView frame]];
	[view setDataSource:dataSource];
	[frameView _setDocumentView:view];
	[view release];
	_doc=[frame DOMDocument];
	[_doc _setVisualRepresentation:view];	// make the view receive change notifications
	[_doc removeChild:[_doc firstChild]];	// if there is one from the last load
	_root=[[DOMHTMLDocument alloc] _initWithName:@"#document" namespaceURI:nil document:_doc];	// a new root
	[(DOMHTMLDocument *) _root _setWebFrame:frame];
	[(DOMHTMLDocument *) _root _setWebDataSource:dataSource];
	[_doc appendChild:_root];
	html=[[DOMHTMLHtmlElement alloc] _initWithName:@"HTML" namespaceURI:nil document:_doc];
	[_root appendChild:html];
	_head=[[DOMHTMLHeadElement alloc] _initWithName:@"HEAD" namespaceURI:nil document:_doc];
	[html appendChild:_head];
	_body=[[DOMHTMLBodyElement alloc] _initWithName:@"BODY" namespaceURI:nil document:_doc];
	[html appendChild:_body];
	[_root release];
	_parser=[[NSXMLParser alloc] init];	// initialize for incremental parsing
	[_parser setDelegate:self];
	// translate [dataSource textEncodingName] - if known
	// [_parser _setEncoding:NSUTF8StringEncoding];
#if 0
	NSLog(@"parser: %@", _parser);
#endif
	[_elementStack release];
	_elementStack=[[NSMutableArray alloc] initWithCapacity:20];
	[_elementStack addObject:_body];	// append whatever is parsed to body
	[super setDataSource:dataSource];
}

- (void) finishedLoadingWithDataSource:(WebDataSource *) source;
{
#if 1
	NSLog(@"WebHTMLDocumentRepresentation finishedLoadingWithDataSource:%@", source);
#endif
	[_parser _parseData:nil];	// finish parsing
	[_parser release];
	_parser=nil;
	[[source webFrame] _finishedLoading];	// notify
}

- (void) receivedError:(NSError *) error withDataSource:(WebDataSource *) source;
{
#if 1
	NSLog(@"WebHTMLDocumentRepresentation receivedError: %@", error);
#endif
}

- (void) receivedData:(NSData *) data withDataSource:(WebDataSource *) source;
{ // we are repeatedly called for each data fragment!
	NSString *title;
	NSAutoreleasePool *arp;
#if 0
	NSLog(@"WebHTMLDocumentRepresentation receivedData %@", data);
//	NSLog(@"document source: %@", [self documentSource]);
#endif
#if 0	// RUN A PARSER ROBUSTNESS TEST - NOTE: this might need Gigabytes to print the logs
	{ // pass byte for byte to check if the parser correctly handles incomplete tags
		unsigned i, len=[data length];
		for(i=0; i<len; i++)
			[_parser _parseData:[data subdataWithRange:NSMakeRange(i, 1)]];	// parse next byte
	}
#else
	arp=[NSAutoreleasePool new];
	[_parser _parseData:data];	// parse next fragment
	[arp release];	// immediately clean up all temporaries
#endif
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

- (id) _parser; { return _parser; }

- (NSString *) title;
{ // return the value of the first DOMHTMLTitleElement's #text
	DOMNodeList *children=[_head childNodes];
	int i, cnt=[children length];
	for(i=0; i<cnt; i++)
		{
		DOMHTMLTitleElement *n=(DOMHTMLTitleElement *)[children item:i];
		if([n isKindOfClass:[DOMHTMLTitleElement class]])
			{ // is really a title element - collect all children text elements
			DOMNodeList *children=[n childNodes];
			unsigned cnt=[children length];
			unsigned i;
			NSString *title=@"";
			for(i=0; i<cnt; i++)
				{
				DOMText *t=(DOMText *)[children item:i];
				if([t isKindOfClass:[DOMText class]])
					{ // is really a text element
#if 0
					NSLog(@"found <title> fragment %@", [t data]);
#endif
					title=[title stringByAppendingString:[t data]];	// splice
					}
				}
#if 1
			NSLog(@"found <title> %@", title);
#endif
			return [title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];	// found!
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
	NSString *string=[[NSString alloc] initWithData:cdata encoding:NSUTF8StringEncoding];	// which encoding???
#if 0
	NSLog(@"%@ foundCDATA: %@", NSStringFromClass(isa), string);
#endif
	[r setData:string];
	[[_elementStack lastObject] appendChild:r];
	[r release];
	[string release];
}

- (void) parser:(NSXMLParser *) parser foundIgnorableWhitespace:(NSString *) whitespaceString;
{
#if 0
	if([whitespaceString length] > 0)
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
		if([attributes count] > 0)
			NSLog(@"FIXME: should copy attributes for <%@>: %@", tag, attributes);
		return;	// ignore
		}
	newElement=[[c alloc] _initWithName:[tag uppercaseString] namespaceURI:uri document:_doc];
	if(!newElement)
		{
		NSLog(@"did not alloc element for tag <%@> of class %@", tag, NSStringFromClass(c));
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
	[[_elementStack lastObject] _elementLoaded];	// any finalizing code
	// if([currentElement _streamline] - add </tag> to the current element
	if(![c _closeNotRequired])
		[_elementStack removeLastObject];	// go up one level
}

@end
