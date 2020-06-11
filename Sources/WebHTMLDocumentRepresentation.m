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

#if __mySTEP__	// don't include twice since we have it in our own Foundation

#import <Foundation/NSXMLParser.h>

#else		// always use our own NSXMLParser that supports -_setEncoding and _tagPath and other HTML compatibility extensions

#define NSXMLParser WebKitXMLParser								// rename class to avoid linker conflicts with Foundation
#define parser Webparser										// rename methods to avoid compiler conflicts with Foundation
#define parserDidStartDocument WebparserDidStartDocument		// rename methods to avoid compiler conflicts with Foundation
#define parserDidEndDocument WebparserDidEndDocument			// rename methods to avoid compiler conflicts with Foundation

#define __WebKit__ 1		// this disables some includes in mySTEP NSXMLParser.h/.m

#include "NSXMLParser.h"	// directly include header here - note that the class is renamed!
#include "NSXMLParser.m"	// directly include source here - note that the class is renamed!

#endif

@interface NSXMLParser (Private)
- (void) _parseData:(NSData *) data;
@end

@implementation _WebHTMLDocumentRepresentation

static NSDictionary *tagtable;

- (id) init;
{
	if((self=[super init]))
		{
		if(!tagtable)
			{
			NSBundle *bundle=[NSBundle bundleForClass:[self class]];
			NSString *path=[bundle pathForResource:@"DOMHTML" ofType:@"plist"];
#if 0
			NSLog(@"bundle for class %@=%@", NSStringFromClass([self class]), bundle);
			NSLog(@"tagtable path=%@", path);
#endif
			tagtable=[[NSDictionary alloc] initWithContentsOfFile:path];
#if 0
			NSLog(@"path=%@", path);
			NSLog(@"tagtable=%@", tagtable);
#endif
			NSAssert(tagtable, @"load <tag> table");
			}
		}
	return self;
}

- (void) dealloc;
{
#if 0
	NSLog(@"dealloc %@: %@", NSStringFromClass([self class]), self);
#endif
	[_root _setVisualRepresentation:nil];
	[_elementStack release];
	[super dealloc];
}

- (NSString *) description;
{
	return [NSString stringWithFormat:@"%@\n%@", [super description], _root];
}

- (void) _abortParsing;
{
	[_parser abortParsing];
}

// methods from WebDocumentRepresentation protocol

- (NSStringEncoding) _textEncodingByName:(NSString *) textEncoding;
{
	NSStringEncoding enc=NSASCIIStringEncoding;	// default
	if([textEncoding caseInsensitiveCompare:@"utf-8"] == NSOrderedSame)
		enc=NSUTF8StringEncoding;
	else if([textEncoding caseInsensitiveCompare:@"iso-8859-1"] == NSOrderedSame)
		enc=NSISOLatin1StringEncoding;
	else
		NSLog(@"unknown _textEncoding: %@", textEncoding);
	// FIXME: add others
	return enc;
}

- (void) _setEncodingByName:(NSString *) encoding;
{
	[_parser _setEncoding:[self _textEncodingByName:encoding]];
}

- (void) setDataSource:(WebDataSource *) dataSource;
{
	Class viewclass;
	WebFrame *frame=[dataSource webFrame];
	WebFrameView *frameView=[frame frameView];
	NSView <WebDocumentView> *view;
	viewclass=[WebView _viewClassForMIMEType:[[dataSource response] MIMEType]];	// well, we should know that...
	view=[[viewclass alloc] initWithFrame:[frameView _recommendedDocumentFrame]];
	[view setDataSource:dataSource];
	[frameView _setDocumentView:view];
	[view release];
	_root=[[[DOMHTMLDocument alloc] _initWithName:@"#document" namespaceURI:nil] autorelease];	// a new root
	[_root _setVisualRepresentation:view];	// make the view receive change notifications
	[frame _setDOMDocument:(DOMDocument *) _root];
	[(DOMHTMLDocument *) _root _setWebFrame:frame];
	[(DOMHTMLDocument *) _root _setWebDataSource:dataSource];
	_html=[[[DOMHTMLHtmlElement alloc] _initWithName:@"HTML" namespaceURI:nil] autorelease];	// build a minimal tree
	[_root appendChild:_html];
	_body=[[[DOMHTMLBodyElement alloc] _initWithName:@"BODY" namespaceURI:nil] autorelease];
	[_html appendChild:_body];
	_parser=[[NSXMLParser alloc] init];	// initialize for incremental parsing
	[_parser setDelegate:self];
	[self _setEncodingByName:[dataSource textEncodingName]];
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
#if 0
	NSLog(@"WebHTMLDocumentRepresentation finishedLoadingWithDataSource:%@", source);
#endif
	[_parser _parseData:nil];	// notify parser that no more data will arrive
}

- (void) receivedError:(NSError *) error withDataSource:(WebDataSource *) source;
{
#if 0
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
#if 0
		NSLog(@"notify delegate for title %@: %@", title, [webView frameLoadDelegate]);
#endif
		[[webView frameLoadDelegate] webView:webView didReceiveTitle:title forFrame:webFrame];	// update title
		}
	[(NSView <WebDocumentView> *)[[[source webFrame] frameView] documentView] dataSourceUpdated:source];	// notify frame view
}

- (id) _parser; { return _parser; }

- (DOMHTMLElement *) _lastObject;	{ return [_elementStack lastObject]; }
- (DOMHTMLElement *) _root;	{ return _root; }	// the root node
- (DOMHTMLElement *) _html;	{ return _html; }	// the <html> node
- (DOMHTMLElement *) _body;	{ return _body; }	// the <body> node

- (DOMHTMLElement *) _head;
{ // the <head> node
	if(!_head)
		{ // create if requested
		_head=[[DOMHTMLHeadElement alloc] _initWithName:@"HEAD" namespaceURI:nil];
		[_html insertBefore:_head :_body];	// insert before <body>
		}
	return _head;
}

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
#if 0
			NSLog(@"found <title> %@", title);
#endif
			return [title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];	// found!
			}
		}
#if 0
	NSLog(@"no <title> found in %@", _head);
#endif
	return nil;
}

- (BOOL) canProvideDocumentSource; { return YES; }

- (NSString *) documentSource;
{
	NSStringEncoding enc=[self _textEncodingByName:[_dataSource textEncodingName]];
	NSString *r=[[[NSString alloc] initWithData:[_dataSource data] encoding:enc] autorelease];
	if(!r)
		r=[[[NSString alloc] initWithData:[_dataSource data] encoding:NSASCIIStringEncoding] autorelease];
	if(!r)
		r=@"<can't display document source>";
	return r;
}

// XML Parser delegate methods for parsing HTML

- (void) parser:(NSXMLParser *) parser parseErrorOccurred:(NSError *) parseError;
{
#if 1
	NSLog(@"%@ parseErrorOccurred: %@", NSStringFromClass([self class]), parseError);
#endif
}

- (void) parser:(NSXMLParser *) parser foundCharacters:(NSString *) string;
{
	if([string length] > 0)
		{
		DOMText *r=[[DOMText alloc] _initWithName:@"#text" namespaceURI:nil];
#if 0
		NSLog(@"%@ foundCharacters: %@", NSStringFromClass([self class]), string);
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
		DOMComment *r=[[DOMComment alloc] _initWithName:@"#comment" namespaceURI:nil];
#if 0
		NSLog(@"%@ foundComment: %@", NSStringFromClass([self class]), string);
#endif
		[r setData:comment];
		[[_elementStack lastObject] appendChild:r];
		[r release];
		}
}

- (void) parser:(NSXMLParser *) parser foundCData:(NSData *) cdata;
{
	DOMCDATASection *r=[[DOMCDATASection alloc] _initWithName:@"#CDATA" namespaceURI:nil];
	NSString *string=[[NSString alloc] initWithData:cdata encoding:NSUTF8StringEncoding];	// which encoding???
#if 0
	NSLog(@"%@ foundCDATA: %@", NSStringFromClass([self class]), string);
#endif
	[r setData:string];
	[[_elementStack lastObject] appendChild:r];
	[r release];
	[string release];
}

/* FIXME:

 - ... foundDOCTYPE:
 
 add DOMDocumentType child to DOMDocument so that -[DOMDocument doctype] can return it
 */

- (void) parser:(NSXMLParser *) parser foundIgnorableWhitespace:(NSString *) whitespaceString;
{
#if 0	// ignore ignorable text
	if([whitespaceString length] > 0)
		{
		DOMText *r=[[DOMText alloc] _initWithName:@"#text" namespaceURI:nil];
#if 0
		NSLog(@"%@ foundIgnorableWhitespace: %@", NSStringFromClass([self class]), whitespaceString);
#endif
		[r setData:whitespaceString];
		[[_elementStack lastObject] appendChild:r];
		[r release];
		}
#endif
}

- (void) parser:(NSXMLParser *) parser didStartElement:(NSString *) tag namespaceURI:(NSString *) uri qualifiedName:(NSString *) name attributes:(NSDictionary *) attributes;
{ // handle opening tags
	Class c=NSClassFromString([tagtable objectForKey:tag]);
	DOMHTMLElement *newElement=nil;
	DOMHTMLElement *parent;
	NSEnumerator *e;
	NSString *key;
	DOMHTMLNestingStyle nesting;
#if 0
	NSLog(@"%@ %@: <%@> -> %@", NSStringFromClass([self class]), [parser _tagPath], tag, NSStringFromClass(c));
#endif
	if(!c)
		{
#if 0
		NSLog(@"%@ %@: <%@> ignored - no class found", NSStringFromClass([self class]), [parser _tagPath], tag);
#endif
		return;	// ignore
		}
	nesting=[c _nesting];
	if(nesting == DOMHTMLIgnore)
		return;	// ignore
	if(nesting == DOMHTMLLazyNesting)
		{ // virtually close previous node if both are lazily nested -- <p>xxx<p>yyy</p></p>
#if OLD
#if 0	// some test code
		id last=[_elementStack lastObject];
		Class class=[last class];
		DOMHTMLNestingStyle nesting=[class _nesting];
#if 0
		if([newElement isKindOfClass:[DOMHTMLParagraphElement class]])
			NSLog(@"last %@", last);
#endif
#endif
		if([[[_elementStack lastObject] class] _nesting] == DOMHTMLLazyNesting)
			{ // has been pushed
			[[_elementStack lastObject] _elementLoaded];	// run any finalizing code
			[_elementStack removeLastObject];	// go up one level
			}
#else
		/*
		 * we check if we would be nested in a node of the same type
		 * if yes, we close all open children of that node
		 * and make us a sibling
		 * this guarantees that
		 * e.g. <li><p><p> becomes <li><p></p><p></p></li>
		 *
		 * FIXME: <h1> elements should break a <p> or <li> as well, but not a <td>
		 */
		unsigned int i=[_elementStack count], j=i;
		tag=[tag uppercaseString];
		while(i > 0)
			{
//			NSLog(@"%@ vs. %@", [[_elementStack objectAtIndex:i-1] tagName], tag);
			// instead of comparing names we might need sort of "priority"
			// so that we end a <p> or <li> as well by a <h1> which goes even further up in the tree
			if([[[_elementStack objectAtIndex:--i] tagName] isEqualToString:tag])
				{ // we found someone at index i whom we consider a sibling and not a parent
					while(j > i)
						{ // close all elements between our sibling and us
						DOMHTMLElement *e=[_elementStack objectAtIndex:--j];
						[e _elementLoaded];
						[_elementStack removeLastObject];
						}
					break;
				}
			}
#endif
		}
	parent=[c _designatedParentNode:self];
#if 0
	NSLog(@"<%@> parent node=%@", tag, parent);
#endif
	if(nesting == DOMHTMLSingletonNesting)
		{ // look if designated parent already has a singleton node
		NSArray *children=[[parent childNodes] _list];
		unsigned int i, cnt=[children count];
		NSString *t=[tag uppercaseString];
		for(i=0; i<cnt; i++)
			{
			if([[[children objectAtIndex:i] nodeName] isEqualToString:t])
				{
				newElement=[children objectAtIndex:i];
#if 0
				NSLog(@"matching singleton %@", newElement);
#endif
				break;	// found!
				}
			}
		}
	if(!newElement)
		{ // not a singleton or not yet a child of the desigated parent
		newElement=[[[c alloc] _initWithName:[tag uppercaseString] namespaceURI:uri] autorelease];
		if(!newElement)
			{
			NSLog(@"could not alloc element for tag <%@> of class %@", tag, NSStringFromClass(c));
			return;	// ignore if we can't allocate
			}
		[parent appendChild:newElement];	// make sibling
		}
	e=[attributes keyEnumerator];
	while((key=[e nextObject]))
		{ // attach or merge attributes
		NSString *val=[attributes objectForKey:key];
		if([val class] == [NSNull class])
			val=nil;
		if(![newElement hasAttribute:key])
			[newElement setAttribute:key :val];	// like Safari: merges only not-yet-existing attributes from a repeated tag (e.g. <body attr1></body><body attr2></body>) 
		}
	if(nesting == DOMHTMLStandardNesting || nesting == DOMHTMLLazyNesting)
		[_elementStack addObject:newElement];	// go down one level for new element
	NS_DURING
		[newElement _elementDidAwakeFromDocumentRepresentation:self];
	NS_HANDLER
		if(NSRunAlertPanel(@"An internal parse exception occurred\nPlease report to <http://projects.goldelico.com/p/swk/issues>",
						@"URL: <%@>\nTag: <%@>\nException: %@",
						@"Continue",
						@"Abort",
						nil,
						[[[[[(DOMHTMLDocument *) [parent ownerDocument] webFrame] dataSource] request] URL] absoluteString],
						tag,
						localException
						) == NSAlertAlternateReturn)
			[localException raise];	// should end any processing
	NS_ENDHANDLER
}

- (void) parser:(NSXMLParser *) parser didEndElement:(NSString *) tag namespaceURI:(NSString *) uri qualifiedName:(NSString *) name;
{ // handle closing tags
	Class c=NSClassFromString([tagtable objectForKey:tag]);
	DOMHTMLNestingStyle nesting=[c _nesting];
	DOMHTMLElement *element;
#if 0
	NSLog(@"%@ %@: </%@> -> %@", NSStringFromClass([self class]), [parser _tagPath], tag, NSStringFromClass(c));
#endif
	if(!c)
		return;	// ignore
	if(nesting == DOMHTMLIgnore)
		return;	// ignore
	tag=[tag uppercaseString];
	element=[_elementStack lastObject];
	if([[element nodeName] isEqualToString:tag])
		{ // has been pushed
		[element _elementLoaded];			// any finalizing code
		[_elementStack removeLastObject];	// go up one level
		}
}

- (void) parserDidEndDocument:(NSXMLParser *) parser
{ // done
#if 0
	NSLog(@"WebHTMLDocumentRepresentation parserDidEndDocument:%@", parser);
#endif
	[_parser release];
	_parser=nil;
	[[_dataSource webFrame] _finishedLoading];	// notify
}

@end


@implementation _WebRTFDocumentRepresentation

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
	[super setDataSource:dataSource];
}

- (void) finishedLoadingWithDataSource:(WebDataSource *) source;
{
	[[source webFrame] _finishedLoading];	// notify
}

- (void) receivedError:(NSError *) error withDataSource:(WebDataSource *) source;
{
#if 0
	NSLog(@"WebHTMLDocumentRepresentation receivedError: %@", error);
#endif
}

- (void) receivedData:(NSData *) data withDataSource:(WebDataSource *) source;
{ // we are repeatedly called for each data fragment!
	[(NSView <WebDocumentView> *)[[[source webFrame] frameView] documentView] dataSourceUpdated:source];	// notify frame view
}

- (NSString *) title;
{ // try to get from RTF
	return nil;
}

- (BOOL) canProvideDocumentSource; { return NO; }

- (NSString *) documentSource; { return nil; }

@end
