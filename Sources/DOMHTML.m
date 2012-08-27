/* simplewebkit
 DOMHTML.m
 
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

// FIXME: learn from http://www.w3.org/TR/2004/REC-DOM-Level-3-Core-20040407/core.html
// FIXME: move everything that is 'View' related to WebHTMLDocumentView.m so that this class tree is a pure 'Model'

#import <WebKit/WebView.h>
#import <WebKit/WebResource.h>
#import <WebKit/WebPreferences.h>
#import "WebHTMLDocumentView.h"
#import "WebHTMLDocumentRepresentation.h"
#import "Private.h"

@interface DOMHTMLFormElement (Private)
- (void) _submitForm:(DOMHTMLElement *) clickedElement;
@end

@interface DOMCSSValue (Private)
- (NSString *) _toString;
- (NSString *) _toStringArray;
@end

@interface NSTextBlock (Attributes)
- (void) _setTextBlockAttributes:(DOMHTMLElement *) element	paragraph:(NSMutableParagraphStyle *) paragraph;
@end

@interface DOMHTMLInputElement (Forms)
- (void) _submit:(id) sender;
- (void) _reset:(id) sender;
- (void) _checkbox:(id) sender;
- (void) _resetForm:(DOMHTMLElement *) ignored;
- (void) _radio:(id) sender;
- (void) _radioOff:(DOMHTMLElement *) clickedCell;
- (NSString *) _formValue;	// return nil if not successful according to http://www.w3.org/TR/html401/interact/forms.html#h-17.3 17.13.2 Successful controls
@end

@implementation DOMHTMLCollection

- (id) init
{
	if((self = [super init]))
		{
		elements=[NSMutableArray new]; 
		}
	return self;
}

- (void) dealloc
{
	[elements release];
	[super dealloc];
}

- (DOMElement *) appendChild:(DOMElement *) element;
{
	[elements addObject:element];
	return element;
}

- (DOMNodeList *) childNodes; { return NIMP; }
- (DOMElement *) cloneNode:(BOOL) deep; { return NIMP; }
- (DOMElement *) firstChild; { return [elements objectAtIndex:0]; }
- (BOOL) hasChildNodes; { return [elements count] > 0; }
- (DOMElement *) insertBefore:(DOMElement *) node :(DOMElement *) ref; { return NIMP; }
- (DOMElement *) lastChild; { return [elements lastObject]; }
- (DOMElement *) nextSibling; { return NIMP; }
- (DOMElement *) previousSibling; { return NIMP; }
- (DOMElement *) removeChild:(DOMNode *) node; { [elements removeObject:node]; return (DOMElement *) self; }
- (DOMElement *) replaceChild:(DOMNode *) node :(DOMNode *) old; { return NIMP; }

- (void) _makeObjectsPerformSelector:(SEL) sel withObject:(id) obj
{
	[elements makeObjectsPerformSelector:sel withObject:obj];
}

@end

@implementation DOMElement (DOMHTMLElement)

// parser information

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLStandardNesting; }	// default implementation

+ (DOMHTMLElement *) _designatedParentNode:(_WebHTMLDocumentRepresentation *) rep;
{ // return the parent node (nil to ignore)
	return [rep _lastObject];	// default is to build a tree
}

// DOMDocumentAdditions

- (DOMCSSRuleList *) getMatchedCSSRules:(DOMElement *) elt :(NSString *) pseudoElt;
{
	NIMP;
	// call -[DOMCSSStyleRule _ruleMatchesElement:(DOMElement *) element pseudoElement:(NSString *) pseudoElement]
	// and collect all matching rules
	return nil;
}

- (WebFrame *) webFrame
{
	return [(DOMHTMLDocument *) [self ownerDocument] webFrame];	// should be a DOMHTMLDocument (subclass of DOMDocument)
}

- (NSURL *) URLWithAttributeString:(NSString *) string;	// we don't inherit from DOMDocument...
{
	DOMHTMLDocument *htmlDocument=(DOMHTMLDocument *) [self ownerDocument];
	NSURL *url=[[NSURL URLWithString:[self valueForKey:string] relativeToURL:[[[htmlDocument _webDataSource] response] URL]] absoluteURL];
#if 1
	NSLog(@"URL %@ -> %@", [self valueForKey:string], url);
#endif
	return url;
}

- (NSData *) _loadSubresourceWithAttributeString:(NSString *) string blocking:(BOOL) stall;
{
	NSURL *url=[self URLWithAttributeString:string];
	if(url)
		{
		WebDataSource *source=[(DOMHTMLDocument *) [self ownerDocument] _webDataSource];
		WebResource *res=[source subresourceForURL:url];
		WebDataSource *sub;
		NSData *data;
		if(res)
			{
#if 0
			NSLog(@"sub: already completely loaded: %@ (%u bytes)", url, [[res data] length]);
#endif
			// should we call _finishedLoading???
			return [res data];	// already completely loaded
			}
		sub=[source _subresourceWithURL:url delegate:(id <WebDocumentRepresentation>) self];	// triggers loading if not yet and make me receive notification
#if 0
		NSLog(@"sub: loading: %@ (%u bytes) delegate=%@", url, [[sub data] length], self);
#endif
		data=[sub data];
		if(!data && stall)	// incomplete
			[[(_WebHTMLDocumentRepresentation *) [source representation] _parser] _stall:YES];	// make parser stall until we have loaded
		return data;
		}
	return nil;
}

// WebDocumentRepresentation callbacks

- (void) setDataSource:(WebDataSource *) dataSource; { return; }

- (void) finishedLoadingWithDataSource:(WebDataSource *) source;
{ // our subresource did load - i.e. we can clear the stall on the main HTML script
	DOMHTMLDocument *htmlDocument=(DOMHTMLDocument *) [self ownerDocument];
	WebDataSource *mainsource=[htmlDocument _webDataSource];
#if 0
	NSLog(@"clear stall for %@", self);
	NSLog(@"source: %@", source);
	NSLog(@"mainsource: %@", mainsource);
	NSLog(@"rep: %@", [mainsource representation]);
	NSLog(@"parser: %@", [(_WebHTMLDocumentRepresentation *) [mainsource representation] _parser]);
	if(![(_WebHTMLDocumentRepresentation *) [mainsource representation] _parser])
		NSLog(@"no parser");
#endif
	[[(_WebHTMLDocumentRepresentation *) [mainsource representation] _parser] _stall:NO];
}

- (void) receivedData:(NSData *) data withDataSource:(WebDataSource *) source;
{ // we received the next framgment of the script
#if 0
	NSLog(@"stalling subresource %@ receivedData: %u", NSStringFromClass(isa), [[source data] length]);
#endif
}

- (void) receivedError:(NSError *) error withDataSource:(WebDataSource *) source;
{ // error loading external script
	NSLog(@"%@ receivedError: %@", NSStringFromClass(isa), error);
}

- (void) _triggerEvent:(NSString *) event;
{
	WebView *webView=[[self webFrame] webView];
#if 1
	NSLog(@"trigger %@", event);
#endif
	if([[webView preferences] isJavaScriptEnabled])
		{
		NSString *script=[(DOMElement *) self valueForKey:event];	// try to read script
		if(script)
			{
#if 0
			NSLog(@"  script=%@", event, script);
#endif
#if 0
				{
				id r;
				NSLog(@"trigger <script>%@</script>", script);
				r=[self evaluateWebScript:script];	// try to parse and directly execute script in current document context
				NSLog(@"result=%@", r);
				}
#else
			[self evaluateWebScript:script];	// evaluate code defined by event attribute (protected against exceptions)
#endif
			}
		}
	// special hack
	else if([event isEqualToString:@"onclick"])
		{ // handle special case...
			NSString *script=[(DOMElement *) self valueForKey:event];
			if([script isEqualToString:@"document.Destination.submit()"])
				[[self valueForKey:@"form"] _submitForm:(DOMHTMLElement *) self];
		}
}

- (void) _elementDidAwakeFromDocumentRepresentation:(_WebHTMLDocumentRepresentation *) rep;
{ // our subclasses should call [super _elementDidAwakeFromDocumentRepresentation:rep];
	// FIXME: this appears to be case sensitive!
	[self _triggerEvent:@"onload"];
}

- (void) _elementLoaded; { return; } // ignore

@end

@implementation DOMHTMLElement

// layout and rendering

- (NSString *) innerHTML;
{ // HTML within this node
	NSString *str=@"";
	int i;
	for(i=0; i<[_childNodes length]; i++)
		{
		NSString *d=[(DOMHTMLElement *) [_childNodes item:i] outerHTML];
		str=[str stringByAppendingString:d];
		}
	return str;
}

- (NSString *) outerHTML;
{ // include this node tags
	NSMutableString *str=[NSMutableString stringWithFormat:@"<%@", [self nodeName]];
	if([self respondsToSelector:@selector(_attributes)])
		{
		DOMNamedNodeMap *attributes=[self attributes];
		unsigned int i, cnt=[attributes length];
		for(i=0; i<cnt; i++)
			{
			DOMAttr *a=[attributes item:i];
			if([a specified])
				// fixme: escape quotes etc.
				[str appendFormat:@" %@=\"%@\"", [a name], [a value]];			
			else
				[str appendFormat:@" %@", [a name]];			
			}
		}
	[str appendFormat:@">%@", [self innerHTML]];
	if([[self class] _nesting] != DOMHTMLNoNesting)
		[str appendFormat:@"</%@>\n", [self nodeName]];	// close
	return str;
}


// Hm... how do we run the parser here?
// it can't be the full parser
// what happens if we set illegal html?
// what happens if we set unbalanced nodes
// what happens if we set e.g. <head>, <script>, <frame> etc.?

- (void) setInnerHTML:(NSString *) str; { NIMP; }
- (void) setOuterHTML:(NSString *) str; { NIMP; }

- (NSAttributedString *) attributedString;
{ // recursively get attributed string representing this node and subnodes
	NSMutableAttributedString *str=[[[NSMutableAttributedString alloc] init] autorelease];
	[[[self webFrame] webView] _spliceNode:self to:str pseudoElement:@"" parentStyle:nil parentAttributes:nil];	// recursively splice all child element strings into this string
	return str;
}

// methods to be overwritten in node specific subclasses

- (NSString *) _string; { return @""; } // default is no contents

- (NSTextAttachment *) _attachment; { return nil; }	// default is no attachment

// REMOVEME:

- (void) OLD_addAttributesToStyle:(DOMCSSStyleDeclaration *) style;			// add node specific attributes to style
{ // allow nodes to override by examining the attributes and overwrite the default style (CSS still takes precedence)
	return;
}

@end

// REMOVEME:

@implementation DOMNode (Content)

- (void) _spliceTo:(NSMutableAttributedString *) str;
{
	WebView *webView=[[(DOMHTMLElement *) self webFrame] webView];
	[webView _spliceNode:self to:str pseudoElement:@"" parentStyle:nil parentAttributes:nil];
}

@end

@implementation DOMCharacterData (DOMHTMLElement)	// this is subclass of DOMNode and not DOMElement!

- (NSString *) outerHTML;
{
	// escape entities
	return [self data];
}

- (NSString *) innerHTML;
{
	// escape entities
	return [self data];
}

- (NSString *) _string;
{
	return [self data];	// character string
}

- (NSTextAttachment *) _attachment; { return nil; }	// no attachment

@end

@implementation DOMCDATASection (DOMHTMLElement)

- (NSString *) outerHTML;
{
	// FIXME: escape characters if needed
	return [NSString stringWithFormat:@"<![CDATA[%@]]>", [(DOMHTMLElement *)self innerHTML]];
}

- (NSString *) _string;
{
	return @"";	// ignore
}

- (NSTextAttachment *) _attachment; { return nil; }	// no attachment

@end

@implementation DOMComment (DOMHTMLElement)

- (NSString *) outerHTML;
{
	// FIXME: escape embeded -- characters
	return [NSString stringWithFormat:@"<!--%@-->\n", [(DOMHTMLElement *)self innerHTML]];
}

- (NSString *) _string;
{
	return @"";	// ignore
}

- (NSTextAttachment *) _attachment; { return nil; }	// no attachment

@end

@implementation DOMHTMLDocument

- (id) init
{
	if((self = [super init]))
		{
		// we could simply add this as properties/attributes
		anchors=[DOMHTMLCollection new]; 
		forms=[DOMHTMLCollection new]; 
		images=[DOMHTMLCollection new]; 
		links=[DOMHTMLCollection new]; 
		styleSheets=[DOMStyleSheetList new];
		}
	return self;
}

- (void) dealloc
{
	[anchors release];
	[forms release];
	[images release];
	[links release];
	[styleSheets release];
	[super dealloc];
}

- (WebFrame *) webFrame; { return _webFrame; }

- (void) _setWebFrame:(WebFrame *) f;
{
	WebPreferences *prefs=[[f webView] preferences];
	_webFrame=f;
	if([prefs userStyleSheetEnabled])
		{
		NSURL *url=[prefs userStyleSheetLocation];
		if(url)
			{
			DOMCSSStyleSheet *sheet;
			// load sheet
			// parse
			// if ok:
			// CHECKME: is this the correct order/priority of user vs. author style sheets?
			[[(DOMHTMLDocument *) [self ownerDocument] styleSheets] _addStyleSheet:sheet];
			}
		}
}

- (WebDataSource *) _webDataSource; { return _dataSource; }
- (void) _setWebDataSource:(WebDataSource *) src; { _dataSource=src; }

- (NSString *) outerHTML;
{
	return @"";
}

- (NSString *) innerHTML;
{
	return @"";
}

- (DOMHTMLCollection *) anchors; { return anchors; }
- (DOMHTMLCollection *) forms; { return forms; }
- (DOMHTMLCollection *) images; { return images; }
- (DOMHTMLCollection *) links; { return links; }
- (DOMStyleSheetList *) styleSheets; { return styleSheets; }

@end

@implementation DOMHTMLHtmlElement

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLIgnore; }

@end

@implementation DOMHTMLHeadElement

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLIgnore; }

@end

@implementation DOMHTMLTitleElement

+ (DOMHTMLElement *) _designatedParentNode:(_WebHTMLDocumentRepresentation *) rep;
{
	return [rep _head];
}

- (void) _elementDidAwakeFromDocumentRepresentation:(_WebHTMLDocumentRepresentation *) rep;
{
	[[rep _parser] _setReadMode:2];	// switch parser mode to read up to </title> and translate entities
	// FIXME: ignore in <body>
	[super _elementDidAwakeFromDocumentRepresentation:rep];
}

@end

@implementation DOMHTMLMetaElement

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLNoNesting; }

+ (DOMHTMLElement *) _designatedParentNode:(_WebHTMLDocumentRepresentation *) rep;
{
	return [rep _head];
}

- (void) _elementDidAwakeFromDocumentRepresentation:(_WebHTMLDocumentRepresentation *) rep;
{
	NSString *cmd=[self valueForKey:@"http-equiv"];
	// FIXME: ignore in <body>
	if([cmd caseInsensitiveCompare:@"refresh"] == NSOrderedSame)
		{ // handle  <meta http-equiv="Refresh" content="4;url=http://www.domain.com/link.html">
			NSString *content=[self valueForKey:@"content"];
			NSArray *c=[content componentsSeparatedByString:@";"];
			if([c count] == 2)
				{
				DOMHTMLDocument *htmlDocument=(DOMHTMLDocument *) [self ownerDocument];
				NSString *u=[[c lastObject] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
				NSURL *url;
				NSTimeInterval seconds;
				if([[u lowercaseString] hasPrefix:@"url="])
					u=[u substringFromIndex:4];	// cut off url= prefix
				u=[u stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];	// sometimes people write "0; url = xxx"
				url=[NSURL URLWithString:u relativeToURL:[[[htmlDocument _webDataSource] response] URL]];
				if(url)
					{
					seconds=[[c objectAtIndex:0] doubleValue];
#if 0
					NSLog(@"should redirect to %@ after %lf seconds", url, seconds);
#endif
					[[self webFrame] _performClientRedirectToURL:url delay:seconds];
					}
				// else raise some error...
				}
		}
	// decode other meta
	[super _elementDidAwakeFromDocumentRepresentation:rep];
}


@end

@implementation DOMHTMLLinkElement

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLNoNesting; }

+ (DOMHTMLElement *) _designatedParentNode:(_WebHTMLDocumentRepresentation *) rep;
{
	return [rep _head];
}

- (void) _elementDidAwakeFromDocumentRepresentation:(_WebHTMLDocumentRepresentation *) rep;
{ // e.g. <link rel="stylesheet" type="text/css" href="test.css" />
	NSString *rel=[[self valueForKey:@"rel"] lowercaseString];
	// FIXME: ignore in <body>
	if([rel isEqualToString:@"stylesheet"] && [[self valueForKey:@"type"] isEqualToString:@"text/css"])
		{ // load stylesheet in background
			NSData *data=[self _loadSubresourceWithAttributeString:@"href" blocking:NO];
			NSString *media=[self getAttribute:@"media"];
			sheet=[DOMCSSStyleSheet new];	// create new (empty) sheet to store incoming rules
			[sheet setOwnerNode:self];
			[sheet setHref:[self getAttribute:@"href"]];
			if(media)
				[[sheet media] setMediaText:media];
#if 1
			NSLog(@"sheet=%@", sheet);
#endif
			[[(DOMHTMLDocument *) [self ownerDocument] styleSheets] _addStyleSheet:sheet];	// add to list of known style sheets (before loading others)
			[sheet release];
			if(data)
				{ // parse directly if already loaded
					NSString *style=[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
#if 1
					NSLog(@"parsing <link> directly");
#endif
					[sheet _setCssText:style];	// parse the style sheet to add
					[style release];
				}
		}
#if 1
	else if([rel isEqualToString:@"home"])
		{
		NSLog(@"<link>: %@", [self outerHTML]);
		}
 	else if([rel isEqualToString:@"alternate"])
		{
		NSLog(@"<link>: %@", [self outerHTML]);
		}
	else if([rel isEqualToString:@"index"])
		{
		NSLog(@"<link>: %@", [self outerHTML]);
		}
	else if([rel isEqualToString:@"shortcut icon"])
		{
		NSLog(@"<link>: %@", [self outerHTML]);
		}
	else
		{
		NSLog(@"<link>: %@", [self outerHTML]);
		}
#endif
	[super _elementDidAwakeFromDocumentRepresentation:rep];
}

// WebDocumentRepresentation callbacks

- (void) setDataSource:(WebDataSource *) dataSource; { return; }

- (void) finishedLoadingWithDataSource:(WebDataSource *) source;
{
	NSString *rel=[[self valueForKey:@"rel"] lowercaseString];
#if 1
	NSLog(@"<link> finishedLoadingWithDataSource %@", source);
#endif
	if([rel isEqualToString:@"stylesheet"] && [[self valueForKey:@"type"] isEqualToString:@"text/css"])
		{ // did load style sheet
			NSString *style=[[NSString alloc] initWithData:[source data] encoding:NSUTF8StringEncoding];
			[sheet setHref:[[[source response] URL] absoluteString]];	// replace
			[sheet _setCssText:style];	// parse the style sheet to add
#if 1
			NSLog(@"CSS <link>: %@", sheet);
#endif
			[style release];
		}
}

- (void) receivedData:(NSData *) data withDataSource:(WebDataSource *) source;
{
	NSLog(@"%@ receivedData: %u", NSStringFromClass(isa), [[source data] length]);
}

- (void) receivedError:(NSError *) error withDataSource:(WebDataSource *) source;
{ // default error handler
	NSLog(@"%@ receivedError: %@", NSStringFromClass(isa), error);
}

@end

@implementation DOMHTMLStyleElement

// CHECKME: are style definitions "local"?

+ (DOMHTMLElement *) _designatedParentNode:(_WebHTMLDocumentRepresentation *) rep;
{
	return [rep _head];
}

- (void) _elementDidAwakeFromDocumentRepresentation:(_WebHTMLDocumentRepresentation *) rep;
{
	[[rep _parser] _setReadMode:1];	// switch parser mode to read up to </style>
	// checkme - can we say <style src="..."> or is this only done by <link>?
	// FIXME: ignore in <body> or set disabled
	[super _elementDidAwakeFromDocumentRepresentation:rep];
}

- (void) _elementLoaded;
{ // <style> element has been completely loaded, i.e. we are called from the </style> tag
	DOMHTMLDocument *htmlDocument=(DOMHTMLDocument *) [self ownerDocument];
	NSString *media=[self getAttribute:@"media"];
	// FIXME: ignore in <body> or set disabled
	sheet=[DOMCSSStyleSheet new];
	[[(DOMHTMLDocument *) [self ownerDocument] styleSheets] _addStyleSheet:sheet];	// add to list of style sheets
	[sheet setOwnerNode:self];
	if(media)
		[[sheet media] setMediaText:media];
#if 1	// WebKit does not set the href attribute (although it could/should?) - but we must have this link or a relative url in @import would not be found
	[sheet setHref:[[[[htmlDocument _webDataSource] response] URL] absoluteString]];	// should be the href of the current document so that @import with relative URL works
#endif
#if 1
	NSLog(@"parsing <style> element");
#endif
	[sheet _setCssText:[(DOMCharacterData *) [self firstChild] data]];	// parse the style sheet to add
#if 1
	NSLog(@"CSS: %@", sheet);
#endif
	[sheet release];
}

- (DOMCSSStyleSheet *) sheet; { return sheet; }	// allow to access from JS through var theSheet = document.getElementsByTagName('style')[0].sheet;

@end

@implementation DOMHTMLScriptElement

// FIXME: or should we use designatedParentNode; { return nil; } so that it is NOT even stored in DOM Tree?

- (void) _elementDidAwakeFromDocumentRepresentation:(_WebHTMLDocumentRepresentation *) rep;
{
	WebView *webView=[[self webFrame] webView];
	[[rep _parser] _setReadMode:1];	// switch parser mode to read up to </script>
	if([self hasAttribute:@"src"] && [[webView preferences] isJavaScriptEnabled])
		{ // we have an external script to load first
#if 0
			NSLog(@"load <script src=%@>", [self valueForKey:@"src"]);
#endif
			[self _loadSubresourceWithAttributeString:@"src" blocking:YES];	// trigger loading of script or get from cache - notifications will be tied to self, i.e. this instance of the <script element>
		}
	[super _elementDidAwakeFromDocumentRepresentation:rep];
}

- (void) _elementLoaded;
{ // <script> element has been completely loaded, i.e. we are called from the </script> tag
	NSString *type=[self valueForKey:@"type"];	// should be "text/javascript" or "application/javascript"
	NSString *lang=[[self valueForKey:@"lang"] lowercaseString];	// optional language "JavaScript" or "JavaScript1.2"
	NSString *script;
	WebView *webView=[[self webFrame] webView];
	if(![[webView preferences] isJavaScriptEnabled])
		return;	// ignore script
	if(![type isEqualToString:@"text/javascript"] && ![type isEqualToString:@"application/javascript"] && ![lang hasPrefix:@"javascript"])
		return;	// ignore if it is not javascript
	if([self hasAttribute:@"src"])
		{ // external script
			NSData *data=[self _loadSubresourceWithAttributeString:@"src" blocking:NO];		// if we are called, we know that it has been loaded - fetch from cache
			script=[[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
#if 0
			NSLog(@"external script: %@", script);
#endif
#if 0
			NSLog(@"raw: %@", data);
#endif
		}
	else
		script=[(DOMCharacterData *) [self firstChild] data];
	script=[script stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if(script)
		{ // not empty and not disabled
			if([script hasPrefix:@"<!--"])
				script=[script substringFromIndex:4];	// remove
			if([script hasSuffix:@"-->"])
				script=[script substringWithRange:NSMakeRange(0, [script length]-3)];	// remove
			// checkme: is it permitted to write <script><!CDATA[....? and how is that represented
			// YES: http://www.w3schools.com/xmL/xml_cdata.asp
			/*
			 Some text, like JavaScript code, contains a lot of "<" or "&" characters. To avoid errors script code can be defined as CDATA.
			 
			 Everything inside a CDATA section is ignored by the XML parser.
			 
			 A CDATA section starts with "<![CDATA[" and ends with "]]>":
			 
			 <script>
			 <![CDATA[
			 function matchwo(a,b)
			 {
			 if (a < b && a < 0) then
			 {
			 return 1;
			 }
			 else
			 {
			 return 0;
			 }
			 }
			 ]]>
			 </script>
			 */
#if 1
			{
			id r;
			NSLog(@"evaluate inlined <script>%@</script>", script);
			r=[[self ownerDocument] evaluateWebScript:script];	// try to parse and directly execute script in current document context
			NSLog(@"result=%@", r);
			}
#else
			[[self ownerDocument] evaluateWebScript:script];	// try to parse and directly execute script in current document context
#endif
		}
}

@end

@implementation DOMHTMLObjectElement

// use [WebView _webPluginForMIMEType] to get the plugin
// use _WebPluginContainerView to load and manage
// we should create an _WebPluginContainerView as a text attachment container

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLNoNesting; }

@end

@implementation DOMHTMLParamElement

@end

@implementation DOMHTMLFrameSetElement

// FIXME - lock if we have a <body> with children

+ (DOMHTMLElement *) _designatedParentNode:(_WebHTMLDocumentRepresentation *) rep;
{ // find matching <frameset> node or make child of <html>
	DOMHTMLElement *n=[rep _lastObject];
	while([n isKindOfClass:[DOMHTMLElement class]])
		{
		if([[n nodeName] isEqualToString:@"FRAMESET"] || [[n nodeName] isEqualToString:@"HTML"])
			return (DOMHTMLElement *) n;
		n=(DOMHTMLElement *)[n parentNode];	// go one level up
		}	// no <frameset> found!
	// well, this should never happen
	return [[[DOMHTMLElement alloc] _initWithName:@"#dummy" namespaceURI:nil] autorelease];	// return dummy
}

@end

@implementation DOMHTMLNoFramesElement

@end

@implementation DOMHTMLFrameElement

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLNoNesting; }

+ (DOMHTMLElement *) _designatedParentNode:(_WebHTMLDocumentRepresentation *) rep;
{ // find matching <frameset> node
	DOMHTMLElement *n=[rep _lastObject];
	while([n isKindOfClass:[DOMHTMLElement class]])
		{
		if([[n nodeName] isEqualToString:@"FRAMESET"])
			return (DOMHTMLElement *) n;
		n=(DOMHTMLElement *)[n parentNode];	// go one level up
		}	// no <frameset> found!
	return [[[DOMHTMLElement alloc] _initWithName:@"#dummy" namespaceURI:nil] autorelease];	// return dummy
}

@end

@implementation DOMHTMLIFrameElement

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLNoNesting; }

- (NSTextAttachment *) _attachment;
{
	return nil;	// should be a NSTextAttachmentCell which controls a NSTextView/NSWebFrameView that loads and renders its content
}

@end

@implementation DOMHTMLObjectFrameElement

+ (DOMHTMLElement *) _designatedParentNode:(_WebHTMLDocumentRepresentation *) rep;
{ // find matching <frameset> node
	DOMHTMLElement *n=[rep _lastObject];
	while([n isKindOfClass:[DOMHTMLElement class]])
		{
		if([[n nodeName] isEqualToString:@"FRAMESET"])
			return (DOMHTMLElement *) n;
		n=(DOMHTMLElement *)[n parentNode];	// go one level up
		}	// no <frameset> found!
	return [[[DOMHTMLElement alloc] _initWithName:@"#dummy" namespaceURI:nil] autorelease];	// return dummy
}

@end

@implementation DOMHTMLBodyElement

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLSingletonNesting; }

+ (DOMHTMLElement *) _designatedParentNode:(_WebHTMLDocumentRepresentation *) rep;
{
	return [rep _html];
}

#if 0
- (void) OLD_addAttributesToStyle:(DOMCSSStyleDeclaration *) style
{
	NSString *val;
	val=[self valueForKey:@"text"];
	if(val)
		[style setProperty:@"color" value:val priority:nil];
	val=[self valueForKey:@"bgcolor"];
	if(val)
		[style setProperty:@"background-color" value:val priority:nil];
	val=[self valueForKey:@"background"];
	if(val)
		[style setProperty:@"background-image" value:[NSString stringWithFormat:@"url(\"%@\")", val] priority:nil];
	val=[self valueForKey:@"link"];
	if(val)
		; // set implicit color for links, i.e. define a a:link pseudo entry???
	// FIXME: handle other background attributes
}
#endif

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
				// so we should accept dots but only if they separate at least two digits...
				// but don't recognize dates like 29.12.2007
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
#if 0
								NSLog(@"found telephone number: %@", number);
#endif
								// preprocess number so that it fits into E.164 and DIN 5008 formats
								// how do we handle if someone writes +49 (0) 89 - we must remove the 0?
								if([number hasPrefix:@"00"])
									number=[NSString stringWithFormat:@"+%@", [number substringFromIndex:2]];	// convert to international format
#if 0
								NSLog(@"  -> %@", number);
#endif
								[str setAttributes:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"tel:%@", number]
																			   forKey:NSLinkAttributeName] range:srng];	// add link
								continue;
							}
					}
			}
		[sc setScanLocation:start+1];	// skip anything else
		}
}

@end

@implementation DOMHTMLDivElement

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLLazyNesting; }

@end

@implementation DOMHTMLSpanElement

@end

@implementation DOMHTMLCenterElement

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLLazyNesting; }

@end

@implementation DOMHTMLHeadingElement

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLLazyNesting; }

#if OLD
- (void) OLD_addAttributesToStyle:(DOMCSSStyleDeclaration *) style;
{ // add attributes to style
	int level=[[[self nodeName] substringFromIndex:1] intValue];
	NSString *align=[self valueForKey:@"align"];
	if(align) [style setProperty:@"text-align" value:align priority:nil];
	[style setProperty:@"x-header-level" value:[NSString stringWithFormat:@"%d", level] priority:nil];
	if(level == 1)
		[style setProperty:@"font-size" value:@"xx-large" priority:nil];	// 12 -> 24
	else if(level == 2)
		[style setProperty:@"font-size" value:@"x-large" priority:nil];	// 12 -> 18
	else if(level == 3)
		[style setProperty:@"font-size" value:@"large" priority:nil];		// 12 -> 14
	// height passend setzen?
	[style setProperty:@"display" value:@"block" priority:nil];
}
#endif

@end

@implementation DOMHTMLPreElement

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLLazyNesting; }

@end

@implementation DOMHTMLFontElement

- (void) OLD_addAttributesToStyle:(DOMCSSStyleDeclaration *) style;
{ // add attributes to style
	NSString *val;
#if OLD
	val=[self valueForKey:@"face"];
	if(val)
		[style setProperty:@"font-family" value:val priority:nil];	// may be a comma separated list
#endif
	val=[self valueForKey:@"size"];
	if(val)
		{ // FIXME: handle through default.css
		if([val hasPrefix:@"+"])
			{ // enlarge by 1.2 for each step
				float s=[[val substringFromIndex:1] floatValue];
				[style setProperty:@"font-size" value:[NSString stringWithFormat:@"%.0f%%", 100.0*pow(1.2, s)] priority:nil];
			}
		else if([val hasPrefix:@"-"])
			{ // reduce by 1.2 for each step
				float s=[[val substringFromIndex:1] floatValue];
				[style setProperty:@"font-size" value:[NSString stringWithFormat:@"%.0f%%", 100.0*pow(1.2, -s)] priority:nil];
			}
		else
			{ // absolute size relative to 12 pnt
				WebView *webView=[[self webFrame] webView];
				float s=[val intValue];
				if(s > 7) s=7;	// limit
				if(s < 1) s=1;	// limit
				s=12.0*pow(1.2, s);
				[style setProperty:@"font-size" value:[NSString stringWithFormat:@"%.2g pt", s] priority:nil];
			}
		}
#if OLD
	val=[self valueForKey:@"color"];
	if(val)
		[style setProperty:@"color" value:val priority:nil];
#endif
}

@end

@implementation DOMHTMLAnchorElement

- (void) _elementDidAwakeFromDocumentRepresentation:(_WebHTMLDocumentRepresentation *) rep;
{
	NSString *urlString=[self valueForKey:@"href"];
	if(urlString)	// link
		[[(DOMHTMLDocument *) [self ownerDocument] links] appendChild:self];	// add to Links[] DOM Level 0 list
	else	// anchor
		[[(DOMHTMLDocument *) [self ownerDocument] anchors] appendChild:self];	// add to Anchors[] DOM Level 0 list
}

#if 0
- (void) OLD_addAttributesToStyle:(DOMCSSStyleDeclaration *) style;
{ // add attributes to style
	NSString *urlString=[self valueForKey:@"href"];
	NSString *target=[self valueForKey:@"target"];	// WebFrame name where to show
	NSString *name=[self valueForKey:@"name"];
	NSString *charset=[self valueForKey:@"charset"];
	NSString *accesskey=[self valueForKey:@"accesskey"];
	NSString *shape=[self valueForKey:@"shape"];
	NSString *coords=[self valueForKey:@"coords"];
	if(urlString)
		{ // add a hyperlink
			[style setProperty:@"x-link" value:urlString priority:nil];
			[style setProperty:@"x-tooltip" value:urlString priority:nil];
			[style setProperty:@"cursor" value:@"pointer" priority:nil];
			if(target)
				[style setProperty:@"x-target-window" value:target priority:nil];	// set the target window
		}
	if(!name)
		name=[self valueForKey:@"id"];	// XHTML alternative
	if(name)
		[style setProperty:@"x-anchor" value:name priority:nil];	// add an anchor
}
#endif

@end

@implementation DOMHTMLImageElement

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLNoNesting; }

- (void) _elementDidAwakeFromDocumentRepresentation:(_WebHTMLDocumentRepresentation *) rep;
{
	[[(DOMHTMLDocument *) [self ownerDocument] images] appendChild:self];	// add to Images[] DOM Level 0 list
	[super _elementDidAwakeFromDocumentRepresentation:rep];
}

#if 0
- (void) OLD_addAttributesToStyle:(DOMCSSStyleDeclaration *) style;
{ // add attributes to style
	NSString *height=[self valueForKey:@"height"];
	NSString *width=[self valueForKey:@"width"];
	NSString *urlString=[self valueForKey:@"src"];	// relative links will be expanded when clicking on the link
	if(urlString /* && ![_style objectForKey:@"x-link"] */)
		{ // add a hyperlink with the image source (unless we are embedded within a link)
// FIXME:			[_style setObject:urlString forKey:@"x-link"];	// set the link
			[style setProperty:@"cursor" value:@"pointer" priority:nil];
		}
	// FIXME: there is a difference between width=100 and style={ width: 100px }
	// in the first case the height is defined by the source file, while in the second case the image is scaled proportionally
	if(width)
		[style setProperty:@"width" value:[width stringByAppendingString:@" px"] priority:nil];	// should be in Pixels
	if(height)
		[style setProperty:@"height" value:[height stringByAppendingString:@" px"] priority:nil];
	if(urlString)
		// FIXME: we should get rid of this string processing!!!
		[style setProperty:@"content" value:[NSString stringWithFormat:@"url(\"%@\")", urlString] priority:nil];
}
#endif

- (NSString *) string;
{ // if attachment can't be created
	return [self valueForKey:@"alt"];
}

- (NSTextAttachment *) _attachment;
{
	WebView *webView=[[self webFrame] webView];
	NSTextAttachment *attachment;
	NSCell *cell;
	NSImage *image=nil;
	NSFileWrapper *wrapper;
	NSString *src=[self valueForKey:@"src"];
	NSString *alt=[self valueForKey:@"alt"];
	NSString *height=[self valueForKey:@"height"];
	NSString *width=[self valueForKey:@"width"];
	NSString *border=[self valueForKey:@"border"];
	NSString *hspace=[self valueForKey:@"hspace"];
	NSString *vspace=[self valueForKey:@"vspace"];
	NSString *usemap=[self valueForKey:@"usemap"];
	NSString *name=[self valueForKey:@"name"];
	BOOL hasmap=[self hasAttribute:@"ismap"];
#if 0
	NSLog(@"<img>: %@", [self _attributes]);
#endif
	if(!src)
		return nil;	// can't show as attachment
	attachment=[NSTextAttachmentCell textAttachmentWithCellOfClass:[NSActionCell class]];
	cell=(NSCell *) [attachment attachmentCell];	// get the real cell
#if 0
	NSLog(@"cell attachment: %@", [cell attachment]);
#endif
	[cell setTarget:self];
	[cell setAction:@selector(_imgAction:)];
	if([[webView preferences] loadsImagesAutomatically])
		{
		NSData *data=[self _loadSubresourceWithAttributeString:@"src" blocking:NO];	// get from cache or trigger loading (makes us the WebDocumentRepresentation)
		[self retain];	// FIXME: if we can cancel the load we don't need to keep us alive until the data source is done
		if(data)
			{ // we got some or all
				image=[[NSImage alloc] initWithData:data];	// try to get as far as we can
				[image setScalesWhenResized:YES];
			}
		}
	if(!image)
		{ // could not convert
			image=[[NSImage alloc] initWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"WebKitIMG" ofType:@"png"]];	// substitute default image
			[image setScalesWhenResized:NO];	// hm... does not really work
		}
	// take CSS width & height!
	if(width || height) // resize image
		[image setSize:NSMakeSize([width floatValue], [height floatValue])];	// or intValue?
	[cell setImage:image];	// set image
	[image release];
#if 0
	NSLog(@"attachmentCell=%@", [attachment attachmentCell]);
	NSLog(@"[attachmentCell attachment]=%@", [[attachment attachmentCell] attachment]);
	NSLog(@"[attachmentCell image]=%@", [(NSCell *) [attachment attachmentCell] image]);	// maybe, we can apply sizing...
#endif
	// we can also overlay the text attachment with the URL as a link
	return attachment;
}

// WebDocumentRepresentation callbacks (source is the subresource)

- (void) setDataSource:(WebDataSource *) dataSource; { return; }

- (void) finishedLoadingWithDataSource:(WebDataSource *) source; { [self release]; return; }

- (void) receivedData:(NSData *) data withDataSource:(WebDataSource *) source;
{ // simply ask our NSTextView for a re-layout
	NSLog(@"%@ receivedData: %u", NSStringFromClass(isa), [[source data] length]);
	[[self _visualRepresentation] setNeedsLayout:YES];
	[(NSView *) [self _visualRepresentation] setNeedsDisplay:YES];
}

- (void) receivedError:(NSError *) error withDataSource:(WebDataSource *) source;
{ // default error handler
	NSLog(@"%@ receivedError: %@", NSStringFromClass(isa), error);
}

- (IBAction) _imgAction:(id) sender;
{
	// make image load in separate window
	// we can also set the link attribute with the URL for the text attachment
	// how do we handle images within frames?
}

- (void) dealloc
{ // cancel subresource loading
	// FIXME
	[super dealloc];
}

@end

@implementation DOMHTMLBRElement

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLNoNesting; }

#if 0
// FIXME: this will be eliminated unless we set "white-space"

- (NSString *) _string; { return @"\n"; }	// add line break
#endif

@end

@implementation DOMHTMLParagraphElement

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLLazyNesting; }

@end

@implementation DOMHTMLHRElement

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLNoNesting; }

- (NSTextAttachment *) _attachment;
{
    NSTextAttachment *att;
    NSHRAttachmentCell *cell;
    int size;
    
    att = [NSTextAttachmentCell textAttachmentWithCellOfClass:[NSHRAttachmentCell class]];
    cell=(NSHRAttachmentCell *) [att attachmentCell];        // get the real cell
	
	[cell setShaded:![self hasAttribute:@"noshade"]];
	size = [[self valueForKey:@"size"] intValue];
#if 1  
	NSLog(@"<hr> size: %@", [self valueForKey:@"size"]);
    NSLog(@"<hr> width: %@", [self valueForKey:@"width"]);
#endif
    return att;
}

@end

@implementation NSTextBlock (Attributes)

// FIXME to use CSS attributes only!

- (void) _setTextBlockAttributes:(DOMHTMLElement *) element	paragraph:(NSMutableParagraphStyle *) paragraph
{ // apply style attributes to NSTextBlock or NSTextTable and the paragraph
	NSString *background=[element valueForKey:@"background"];
	NSString *bg=[element valueForKey:@"bgcolor"];
	unsigned border=[[element valueForKey:@"border"] intValue];
	unsigned spacing=[[element valueForKey:@"selfspacing"] intValue];
	unsigned padding=[[element valueForKey:@"selfpadding"] intValue];
	NSString *valign=[[element valueForKey:@"valign"] lowercaseString];
	NSString *width=[element valueForKey:@"width"];	// cell width in pixels or % of <table>
	NSString *align=[[element valueForKey:@"align"] lowercaseString];
	NSString *alignchar=[element valueForKey:@"char"];
	NSString *offset=[element valueForKey:@"charoff"];
	NSString *axis=[element valueForKey:@"axis"];
	BOOL isTable=[element isKindOfClass:[DOMHTMLTableElement class]];	// handle defaults
	if(!isTable && [element parentNode])
		[self _setTextBlockAttributes:(DOMHTMLElement *) [element parentNode] paragraph:paragraph];	// inherit from parent node(s)
	
	// FIXME: move this to _spliceTo: general handler
	
	if([align isEqualToString:@"left"])
		[paragraph setAlignment:NSLeftTextAlignment];
	else if([align isEqualToString:@"center"])
		[paragraph setAlignment:NSCenterTextAlignment];
	else if([align isEqualToString:@"right"])
		[paragraph setAlignment:NSRightTextAlignment];
	else if([align isEqualToString:@"justify"])
		[paragraph setAlignment:NSJustifiedTextAlignment];
	//			 if([align isEqualToString:@"char"])
	//				 [paragraph setAlignment:NSNaturalTextAlignment];
	if(background)
		{
		}
	if(bg)
		[self setBackgroundColor:[bg _htmlColor]];
	[self setBorderColor:[NSColor blackColor]];
	// here we could use black and grey color for different borders
	if([element valueForKey:@"border"])
		{ // not inherited
			if(border < 1) border=1;
			[self setWidth:border type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockBorder];	// border width
		}
	if(isTable || [element valueForKey:@"selfspacing"])
		{ // root or overwritten
			if(spacing < 1) spacing=1;
			[self setWidth:spacing type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockMargin];	// margin between selfs
		}
	if(isTable || [element valueForKey:@"selfpadding"])
		{ // root or overwritten
			if(padding < 1) padding=1;
			[self setWidth:padding type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockPadding];	// space between border and text
		}
	if([valign isEqualToString:@"top"])
		[self setVerticalAlignment:NSTextBlockTopAlignment];
	else if([valign isEqualToString:@"middle"])
		[self setVerticalAlignment:NSTextBlockMiddleAlignment];
	else if([valign isEqualToString:@"bottom"])
		[self setVerticalAlignment:NSTextBlockBottomAlignment];
	else if([valign isEqualToString:@"baseline"])
		[self setVerticalAlignment:NSTextBlockBaselineAlignment];
	else if(isTable)
		[self setVerticalAlignment:NSTextBlockMiddleAlignment];	// default
	if(width)
		{
		NSScanner *sc=[NSScanner scannerWithString:width];
		double val;
		if([sc scanDouble:&val])
			{
			NSTextBlockValueType type=[sc scanString:@"%" intoString:NULL]?NSTextBlockPercentageValueType:NSTextBlockAbsoluteValueType;
			[self setValue:20 type:NSTextBlockAbsoluteValueType forDimension:NSTextBlockMinimumWidth];
			[self setValue:val type:type forDimension:NSTextBlockWidth];
			[self setValue:50 type:NSTextBlockAbsoluteValueType forDimension:NSTextBlockMaximumWidth];
			}
		}
}

@end

@implementation DOMHTMLTableElement

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLLazyNesting; }

- (void) dealloc;
{
	[table release];
	[rows release];
	[super dealloc];
}

#if 0
- (void) OLD_addAttributesToStyle:(DOMCSSStyleDeclaration *) style;
{ // add attributes to style
	NSMutableParagraphStyle *paragraph=[[_style objectForKey:NSParagraphStyleAttributeName] mutableCopy];
	unsigned cols=[[self valueForKey:@"cols"] intValue];
#if 0
	NSLog(@"<table>: %@", [self _attributes]);
#endif
	table=[[NSClassFromString(@"NSTextTable") alloc] init];
	[table setHidesEmptyCells:YES];
	[table setNumberOfColumns:cols];	// will be increased automatically as needed!
	[table _setTextBlockAttributes:self paragraph:paragraph];
	// should use a different method - e.g. store the NSTextTable in an iVar and search us from the siblings
	// should reset to default paragraph
	// should reset font style, color etc. to defaults!
	[_style setObject:@"table" forKey:@"display"];	// a table is a block element, i.e. force a \n before table starts
	[_style setObject:paragraph forKey:NSParagraphStyleAttributeName];
	[paragraph release];
#if 0
	NSLog(@"<table> _style=%@", _style);
#endif
}
#endif

- (NSTextTable *) _getRow:(int *) row andColumn:(int *) col rowSpan:(int *) rowspan colSpan:(int *) colspan forCell:(DOMHTMLTableCellElement *) cell
{
	// algorithm could cache the current cell and start over only if it is not called for the next one
	// since it will most probably be called in correct sequence
	DOMNodeList *l=[self getElementsByTagName:@"TBODY"];
	NSCountedSet *rowSpanTracking=[[NSCountedSet new] autorelease];	// counts the (additional) rows to span for each column (of type NSNumber)
	*row=1;
	*col=1;
	*rowspan=0;
	*colspan=0;
	if([l length] > 0)
		{
		DOMHTMLTBodyElement *body=(DOMHTMLTBodyElement *)[l item:0];
		NSEnumerator *re;
		DOMHTMLTableRowElement *r;
		re=[[[body childNodes] _list] objectEnumerator];
		while((r=[re nextObject]))
			{ // check in which <tr> we are child
				NSEnumerator *ce;
				DOMHTMLTableCellElement *c;
				int i;
				if(![r isKindOfClass:[DOMHTMLTableRowElement class]])
					continue;
				ce=[[[r childNodes] _list] objectEnumerator];
				while((c=[ce nextObject]))
					{
					if(![c isKindOfClass:[DOMHTMLTableCellElement class]])
						continue;
					while(([rowSpanTracking countForObject:[NSNumber numberWithInt:*col]] > 0))
						(*col)++;	// skip
					*rowspan=[[c valueForKey:@"rowspan"] intValue];
					*colspan=[[c valueForKey:@"colspan"] intValue];
					if((*colspan) > ([table numberOfColumns]-(*col-1)))
						*colspan=[table numberOfColumns]-(*col-1);	// limit (default mechanism will add at least one!)
					if(*colspan < 1) *colspan=1;	// default
					if(*rowspan < 1) *rowspan=1;	// default
					if(cell == c)
						return table;	// found!
					while(*colspan >= 1)
						{
						for(i=0; i<*rowspan; i++)
							[rowSpanTracking addObject:[NSNumber numberWithInt:*col]];	// extend rowspan set
						(*col)++;
						(*colspan)--;
						}
					}
				(*row)++;
				for(i=1; i<[table numberOfColumns]; i++)
					[rowSpanTracking removeObject:[NSNumber numberWithInt:i]];	// remove one count per column number
				*col=1;
			}
		}
	return nil;
}

@end

@implementation DOMHTMLTBodyElement

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLSingletonNesting; }

// FIXME: there may be <table><div style...><tbody>

+ (DOMHTMLElement *) _designatedParentNode:(_WebHTMLDocumentRepresentation *) rep;
{ // find matching <table> node
	DOMHTMLElement *n=[rep _lastObject];
	while(n && ![n isKindOfClass:[DOMHTMLTableElement class]])
		n=(DOMHTMLElement *)[n parentNode];	// go one level up
	if(n)
		return n;	// found
	return [[[DOMHTMLElement alloc] _initWithName:@"#dummy#tbody" namespaceURI:nil] autorelease];	// no <table> found! return dummy table
}

@end

@implementation DOMHTMLTableRowElement

// FIXME: there may be <table><div style...><tr>

+ (DOMHTMLElement *) _designatedParentNode:(_WebHTMLDocumentRepresentation *) rep;
{ // find matching <tbody> or <table> node to become child
	DOMHTMLElement *n=[rep _lastObject];
	while([n isKindOfClass:[DOMHTMLElement class]])
		{
		if([[n nodeName] isEqualToString:@"TBODY"])
			return n;	// found
		if([[n nodeName] isEqualToString:@"TABLE"])
			{ // find <tbody> and create a new if there isn't one
				NSEnumerator *list=[[[n childNodes] _list] objectEnumerator];
				DOMHTMLTBodyElement *tbe;
				while((tbe=[list nextObject]))
					{
					if([[tbe nodeName] isEqualToString:@"TBODY"])
						return tbe;	// found!
					}
				tbe=[[DOMHTMLTBodyElement alloc] _initWithName:@"TBODY" namespaceURI:nil];	// create new <tbody>
				[n appendChild:tbe];	// insert a fresh <tbody> element
				[tbe release];
				return tbe;
			}
		n=(DOMHTMLElement *)[n parentNode];	// go one level up
		}	// no <table> found!
	return [[[DOMHTMLElement alloc] _initWithName:@"#dummy#tr" namespaceURI:nil] autorelease];	// return dummy
}

- (void) _elementDidAwakeFromDocumentRepresentation:(_WebHTMLDocumentRepresentation *) rep;
{
	// add to rows collection of table so that we can handle row numbers correctly
	[super _elementDidAwakeFromDocumentRepresentation:rep];
}

@end

@implementation DOMHTMLTableCellElement

// FIXME: shouldn't this be processed during _layout?

#if 0

- (void) OLD_addAttributesToStyle;
{ // add attributes to style
	NSMutableParagraphStyle *paragraph=[[_style objectForKey:NSParagraphStyleAttributeName] mutableCopy];
	NSMutableArray *blocks;
	NSTextTableBlock *cell;
	DOMHTMLTableElement *tableElement;
	NSTextTable *table;	// the table we belong to
	int row, col;
	int rowspan, colspan;
	tableElement=(DOMHTMLTableElement *) self;
	while(tableElement && ![tableElement isKindOfClass:[DOMHTMLTableElement class]])
		tableElement=(DOMHTMLTableElement *)[tableElement parentNode];	// go one level up
	table=[tableElement _getRow:&row andColumn:&col rowSpan:&rowspan colSpan:&colspan forCell:self];	// ask tableElement for our position
	if(!table)
		{ // we are not within a table
			[paragraph release];
			return;	// error...
		}
	if(col+colspan-1 > [table numberOfColumns])
		[table setNumberOfColumns:col+colspan-1];			// adjust number of columns of our enclosing table
	cell=[[NSClassFromString(@"NSTextTableBlock") alloc] initWithTable:table
														   startingRow:row
															   rowSpan:rowspan
														startingColumn:col
															columnSpan:colspan];
	[(NSTextBlock *) cell _setTextBlockAttributes:self paragraph:paragraph];
	if([[self nodeName] isEqualToString:@"TH"])
		{ // make centered and bold paragraph for header cells
			NSFont *f=[_style objectForKey:NSFontAttributeName];	// get current font
			f=[[NSFontManager sharedFontManager] convertFont:f toHaveTrait:NSBoldFontMask];
			if(f) [_style setObject:f forKey:NSFontAttributeName];
			[paragraph setAlignment:NSCenterTextAlignment];	// modify alignment
		}
	blocks=(NSMutableArray *) [paragraph textBlocks];	// the text blocks
	if(!blocks)	// didn't inherit text blocks (i.e. outermost table)
		blocks=[[NSMutableArray alloc] initWithCapacity:2];	// rarely needs more nesting
	else
		blocks=[blocks mutableCopy];
	[blocks addObject:cell];	// add to list of text blocks
	[paragraph setTextBlocks:blocks];	// add to paragraph style
	[cell release];
	[blocks release];	// was either mutableCopy or alloc/initWithCapacity
#if 0
	NSLog(@"<td> _style=%@", _style);
#endif
	[_style setObject:paragraph forKey:NSParagraphStyleAttributeName];
	[paragraph release];
}
#endif

@end

@implementation DOMHTMLFormElement

- (id) init
{
	if((self = [super init]))
		{
		elements=[DOMHTMLCollection new]; 
		}
	return self;
}

- (void) dealloc
{
	[elements release];
	[super dealloc];
}

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLStandardNesting; }

- (void) _elementDidAwakeFromDocumentRepresentation:(_WebHTMLDocumentRepresentation *) rep;
{
	[[(DOMHTMLDocument *) [self ownerDocument] forms] appendChild:self];	// add to Forms[] DOM Level 0 list
	[super _elementDidAwakeFromDocumentRepresentation:rep];
}

- (DOMHTMLCollection *) elements { return elements; }

- (void) _submitForm:(DOMHTMLElement *) clickedElement;
{ // post current request
	NSMutableURLRequest *request;
	DOMHTMLDocument *htmlDocument;
	NSString *action;
	NSString *method;
	NSString *target;
	NSMutableString *r;
	NSEnumerator *e;
	DOMHTMLElement *element;
	BOOL post;
	[self _triggerEvent:@"onsubmit"];
	// can the trigger abort sending the form? Through an exception?
	htmlDocument=(DOMHTMLDocument *) [self ownerDocument];	// may have been changed by the onsubmit script
	action=[self valueForKey:@"action"];
	method=[self valueForKey:@"method"];
	target=[self valueForKey:@"target"];
	if(!action)
		action=@"";	// we simply reuse the current - FIXME: we should remove all ? components
#if 1
	NSLog(@"method = %@", method);
#endif
	post=(method && [method caseInsensitiveCompare:@"post"] == NSOrderedSame);
	r=[NSMutableString stringWithCapacity:100];
	e=[[elements valueForKey:@"elements"] objectEnumerator];
	while((element=[e nextObject]))
		{
		NSString *name;
		NSString *val=[(DOMHTMLInputElement *) element _formValue];	// should be [element valueForKey:@"value"]; but then we need to handle active elements here
		// but we may need anyway since a <input type="file"> defines more than one variable!
		NSMutableArray *a;
		NSEnumerator *e;
		NSMutableString *s;
		if(!val)
			continue;
		name=[element valueForKey:@"name"];
		if(!name)
			continue;
		a=[[NSMutableArray alloc] initWithCapacity:10];
		e=[[val componentsSeparatedByString:@"+"] objectEnumerator];
		while((s=[e nextObject]))
			{ // URL-Encode components
#if 1
				NSLog(@"percent-escaping: %@ -> %@", s, [s stringByAddingPercentEscapesUsingEncoding:NSISOLatin1StringEncoding]);
#endif
				s=[[s stringByAddingPercentEscapesUsingEncoding:NSISOLatin1StringEncoding] mutableCopy];
				[s replaceOccurrencesOfString:@" " withString:@"+" options:0 range:NSMakeRange(0, [s length])];
				// CHECKME: which of these are already converted by stringByAddingPercentEscapesUsingEncoding?
				[s replaceOccurrencesOfString:@"&" withString:@"%26" options:0 range:NSMakeRange(0, [s length])];
				[s replaceOccurrencesOfString:@"?" withString:@"%3F" options:0 range:NSMakeRange(0, [s length])];
				[s replaceOccurrencesOfString:@"-" withString:@"%3D" options:0 range:NSMakeRange(0, [s length])];
				[s replaceOccurrencesOfString:@";" withString:@"%3B" options:0 range:NSMakeRange(0, [s length])];
				[s replaceOccurrencesOfString:@"," withString:@"%2C" options:0 range:NSMakeRange(0, [s length])];
				[a addObject:s];
				[s release];										
			}
		val=[a componentsJoinedByString:@"%2B"];
		[a release];
		[r appendFormat:[r length] > 0?@"&%@=%@":@"%@=%@", name, val];	// separate by &
		}
	if(!post && [r length] > 0)
		{
#if 1
		NSLog(@"getURL = %@", r);
#endif
		action=[action stringByAppendingFormat:@"?%@", r];
#if 1
		NSLog(@"action = %@", action);
#endif
		// FIXME: remove any existing ?query part and replace
		}
	request=(NSMutableURLRequest *)[NSMutableURLRequest requestWithURL:[NSURL URLWithString:action relativeToURL:[[[htmlDocument _webDataSource] response] URL]]];
	if(method)
		[request setHTTPMethod:[method uppercaseString]];	// will default to "GET" if missing
	if(post)
		{
#if 1
		NSLog(@"post = %@", [r dataUsingEncoding:NSUTF8StringEncoding]);
#endif
		[request setHTTPBody:[r dataUsingEncoding:NSUTF8StringEncoding]];
		}
#if 1
	NSLog(@"submit <form> to %@ using method %@", [request URL], [request HTTPMethod]);
#endif
	[request setMainDocumentURL:[[[htmlDocument _webDataSource] request] URL]];
	[[self webFrame] loadRequest:request];	// and submit the request
}

@end

@implementation DOMHTMLInputElement

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLNoNesting; }

- (void) _elementDidAwakeFromDocumentRepresentation:(_WebHTMLDocumentRepresentation *) rep;
{
	form=[self valueForKeyPath:@"ownerDocument.forms.lastChild"];	// add to last form we have seen
	//	form=(DOMHTMLFormElement *) [[(DOMHTMLDocument *) [self ownerDocument] forms] lastChild];
	// Objc-2.0? self.ownerDocument.forms.elements.appendChild=self
#if 1
	NSLog(@"<input>: form=%@", form);
#endif
	[[form elements] appendChild:self];
	[super _elementDidAwakeFromDocumentRepresentation:rep];
}

- (NSTextAttachment *) _attachment;
{
	NSTextAttachment *attachment;
	NSString *type=[[self valueForKey:@"type"] lowercaseString];
	NSString *name=[self valueForKey:@"name"];
	// FIXME:	NSString *val=[self valueForKey:@"value"];   <-- returns e.g. INPUT: WHY???
	NSString *val=[self getAttribute:@"value"];
	NSString *title=[self valueForKey:@"title"];
	NSString *placeholder=[self valueForKey:@"placeholder"];
	NSString *size=[self valueForKey:@"size"];
	NSString *maxlen=[self valueForKey:@"maxlength"];
	NSString *results=[self valueForKey:@"results"];
	NSString *autosave=[self valueForKey:@"autosave"];
	NSString *align=[self valueForKey:@"align"];
	if([type isEqualToString:@"hidden"])
		{ // ignore for rendering purposes - will be collected when sending the <form>
			return nil;
		}
#if 1
	NSLog(@"<input>: %@", [self attributes]);
#endif
	if([type isEqualToString:@"submit"] || [type isEqualToString:@"reset"] ||
	   [type isEqualToString:@"checkbox"] || [type isEqualToString:@"radio"] ||
	   [type isEqualToString:@"button"])
		attachment=[NSTextAttachmentCell textAttachmentWithCellOfClass:[NSButtonCell class]];
	else if([type isEqualToString:@"search"])
		attachment=[NSTextAttachmentCell textAttachmentWithCellOfClass:[NSSearchFieldCell class]];
	else if([type isEqualToString:@"password"])
		attachment=[NSTextAttachmentCell textAttachmentWithCellOfClass:[NSSecureTextFieldCell class]];
	else if([type isEqualToString:@"file"])
		attachment=[NSTextAttachmentCell textAttachmentWithCellOfClass:[NSTextFieldCell class]];
	else if([type isEqualToString:@"image"])
		attachment=[NSTextAttachmentCell textAttachmentWithCellOfClass:[NSActionCell class]];
	else
		attachment=[NSTextAttachmentCell textAttachmentWithCellOfClass:[NSTextFieldCell class]];
	cell=(NSCell *) [attachment attachmentCell];	// get the real cell
	[(NSActionCell *) cell setTarget:self];
	[(NSActionCell *) cell setAction:@selector(_submit:)];	// default action
	[cell setEditable:!([self hasAttribute:@"disabled"] || [self hasAttribute:@"readonly"])];
	if([cell isKindOfClass:[NSTextFieldCell class]])
		{ // set text field, placeholder etc.
			[(NSTextFieldCell *) cell setSelectable:YES];
			[(NSTextFieldCell *) cell setBezeled:YES];
			[(NSTextFieldCell *) cell setStringValue: (val != nil) ? val : (NSString *)@""];
			// how to handle the size attribute?
			// an NSCell has no inherent size
			// should we pad the placeholder string?
			if([cell respondsToSelector:@selector(setPlaceholderString:)])
				[(NSTextFieldCell *) cell setPlaceholderString:placeholder];
		}
	else if([cell isKindOfClass:[NSButtonCell class]])
		{ // button
			[(NSButtonCell *) cell setButtonType:NSMomentaryLightButton];
			[(NSButtonCell *) cell setBezelStyle:NSRoundedBezelStyle];
			if([type isEqualToString:@"submit"])
				[(NSButtonCell *) cell setTitle:val?val: (NSString *)@"Submit"];	// FIXME: Localization!
			else if([type isEqualToString:@"reset"])
				{
				[(NSButtonCell *) cell setTitle:val?val: (NSString *)@"Reset"];
				[(NSActionCell *) cell setAction:@selector(_reset:)];
				}
			else if([type isEqualToString:@"checkbox"])
				{
				[(NSButtonCell *) cell setState:[self hasAttribute:@"checked"]];
				[(NSButtonCell *) cell setButtonType:NSSwitchButton];
				[(NSButtonCell *) cell setTitle:@""];
				[(NSActionCell *) cell setAction:@selector(_checkbox:)];
				}
			else if([type isEqualToString:@"radio"])
				{
				[(NSButtonCell *) cell setState:[self hasAttribute:@"checked"]];
				[(NSButtonCell *) cell setButtonType:NSRadioButton];
				[(NSButtonCell *) cell setTitle:@""];
				[(NSActionCell *) cell setAction:@selector(_radio:)];
				}
			else
				[(NSButtonCell *) cell setTitle:val?val:(NSString *)@"Button"];
		}
	else if([type isEqualToString:@"file"])
		// FIXME
		;
	else if([type isEqualToString:@"image"])
		{
		WebView *webView=[[self webFrame] webView];
		NSImage *image=nil;
		NSString *height=[self valueForKey:@"height"];
		NSString *width=[self valueForKey:@"width"];
		NSString *border=[self valueForKey:@"border"];
		NSString *src=[self valueForKey:@"border"];
#if 0
		NSLog(@"cell attachment: %@", [cell attachment]);
#endif
		if([[webView preferences] loadsImagesAutomatically])
			{
			NSData *data=[self _loadSubresourceWithAttributeString:@"src" blocking:NO];	// get from cache or trigger loading (makes us the WebDocumentRepresentation)
			[self retain];	// FIXME: if we can cancel the load we don't need to keep us alive until the data source is done
			if(data)
				{ // we got some or all
					image=[[NSImage alloc] initWithData:data];	// try to get as far as we can
					[image setScalesWhenResized:YES];
				}
			}
		if(!image)
			{ // could not convert
				image=[[NSImage alloc] initWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"WebKitIMG" ofType:@"png"]];	// substitute default image
				[image setScalesWhenResized:NO];	// hm... does not really work
			}
		if(width || height) // resize image
			[image setSize:NSMakeSize([width floatValue], [height floatValue])];	// or intValue?
		[cell setImage:image];	// set image
		[image release];
#if 1
		NSLog(@"attachmentCell=%@", [attachment attachmentCell]);
		NSLog(@"[attachmentCell attachment]=%@", [[attachment attachmentCell] attachment]);
		NSLog(@"[attachmentCell image]=%@", [(NSCell *) [attachment attachmentCell] image]);	// maybe, we can apply sizing...
			NSLog(@"[attachmentCell target]=%@", [[attachment attachmentCell] target]);
			NSLog(@"[attachmentCell controlView]=%@", [[attachment attachmentCell] controlView]);
#endif
		}
#if 1
	NSLog(@"  cell: %@", cell);
	NSLog(@"  cell control view: %@", [cell controlView]);
//	NSLog(@"  _style: %@", _style);
#endif
	return attachment;
}

- (void) _submit:(id) sender
{ // forward to <form> so that it can handle
	[self _triggerEvent:@"onclick"];
	[form _submitForm:self];
}

- (void) _reset:(id) sender;
{ // does not _submitForm form
	[self _triggerEvent:@"onclick"];
	[[form elements] _makeObjectsPerformSelector:@selector(_resetForm:) withObject:nil];
}

- (void) _checkbox:(id) sender;
{ // does not _submitForm form
	[self _triggerEvent:@"onclick"];
}

- (void) _resetForm:(DOMHTMLElement *) ignored;
{
	NSString *type=[[self valueForKey:@"type"] lowercaseString];
	if([type isEqualToString:@"checkbox"])
		[cell setState:NSOffState];
	else if([type isEqualToString:@"radio"])
		[cell setState:[self hasAttribute:@"checked"]];	// reset to default
	else
		[cell setStringValue:@""];	// clear string
}

- (void) _radio:(id) sender;
{
	[self _triggerEvent:@"onclick"];
	[[form elements] _makeObjectsPerformSelector:@selector(_radioOff:) withObject:self];	// notify all radio buttons in the same group to switch off
}

- (void) _radioOff:(DOMHTMLElement *) clickedCell;
{
#if 1
	NSLog(@"radioOff clicked %@ self %@", clickedCell, self);
#endif
	if(clickedCell == self)
		return;	// yes, we know...
	if(![[[self valueForKey:@"type"] lowercaseString] isEqualToString:@"radio"])
		return;	// only process radio buttons
	if([[clickedCell valueForKey:@"name"] caseInsensitiveCompare:[self valueForKey:@"name"]] == NSOrderedSame)
		{ // yes, they have the same name i.e. group!
			[cell setState:NSOffState];	// reset radio button
		}
}

- (NSString *) _formValue;	// return nil if not successful according to http://www.w3.org/TR/html401/interact/forms.html#h-17.3 17.13.2 Successful controls
{
	NSString *type=[[self valueForKey:@"type"] lowercaseString];
	//	FIXME: NSString *val=[self valueForKey:@"value"];	// returns strange values...
	NSString *val=[self getAttribute:@"value"];
	if([type isEqualToString:@"checkbox"])
		{
		if(!val) val=@"on";
		return [cell state] == NSOnState?val:(NSString *) @"";
		}
	else if([type isEqualToString:@"radio"])
		{ // report only the active button
			if(!val) val=@"on";
			return [cell state] == NSOnState?val:(NSString *) nil;
		}
	else if([type isEqualToString:@"submit"])
		{
		if(![cell isHighlighted])
			return nil;	// is not the button that has sent submit:
		if(val)
			return val;	// send value
		return [cell title];
		}
	else if([type isEqualToString:@"reset"])
		return nil;	// never send
	else if([type isEqualToString:@"hidden"])
		return val;	// pass value of hidden fields
	return [cell stringValue];	// text field
}

- (void) textDidEndEditing:(NSNotification *)aNotification
{
	NSNumber *code = [[aNotification userInfo] objectForKey:@"NSTextMovement"];
	[cell setStringValue:[[aNotification object] string]];	// copy value to cell
	[cell endEditing:[aNotification object]];
#if 1
	NSLog(@"Field Editor=%@", [aNotification object]);	// the field editor
	NSLog(@"[attachmentCell target]=%@", [cell target]);	// this DOMHTMLInputElement
	NSLog(@"[attachmentCell controlView]=%@", [cell controlView]);	// nil!
#endif
	switch([code intValue]) {
		case NSReturnTextMovement:
			[self _submit:nil];
			break;
		case NSTabTextMovement:
			break;
		case NSBacktabTextMovement:
			break;
		case NSIllegalTextMovement:
			break;
	}
}

// WebDocumentRepresentation callbacks (source is the subresource) - for type="image"

- (void) setDataSource:(WebDataSource *) dataSource; { return; }

- (void) finishedLoadingWithDataSource:(WebDataSource *) source; { [self release]; return; }

- (void) receivedData:(NSData *) data withDataSource:(WebDataSource *) source;
{ // simply ask our NSTextView for a re-layout
	NSLog(@"%@ receivedData: %u", NSStringFromClass(isa), [[source data] length]);
	[[self _visualRepresentation] setNeedsLayout:YES];
	[(NSView *) [self _visualRepresentation] setNeedsDisplay:YES];
}

- (void) receivedError:(NSError *) error withDataSource:(WebDataSource *) source;
{ // default error handler
	NSLog(@"%@ receivedError: %@", NSStringFromClass(isa), error);
}

@end

@implementation DOMHTMLButtonElement

- (void) _elementDidAwakeFromDocumentRepresentation:(_WebHTMLDocumentRepresentation *) rep;
{
	form=[self valueForKeyPath:@"ownerDocument.forms.lastChild"];
	[[form elements] appendChild:self];
	[super _elementDidAwakeFromDocumentRepresentation:rep];
}

// FIXME: handle this through display: inline-box

- (NSTextAttachment *) _attachment;
{ // create a text attachment that displays the content of the button
	NSMutableAttributedString *value=[[[NSMutableAttributedString alloc] init] autorelease];
	NSTextAttachment *attachment;
	NSString *name=[self valueForKey:@"name"];
	NSString *size=[self valueForKey:@"size"];
	WebView *webView=[[(DOMHTMLElement *) self webFrame] webView];
	[webView _spliceNode:[self firstChild] to:value pseudoElement:@"" parentStyle:nil parentAttributes:nil];
#if 0
	NSLog(@"<button>: %@", [self _attributes]);
#endif
	attachment=[NSTextAttachmentCell textAttachmentWithCellOfClass:[NSButtonCell class]];
	cell=(NSButtonCell *) [attachment attachmentCell];	// get the real cell
	[cell setBezelStyle:0];	// select a grey square button bezel by default
	// NOTE: Safari can display <tables> or other <input> elements nested within a <button>...</button>!
	[cell setAttributedTitle:value];	// formatted by contents between <buton> and </button>
	[cell setTarget:self];
	[cell setAction:@selector(_submit:)];
#if 0
	NSLog(@"  cell: %@", cell);
#endif
	return attachment;
}

- (void) _submit:(id) sender
{ // forward to <form> so that it can handle
	[self _triggerEvent:@"onclick"];
	[form _submitForm:self];
}

- (void) _radioOff:(DOMHTMLElement *) clickedCell; { return; }
- (void) _resetForm:(DOMHTMLElement *) ignored; { return; }

- (NSString *) _formValue;
{
	if(![cell isHighlighted])
		return nil;	// this is not the button that has sent submit:
	return [cell title];
}

@end

@implementation DOMHTMLSelectElement

+ (void) initialize
{
}

- (id) init
{
	if((self = [super init]))
		{
		options=[DOMHTMLCollection new]; 
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_willPopUp:) name:NSPopUpButtonCellWillPopUpNotification object:nil];
		}
	return self;
}

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[options release];
	[super dealloc];
}

- (void) _elementDidAwakeFromDocumentRepresentation:(_WebHTMLDocumentRepresentation *) rep;
{
	form=[self valueForKeyPath:@"ownerDocument.forms.lastChild"];
	[[form elements] appendChild:self];
	[super _elementDidAwakeFromDocumentRepresentation:rep];
}

- (NSTextAttachment *) _attachment
{ 
	NSTextAttachment *attachment;
	NSString *name=[self valueForKey:@"name"];
	NSString *val=[self valueForKey:@"value"];
	NSString *size=[self valueForKey:@"size"];
	BOOL multiSelect=[self hasAttribute:@"multiple"];
	if(!val)
		val=@"";
#if 0
	NSLog(@"<button>: %@", [self _attributes]);
#endif
	if(YES || [size intValue] <= 1)
		{ // popup menu
			DOMHTMLOptionElement *option;
			NSMenu *menu;
			NSEnumerator *e;
			attachment=[NSTextAttachmentCell textAttachmentWithCellOfClass:[NSPopUpButtonCell class]];
			cell=[attachment attachmentCell];	// get the real cell
			[(NSPopUpButtonCell *) cell setPullsDown:NO];
			[(NSPopUpButtonCell *) cell setTitle:val];
			[(NSPopUpButtonCell *) cell setTarget:self];
			[(NSPopUpButtonCell *) cell setAction:@selector(_submit:)];
			[(NSPopUpButtonCell *) cell setAltersStateOfSelectedItem:!multiSelect];
			// this musst also be done if we update the options nodes
			[cell removeAllItems];
			menu=[(NSPopUpButtonCell *) cell menu];
			[menu setMenuChangedMessagesEnabled:NO];
			e=[[options valueForKey:@"elements"] objectEnumerator];
			while((option=[e nextObject]))
				{
				NSMenuItem *item=[menu addItemWithTitle:[option text] action:NULL keyEquivalent:@""];
				if([option hasAttribute:@"disabled"])
					[item setEnabled:NO];
				if([option hasAttribute:@"selected"])
					[cell selectItem:item];
				}
			[menu setMenuChangedMessagesEnabled:YES];
		}
	else
		{ // embed NSTableView with [size intValue] visible lines
			attachment=nil;
			cell=nil;
		}
#if 0
	NSLog(@"  cell: %@", cell);
#endif
	return attachment;
}

- (void) _submit:(id) sender
{ // forward to <form> so that it can handle
	[self _triggerEvent:@"onclick"];
}

- (void) _radioOff:(DOMHTMLElement *) clickedCell; { return; }

- (void) _resetForm:(DOMHTMLElement *) ignored;
{	// NOTE: Safari simply selects the first option (!)
	NSArray *elements=[options valueForKey:@"elements"];
	int i, cnt=[elements count];
	[cell selectItemAtIndex:0];	// default to select first item
	for(i=0; i<cnt; i++)
		{
		DOMHTMLOptionElement *option=[elements objectAtIndex:i];
		if([option hasAttribute:@"selected"])
			[cell selectItemAtIndex:i];	// selects the last one with "selected"
		}
}

- (void) _willPopUp:(NSNotification *)aNotification
{
	[self _triggerEvent:@"onselect"];
}

- (NSString *) _formValue;
{
	int idx=[cell indexOfSelectedItem];
	if(idx < 0)
		return nil;	// nothing selected
	return [[[options valueForKey:@"elements"] objectAtIndex:idx] valueForKey:@"value"];
}

- (DOMHTMLCollection *) options { return options; }

// fixme - translate TextView notifications into JavaScript events: onblur, onselect, onchange, onfocus, ...

@end

@implementation DOMHTMLOptionElement

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLLazyNesting; }

- (void) _elementDidAwakeFromDocumentRepresentation:(_WebHTMLDocumentRepresentation *) rep;
{
	DOMHTMLElement *sel=self;
	while(sel)
		{ // find enclosing <select>
			if([sel isKindOfClass:[DOMHTMLSelectElement class]])
				break;
			sel=(DOMHTMLElement *) [sel parentNode];
		}
	if(sel)
		[[(DOMHTMLSelectElement *) sel options] appendChild:self];
	[super _elementDidAwakeFromDocumentRepresentation:rep];
}

- (NSString *) text
{
	NSMutableAttributedString *value=[[[NSMutableAttributedString alloc] init] autorelease];
	WebView *webView=[[(DOMHTMLElement *) self webFrame] webView];
	[webView _spliceNode:[self firstChild] to:value pseudoElement:@"" parentStyle:nil parentAttributes:nil];
	return [value string];	// removes any style but has processed content:
}

@end

@implementation DOMHTMLOptGroupElement

@end

@implementation DOMHTMLLabelElement

@end

@implementation DOMHTMLTextAreaElement

- (void) _elementDidAwakeFromDocumentRepresentation:(_WebHTMLDocumentRepresentation *) rep;
{
	form=[self valueForKeyPath:@"ownerDocument.forms.lastChild"];
	[[form elements] appendChild:self];
	[super _elementDidAwakeFromDocumentRepresentation:rep];
}

// FIXME: split into CSS component, attachment generation
// FIXME: can we handle this completely as display: textarea (similar to display: inline-block)?

- (NSTextAttachment *) _attachment;
{ // <textarea cols=xxx lines=yyy>value</textarea> 
	NSMutableAttributedString *value=[[[NSMutableAttributedString alloc] init] autorelease];
	NSTextAttachment *attachment;
	NSString *name=[self valueForKey:@"name"];
	NSString *cols=[self valueForKey:@"cols"];
	NSString *lines=[self valueForKey:@"lines"];
	WebView *webView=[[(DOMHTMLElement *) self webFrame] webView];
	[webView _spliceNode:[self firstChild] to:value pseudoElement:@"" parentStyle:nil parentAttributes:nil];
#if 0
	NSLog(@"<textarea>: %@", [self _attributes]);
#endif
	// FIXME: this should be an embedded TextView
	attachment=[NSTextAttachmentCell textAttachmentWithCellOfClass:[NSTextFieldCell class]];
	cell=(NSTextFieldCell *) [attachment attachmentCell];	// get the real cell
	//	[cell setBezelStyle:0];	// select a grey square button bezel by default
	[(NSTextFieldCell *) cell setBezeled:YES];
	[cell setEditable:!([self hasAttribute:@"disabled"] || [self hasAttribute:@"readonly"])];
	[(NSTextFieldCell *) cell setSelectable:YES];
	[cell setAttributedStringValue:value];	// formatted by contents between <textarea> and </textarea>
	[cell setTarget:self];
	[cell setAction:@selector(_submit:)];
#if 0
	NSLog(@"  cell: %@", cell);
#endif
	return attachment;
}

- (void) textDidEndEditing:(NSNotification *)aNotification
{
  [cell setStringValue:[[aNotification object] string]];	// copy value to cell
	[cell endEditing:[aNotification object]];	
}

- (void) _submit:(id) sender
{ // forward to <form> so that it can handle
	[self _triggerEvent:@"onclick"];
	[form _submitForm:self];
}

- (void) _radioOff:(DOMHTMLElement *) clickedCell; { return; }

- (void) _resetForm:(DOMHTMLElement *) ignored;
{
	// FIXME: reset the original string value
	// should be saved for that purpose!
}

- (NSString *) _formValue;
{
	return [cell stringValue];
}

// fixme - translate TextView notifications into JavaScript events: onblur, onselect, onchange, onfocus, ...

@end

// FIXME:
// NSTextList is just descriptors. The Text system does interpret it only when (re)generating new-lines
// List entries are not automatically generated when building attributed strings!
// i.e. we must generate and store the marker string explicitly

@implementation DOMHTMLLIElement	// <li>, <dt>, <dd>

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLLazyNesting; }

#if 0
- (NSString *) _stringBefore;
{
	NSParagraphStyle *paragraph=[_style objectForKey:NSParagraphStyleAttributeName];
	NSArray *lists=[paragraph textLists];	// get (nested) list
	NSString *node=[self nodeName];
	if([node isEqualToString:@"LI"])
		{
		int i=[lists count];
		NSString *str=@"\t";
		while(i-- > 0)
			{
			NSTextList *list=[lists objectAtIndex:i];
			// where do we get the correct item number from? we must track in parent ol/ul nodes!
			str=[[list markerForItemNumber:1] stringByAppendingString:str];
			if(!([list listOptions] & NSTextListPrependEnclosingMarker))
				break;	// don't prepend
			}
		return str;
		}
	else if([node isEqualToString:@"DT"])
		return @"";
	else	// <DL>
		return @"\t";
}
#endif

@end

@implementation DOMHTMLDListElement		// <dl>

#if 0
- (void) OLD_addAttributesToStyle
{
	NSMutableParagraphStyle *paragraph=[[_style objectForKey:NSParagraphStyleAttributeName] mutableCopy];
	NSString *align=[self valueForKey:@"align"];
	NSArray *lists=[paragraph textLists];	// get (nested) list
	NSTextList *list;
	// FIXME: decode HTML list formats and options and translate
	list=[[NSClassFromString(@"NSTextList") alloc] initWithMarkerFormat:@"\t" options:NSTextListPrependEnclosingMarker];
	if(list)
		{ // add initial list marker
			if(!lists)
				lists=[NSMutableArray new];	// start new one
			else
				lists=[lists mutableCopy];			// make mutable
			[(NSMutableArray *) lists addObject:list];
			[list release];
			[paragraph setTextLists:lists];
			[lists release];
		}
#if 0
	NSLog(@"lists=%@", lists);
#endif
	[_style setObject:@"list-item" forKey:@"display"];
	[_style setObject:paragraph forKey:NSParagraphStyleAttributeName];
	[paragraph release];
}
#endif

@end

@implementation DOMHTMLOListElement		// <ol>

#if 0
- (void) OLD_addAttributesToStyle;
{ 
	NSMutableParagraphStyle *paragraph=[[_style objectForKey:NSParagraphStyleAttributeName] mutableCopy];
	NSString *align=[self valueForKey:@"align"];
	NSArray *lists=[paragraph textLists];	// get (nested) list
	NSTextList *list;
	// FIXME: decode HTML list formats and options and translate
	list=[[NSClassFromString(@"NSTextList") alloc] 
		  initWithMarkerFormat: @"{decimal}." 
		  options: NSTextListPrependEnclosingMarker];
	if(list)
		{
		if(!lists) 
			lists=[NSMutableArray new];	// start new one
		else 
			lists=[lists mutableCopy];	// make mutable
		[(NSMutableArray *) lists addObject:list];
		[list release];
		[paragraph setTextLists:lists];
		[lists release];
		}
#if 0
	NSLog(@"lists=%@", lists);
#endif
	[_style setObject:@"block" forKey:@"display"];
	[_style setObject:paragraph forKey: NSParagraphStyleAttributeName];
	[paragraph release];
}
#endif

@end

@implementation DOMHTMLUListElement		// <ul>

#if 0
- (void) OLD_addAttributesToStyle;
{ // add attributes to style
	NSMutableParagraphStyle *paragraph=[[_style objectForKey:NSParagraphStyleAttributeName] mutableCopy];
	NSArray *lists=[paragraph textLists];	// get (nested) list
	NSTextList *list;
	
	// FIXME: decode list formats and options
	
	// change the marker style depending on nesting level disc -> circle -> hyphen
	
	// move this to _splice
	list=[[NSClassFromString(@"NSTextList") alloc] initWithMarkerFormat:@"{disc}" options:0];
	if(list)
		{
		if(!lists)
			lists=[NSMutableArray new];	// start new one
		else
			lists=[lists mutableCopy];			// make mutable
		[(NSMutableArray *) lists addObject:list];
		[list release];
		[paragraph setTextLists:lists];
		[lists release];
		}
#if 0
	NSLog(@"lists=%@", lists);
#endif
	[_style setObject:@"block" forKey:@"display"];
	[_style setObject:paragraph forKey:NSParagraphStyleAttributeName];
	[paragraph release];
}
#endif

@end

@implementation DOMHTMLCanvasElement		// <canvas>

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLNoNesting; }

@end
