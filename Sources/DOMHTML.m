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
// FIXME: add additional attributes (e.g. images, anchors etc. for DOMHTMLDocument) and DOMHTMLCollection type

// look at for handling of whitespace: http://www.w3.org/TR/html401/struct/text.html
// about "display:block" and "display:inline": http://de.selfhtml.org/html/referenz/elemente.htm

#import <WebKit/WebView.h>
#import <WebKit/WebResource.h>
#import "WebHTMLDocumentView.h"
#import "WebHTMLDocumentRepresentation.h"
#import "Private.h"

static NSString *DOMHTMLAnchorElementTargetWindow=@"DOMHTMLAnchorElementTargetName";
static NSString *DOMHTMLAnchorElementAnchorName=@"DOMHTMLAnchorElementAnchorName";
static NSString *DOMHTMLBlockInlineLevel=@"display";

#if defined(__APPLE__)
#if (MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_3)	

// Tiger (10.4) - includes (trhrough WebKit/WebView.h and Cocoa/Cocoa.h) and implements tables

#else

// declarations for headers of classes introduced in OSX 10.4 (#import <NSTextTable.h>) on systems that don't have it

@interface NSTextBlock : NSObject
- (void) setBackgroundColor:(NSColor *) color;
- (void) setBorderColor:(NSColor *) color;
- (void) setWidth:(float) width type:(int) type forLayer:(int) layer;

// FIXME: values must match implementation in Apple AppKit!

#define NSTextBlockBorder 0
#define NSTextBlockPadding 1
#define NSTextBlockMargin 2
#define NSTextBlockAbsoluteValueType 0
#define NSTextBlockPercentageValueType 1
#define NSTextBlockTopAlignment	0
#define NSTextBlockMiddleAlignment 1
#define NSTextBlockBottomAlignment 2
#define NSTextBlockBaselineAlignment 3
@end

@interface NSTextTable : NSTextBlock
- (int) numberOfColumns;
- (void) setHidesEmptyCells:(BOOL) flag;
- (void) setNumberOfColumns:(unsigned) cols;
@end

@interface NSTextTableBlock : NSTextBlock
- (id) initWithTable:(NSTextTable *) table startingRow:(int) r rowSpan:(int) rs startingColumn:(int) c columnSpan:(int) cs;
@end

@interface NSTextList : NSObject <NSCoding, NSCopying>
- (id) initWithMarkerFormat:(NSString *) fmt options:(unsigned) mask;
- (unsigned) listOptions;
- (NSString *) markerForItemNumber:(int) item;
- (NSString *) markerFormat;
@end

#endif
#endif

@implementation NSString (HTMLAttributes)

- (BOOL) _htmlBoolValue;
{
	if([self length] == 0)
		return YES;	// pure existence means YES
	if([[self lowercaseString] isEqualToString:@"yes"])
		return YES;
	return NO;
}

- (NSColor *) _htmlColor;
{
	unsigned hex;
	NSScanner *sc=[NSScanner scannerWithString:self];
	if([sc scanString:@"#" intoString:NULL] && [sc scanHexInt:&hex])
		{ // should check for 6 hex digits...
		return [NSColor colorWithCalibratedRed:((hex>>16)&0xff)/255.0 green:((hex>>8)&0xff)/255.0 blue:(hex&0xff)/255.0 alpha:1.0];
		}
	return [NSColor colorWithCatalogName:@"SystemColor" colorName:[self lowercaseString]];
}

- (NSTextAlignment) _htmlAlignment;
{
	self=[self lowercaseString];
	if([self isEqualToString:@"left"])
		return NSLeftTextAlignment;
	else if([self isEqualToString:@"right"])
		return NSRightTextAlignment;
	else if([self isEqualToString:@"center"])
		return NSCenterTextAlignment;
	else if([self isEqualToString:@"justify"])
		return NSJustifiedTextAlignment;
	else
		return NSNaturalTextAlignment;
}

- (NSEnumerator *) _htmlFrameSetEnumerator;
{
	NSArray *elements=[self componentsSeparatedByString:@","];
	NSEnumerator *e;
	NSString *element;
	NSMutableArray *r=[NSMutableArray arrayWithCapacity:[elements count]];
	float total=0.0;
	float strech=0.0;
	e=[elements objectEnumerator];
	while((element=[e nextObject]))
		{ // x% or * or n* - first pass to get total width
		float width;
		element=[element stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		if([element isEqualToString:@"*"])
			strech=1.0;
		else
			{
			width=[element floatValue];
			if(width > 0.0)
				total+=width;	// accumulate
			}
		}
	if(strech)
		{
		strech=100.0-total;	// how much is missing
		total=100.0;		// 100% total
		}
	if(total == 0.0)
		return nil;
	e=[elements objectEnumerator];
	while((element=[e nextObject]))
		{ // x% or * or n*
		float width;
		element=[element stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		if([element isEqualToString:@"*"])
			width=strech;
		else
			width=[element floatValue];
		[r addObject:[NSNumber numberWithFloat:width/total]];	// fraction of total width
		}
	return [r objectEnumerator];
}

@end

// FIXME: read this from our WebPreferences!
// [[webView preferences] fixedFontFamily] etc.
// [[webView preferences] fixedFontSize] etc.

#define DEFAULT_FONT_SIZE 16.0
#define DEFAULT_FONT @"Times"
#define DEFAULT_BOLD_FONT @"Times-Bold"
#define DEFAULT_TT_SIZE 13.0
#define DEFAULT_TT_FONT @"Courier"

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
	return nil;
}

- (WebFrame *) webFrame
{
	return [(DOMHTMLDocument *) [[self ownerDocument] lastChild] webFrame];
}

- (NSURL *) URLWithAttributeString:(NSString *) string;	// we don't inherit from DOMDocument...
{
	DOMHTMLDocument *htmlDocument=(DOMHTMLDocument *) [[self ownerDocument] lastChild];
	return [NSURL URLWithString:[self getAttribute:string] relativeToURL:[[[htmlDocument _webDataSource] response] URL]];
}

- (NSData *) _loadSubresourceWithAttributeString:(NSString *) string blocking:(BOOL) stall;
{
	DOMHTMLDocument *htmlDocument=(DOMHTMLDocument *) [[self ownerDocument] lastChild];
	WebDataSource *source=[htmlDocument _webDataSource];
	NSString *urlstring=[self getAttribute:string];
	NSURL *url=[[NSURL URLWithString:urlstring relativeToURL:[[source response] URL]] absoluteURL];
	if(url)
		{
		WebDataSource *sub;
		WebResource *res=[source subresourceForURL:url];
		NSData *data;
		if(res)
			{
#if 0
			NSLog(@"sub: already completely loaded: %@ (%u bytes)", url, [[res data] length]);
#endif
			return [res data];	// already completely loaded
			}
		sub=[source _subresourceWithURL:url delegate:(id <WebDocumentRepresentation>) self];	// triggers loading if not yet and make me receive notification
#if 0
		NSLog(@"sub: loading: %@ (%u bytes) delegate=%@", url, [[sub data] length], self);
#endif
		data=[sub data];
		if(!data && stall)	//incomplete
			[[(_WebHTMLDocumentRepresentation *) [source representation] _parser] _stall:YES];	// make parser stall until we have loaded
		return data;
		}
	return nil;
}

// WebDocumentRepresentation callbacks

- (void) setDataSource:(WebDataSource *) dataSource; { return; }

- (void) finishedLoadingWithDataSource:(WebDataSource *) source;
{ // our subresource did load - i.e. we can clear the stall on the main HTML script
	DOMHTMLDocument *htmlDocument=(DOMHTMLDocument *) [[self ownerDocument] lastChild];
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
	NSString *script=[(DOMElement *) self getAttribute:event];
	if(script)
		{
#if 0
		NSLog(@"trigger %@=%@", event, script);
#endif
		// FIXME: make an event object available to the script
		// FIXME: make depend on [[webView preferences] isJavaScriptEnabled]
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

- (void) _elementDidAwakeFromDocumentRepresentation:(_WebHTMLDocumentRepresentation *) rep;
{ // our subclasses should call [super _elementDidAwakeFromDocumentRepresentation:rep];
	// FIXME: this appears to be case sensitive!
	[self _triggerEvent:@"onload"];
}

- (void) _elementLoaded; { return; } // ignore

@end

@implementation DOMHTMLElement

// FIXME: how do we recognize changes in attributes/CSS to clear the cache?
// we must also clear the cache of all descendants!

- (void) dealloc
{
	[_style release];
	[super dealloc];
}

// layout and rendering

- (NSString *) outerHTML;
{
	NSMutableString *str=[NSMutableString stringWithFormat:@"<%@", [self nodeName]];
	if([self respondsToSelector:@selector(_attributes)])
		{
		NSEnumerator *e=[[self _attributes] objectEnumerator];
		DOMAttr *a;
		while((a=[e nextObject]))
			{
			if([a specified])
				[str appendFormat:@" %@=\"%@\"", [a name], [a value]];			
			else
				[str appendFormat:@" %@", [a name]];			
			}
		}
	[str appendFormat:@">%@", [self innerHTML]];
	if([isa _nesting] != DOMHTMLNoNesting)
		[str appendFormat:@"</%@>\n", [self nodeName]];	// close
	return str;
}

- (NSString *) innerHTML;
{
	NSString *str=@"";
	int i;
	for(i=0; i<[_childNodes length]; i++)
		{
		NSString *d=[(DOMHTMLElement *) [_childNodes item:i] outerHTML];
		str=[str stringByAppendingString:d];
		}
	return str;
}

// Hm... how do we run the parser here?
// it can't be the full parser
// what happens if we set illegal html?
// what happens if we set unbalanced nodes
// what happens if we set e.h. <head>, <script>, <frame> etc.?

- (void) setInnerHTML:(NSString *) str; { NIMP; }
- (void) setOuterHTML:(NSString *) str; { NIMP; }

- (NSAttributedString *) attributedString;
{ // get part as attributed string
	NSMutableAttributedString *str=[[[NSMutableAttributedString alloc] init] autorelease];
	[self _spliceTo:str];	// recursively splice all child element strings into our string
	[self _flushStyles];	// don't keep them in the DOM Tree
#if 0
	[str removeAttribute:DOMHTMLBlockInlineLevel range:NSMakeRange(0, [str length])];
#endif
	return str;
}

- (void) _layout:(NSView *) parent;
{
	NIMP;	// no default implementation!
}

- (void) _spliceTo:(NSMutableAttributedString *) str;
{ // recursively splice this node and any subnodes, taking end of last fragment into account
	unsigned i;
	NSDictionary *style=[self _style];
	NSTextAttachment *attachment=[self _attachment];	// may be nil
	NSString *string=[self _string];	// may be nil
	BOOL lastIsInline=[str length]>0 && [[str attribute:DOMHTMLBlockInlineLevel atIndex:[str length]-1 effectiveRange:NULL] isEqualToString:@"inline"];
	BOOL isInline=[[style objectForKey:DOMHTMLBlockInlineLevel] isEqualToString:@"inline"];
	if(lastIsInline && !isInline)
		{ // we need to close the last inline segment and prefix new block mode segment
		if([[str string] hasSuffix:@" "])
			[str replaceCharactersInRange:NSMakeRange([str length]-1, 1) withString:@"\n"];	// replace space
		else
			[str replaceCharactersInRange:NSMakeRange([str length], 0) withString:@"\n"];	// this operation inherits attributes of the previous section
		}
	if(attachment)
		{ // add styled attachment (if available)
		NSMutableAttributedString *astr=(NSMutableAttributedString *)[NSMutableAttributedString attributedStringWithAttachment:attachment];
		[astr addAttributes:style range:NSMakeRange(0, [astr length])];
		[str appendAttributedString:astr];
		}
	if([string length] > 0)	
		{ // add styled string (if available)
		[str appendAttributedString:[[[NSAttributedString alloc] initWithString:string attributes:style] autorelease]];
		}
	if(string)
		{ // must be @""
		for(i=0; i<[_childNodes length]; i++)
			{ // add children nodes (if available)
			[(DOMHTMLElement *) [_childNodes item:i] _spliceTo:str];
			}
		}
	if(!isInline)
		{ // close our block
		if([[str string] hasSuffix:@" "])
			[str replaceCharactersInRange:NSMakeRange([str length]-1, 1) withString:@""];	// strip off trailing space
		[str appendAttributedString:[[[NSAttributedString alloc] initWithString:@"\n" attributes:style] autorelease]];	// close this block
		}
}

- (NSMutableDictionary *) _style;
{ // get attributes to apply to this node, process appropriate CSS definition by tag, tag level, id, class, etc.
	if(!_style)
		{
		_style=[[(DOMHTMLElement *) _parentNode _style] mutableCopy];	// inherit initial style from parent node; make a copy so that we can modify
		[_style setObject:self forKey:WebElementDOMNodeKey];	// establish a reference to ourselves into the DOM tree
		[_style setObject:[(DOMHTMLDocument *) [[self ownerDocument] lastChild] webFrame] forKey:WebElementFrameKey];
		[_style setObject:@"inline" forKey:DOMHTMLBlockInlineLevel];	// set default display style (override in _addAttributesToStyle)
		[self _addAttributesToStyle];
		[self _addCSSToStyle];
		}
	return _style;
}

- (void) _flushStyles;
{
	if(_style)
		{
		[_style release];
		_style=nil;
		}
	[[_childNodes _list] makeObjectsPerformSelector:_cmd];	// also flush child nodes
}

- (DOMCSSStyleDeclaration *) _cssStyle;
{ // get relevant CSS definition by tag, tag level, id, class, etc. recursively going upwards
	return nil;
}

- (void) _addCSSToStyle;				// add CSS to style
{
	DOMCSSStyleDeclaration *css;
	// FIXME
}

- (void) _addAttributesToStyle;			// add attributes to style
{ // allow nodes to override by examining the attributes
	NSString *node=[self nodeName];
	if([node isEqualToString:@"B"] || [node isEqualToString:@"STRONG"])
		{ // make bold
		NSFont *f=[_style objectForKey:NSFontAttributeName];	// get current font
		f=[[NSFontManager sharedFontManager] convertFont:f toHaveTrait:NSBoldFontMask];
		if(f) [_style setObject:f forKey:NSFontAttributeName];
		else NSLog(@"could not convert %@ to Bold", [_style objectForKey:NSFontAttributeName]);
		}
	else if([node isEqualToString:@"I"] || [node isEqualToString:@"EM"] || [node isEqualToString:@"VAR"] || [node isEqualToString:@"CITE"])
		{ // make italics
		NSFont *f=[_style objectForKey:NSFontAttributeName];	// get current font
		f=[[NSFontManager sharedFontManager] convertFont:f toHaveTrait:NSItalicFontMask];
		if(f) [_style setObject:f forKey:NSFontAttributeName];
		else NSLog(@"could not convert %@ to Italics", [_style objectForKey:NSFontAttributeName]);
		}
	else if([node isEqualToString:@"TT"] || [node isEqualToString:@"CODE"] || [node isEqualToString:@"KBD"] || [node isEqualToString:@"SAMP"])
		{ // make monospaced
		WebView *webView=[[(DOMHTMLDocument *) [[self ownerDocument] lastChild] webFrame] webView];
		NSFont *f=[_style objectForKey:NSFontAttributeName];	// get current font
		f=[[NSFontManager sharedFontManager] convertFont:f toFamily:DEFAULT_TT_FONT];
		f=[[NSFontManager sharedFontManager] convertFont:f toSize:DEFAULT_TT_SIZE*[webView textSizeMultiplier]];
		if(f) [_style setObject:f forKey:NSFontAttributeName];
		}
	else if([node isEqualToString:@"U"])
		{ // make underlined
#if defined(__mySTEP__) || MAC_OS_X_VERSION_10_2 < MAC_OS_X_VERSION_MAX_ALLOWED
		[_style setObject:[NSNumber numberWithInt:NSUnderlineStyleSingle] forKey:NSUnderlineStyleAttributeName];
#else	// MacOS X < 10.3 and GNUstep
		[_style setObject:[NSNumber numberWithInt:NSSingleUnderlineStyle] forKey:NSUnderlineStyleAttributeName];
#endif
		}
	else if([node isEqualToString:@"STRIKE"])
		{ // make strike-through
#if defined(__mySTEP__) || MAC_OS_X_VERSION_10_2 < MAC_OS_X_VERSION_MAX_ALLOWED
		[_style setObject:[NSNumber numberWithInt:NSUnderlineStyleSingle] forKey:NSStrikethroughStyleAttributeName];
#else	// MacOS X < 10.3 and GNUstep
		//		[s setObject:[NSNumber numberWithInt:NSSingleUnderlineStyle] forKey:NSStrikethroughStyleAttributeName];
#endif		
		}
	else if([node isEqualToString:@"SUP"])
		{ // make superscript
		NSFont *f=[_style objectForKey:NSFontAttributeName];	// get current font
		f=[[NSFontManager sharedFontManager] convertFont:f toSize:[f pointSize]/1.2];
		if(f) [_style setObject:f forKey:NSFontAttributeName];
		[_style setObject:[NSNumber numberWithInt:1] forKey:NSSuperscriptAttributeName];
		}
	else if([node isEqualToString:@"SUB"])
		{ // make subscript
		NSFont *f=[_style objectForKey:NSFontAttributeName];	// get current font
		f=[[NSFontManager sharedFontManager] convertFont:f toSize:[f pointSize]/1.2];
		if(f)
			[_style setObject:f forKey:NSFontAttributeName];
		[_style setObject:[NSNumber numberWithInt:-1] forKey:NSSuperscriptAttributeName];
		}
	else if([node isEqualToString:@"BIG"])
		{ // make font larger +1
		NSFont *f=[_style objectForKey:NSFontAttributeName];	// get current font
		[_style setObject:[NSFont fontWithName:[f fontName] size:[f pointSize]*1.2] forKey:NSFontAttributeName];
		f=[[NSFontManager sharedFontManager] convertFont:f toSize:[f pointSize]*1.2];
		if(f) [_style setObject:f forKey:NSFontAttributeName];
		}
	else if([node isEqualToString:@"SMALL"])
		{ // make font smaller -1
		NSFont *f=[_style objectForKey:NSFontAttributeName];	// get current font
		f=[[NSFontManager sharedFontManager] convertFont:f toSize:[f pointSize]/1.2];
		if(f) [_style setObject:f forKey:NSFontAttributeName];
		}
}

- (NSString *) _string; { return @""; }	// default is no content

- (NSTextAttachment *) _attachment; { return nil; }	// default is no attachment

@end

@implementation DOMCharacterData (DOMHTMLElement)

- (NSString *) outerHTML;
{
	return [self data];
}

- (NSString *) innerHTML;
{
	return [self data];
}

- (void) _flushStyles; { return; }	// we may be children but don't chache styles

- (void) _spliceTo:(NSMutableAttributedString *) str;
{
	BOOL lastIsInline=[str length]>0 && [[str attribute:DOMHTMLBlockInlineLevel atIndex:[str length]-1 effectiveRange:NULL] isEqualToString:@"inline"];
	// FIXME: there is a setting in CSS 3.0 which controls this mapping
	// if we are enclosed in a <PRE> skip this step
	NSMutableString *s=[[[self data] mutableCopy] autorelease];
	[s replaceOccurrencesOfString:@"\r" withString:@" " options:0 range:NSMakeRange(0, [s length])];	// convert to space
	[s replaceOccurrencesOfString:@"\n" withString:@" " options:0 range:NSMakeRange(0, [s length])];	// convert to space
	[s replaceOccurrencesOfString:@"\t" withString:@" " options:0 range:NSMakeRange(0, [s length])];	// convert to space
#if QUESTIONABLE_OPTIMIZATION
	while([s replaceOccurrencesOfString:@"        " withString:@" " options:0 range:NSMakeRange(0, [s length])])	// convert long space sequences into single one
		;
#endif
	while([s replaceOccurrencesOfString:@"  " withString:@" " options:0 range:NSMakeRange(0, [s length])])	// convert double spaces into single one
		;	// trim multiple spaces to single ones as long as we find them
	if(!lastIsInline && [s hasPrefix:@" "])
		s=(NSMutableString *)[s substringFromIndex:1];	// strip off leading spaces after blocks (string is immutable but we don't have to change it from now on)
	if([s length] > 0)
		{ // is not empty, get style from parent node and append characters
		NSMutableDictionary *style=[[(DOMHTMLElement *) [self parentNode] _style] mutableCopy];
		[style setObject:@"inline" forKey:DOMHTMLBlockInlineLevel];	// text must be regarded as inline
		[style setObject:self forKey:WebElementDOMNodeKey];	// establish a reference to ourselves into the DOM tree
		[str appendAttributedString:[[[NSAttributedString alloc] initWithString:s attributes:style] autorelease]];	// add formatted content
		[style release];
		}
}

- (void) _layout:(NSView *) parent;
{
	return;	// ignore if mixed with <frame> and <frameset> elements
}

@end

@implementation DOMCDATASection (DOMHTMLElement)

- (void) _spliceTo:(NSMutableAttributedString *) str; { return; }	// ignore

- (NSString *) outerHTML;
{
	return [NSString stringWithFormat:@"<![CDATA[%@]]>", [(DOMHTMLElement *)self innerHTML]];
}

@end

@implementation DOMComment (DOMHTMLElement)

- (void) _spliceTo:(NSMutableAttributedString *) str; { return; }	// ignore

- (NSString *) outerHTML;
{
	return [NSString stringWithFormat:@"<!-- %@ -->\n", [(DOMHTMLElement *)self innerHTML]];
}

@end

@implementation DOMHTMLDocument

- (WebFrame *) webFrame; { return _webFrame; }
- (void) _setWebFrame:(WebFrame *) f; { _webFrame=f; }
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
	NSString *cmd=[self getAttribute:@"http-equiv"];
	if([cmd caseInsensitiveCompare:@"refresh"] == NSOrderedSame)
		{ // handle  <meta http-equiv="Refresh" content="4;url=http://www.domain.com/link.html">
		NSString *content=[self getAttribute:@"content"];
		NSArray *c=[content componentsSeparatedByString:@";"];
		if([c count] == 2)
			{
			DOMHTMLDocument *htmlDocument=(DOMHTMLDocument *) [[self ownerDocument] lastChild];
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
				[[(DOMHTMLDocument *) [[self ownerDocument] lastChild] webFrame] _performClientRedirectToURL:url delay:seconds];
				}
			// else raise some error...
			}
		}
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
	NSString *rel=[[self getAttribute:@"rel"] lowercaseString];
	if([rel isEqualToString:@"stylesheet"] && [[self getAttribute:@"type"] isEqualToString:@"text/css"])
		{ // load stylesheet in background
		[self _loadSubresourceWithAttributeString:@"href" blocking:NO];
		}
	else if([rel isEqualToString:@"home"])
		{
		NSLog(@"<link>: %@", [self _attributes]);
		}
 	else if([rel isEqualToString:@"alternate"])
		{
		NSLog(@"<link>: %@", [self _attributes]);
		}
	else if([rel isEqualToString:@"index"])
		{
		NSLog(@"<link>: %@", [self _attributes]);
		}
	else if([rel isEqualToString:@"shortcut icon"])
		{
		NSLog(@"<link>: %@", [self _attributes]);
		}
	else
		{
		NSLog(@"<link>: %@", [self _attributes]);
		}
	[super _elementDidAwakeFromDocumentRepresentation:rep];
}

// WebDocumentRepresentation callbacks

- (void) setDataSource:(WebDataSource *) dataSource; { return; }
- (void) finishedLoadingWithDataSource:(WebDataSource *) source; { return; }
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
	[super _elementDidAwakeFromDocumentRepresentation:rep];
}

// FIXME: process "@import URL" subresources
// CHECKME: here or delayed when referenced in CSS?

@end

@implementation DOMHTMLScriptElement

// FIXME: or should we use designatedParentNode; { return nil; } so that it is NOT stored in DOM Tree?

- (void) _spliceTo:(NSMutableAttributedString *) str; { return; }	// ignore if in <body> context

- (void) _elementDidAwakeFromDocumentRepresentation:(_WebHTMLDocumentRepresentation *) rep;
{
	[[rep _parser] _setReadMode:1];	// switch parser mode to read up to </script>
	if([self hasAttribute:@"src"])
		// FIXME: && [[webView preferences] isJavaScriptEnabled])
		{ // we have an external script to load first
#if 0
		NSLog(@"load <script src=%@>", [self getAttribute:@"src"]);
#endif
		[self _loadSubresourceWithAttributeString:@"src" blocking:YES];	// trigger loading of script or get from cache - notifications will be tied to self, i.e. this instance of the <script element>
		}
	[super _elementDidAwakeFromDocumentRepresentation:rep];
}

- (void) _elementLoaded;
{ // <script> element has been completely loaded, i.e. we are called from the </script> tag
	NSString *type=[self getAttribute:@"type"];	// should be "text/javascript" or "application/javascript"
	NSString *lang=[[self getAttribute:@"lang"] lowercaseString];	// optional language "JavaScript" or "JavaScript1.2"
	NSString *script;
	// FIXME: if(![[webView preferences] isJavaScriptEnabled]) return;	// ignore script
	if(![type isEqualToString:@"text/javascript"] && ![type isEqualToString:@"application/javascript"] && ![lang hasPrefix:@"javascript"])
		return;	// ignore
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
#if 0
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

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLNoNesting; }

- (void) _addAttributesToStyle
{
	[_style setObject:@"block" forKey:DOMHTMLBlockInlineLevel];
}

@end

@implementation DOMHTMLParamElement

@end

@implementation DOMHTMLFrameSetElement

- (void) _addAttributesToStyle
{
	[_style setObject:@"block" forKey:DOMHTMLBlockInlineLevel];
}

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
	return [[[DOMHTMLElement alloc] _initWithName:@"#dummy" namespaceURI:nil document:[[rep _root] ownerDocument]] autorelease];	// return dummy
}

- (void) _layout:(NSView *) view;
{ // recursively arrange subviews so that they match children
	NSString *rows=[self getAttribute:@"rows"];	// comma separated list e.g. "20%,*" or "1*,3*,7*"
	NSString *cols=[self getAttribute:@"cols"];
	NSEnumerator *erows, *ecols;
	NSNumber *rowHeight, *colWidth;
	NSRect parentFrame=[view frame];
	NSPoint last=parentFrame.origin;
	DOMNodeList *children=[self childNodes];
	unsigned count=[children length];
	unsigned childIndex=0;
	unsigned subviewIndex=0;
#if 0
	NSLog(@"_layout: %@", self);
	NSLog(@"attribs: %@", [self _attributes]);
#endif
	if(![view isKindOfClass:[_WebHTMLDocumentView class]])
		{ // add/substitute a new _WebHTMLDocumentFrameSetView view of same dimensions
		_WebHTMLDocumentFrameSetView *setView=[[_WebHTMLDocumentFrameSetView alloc] initWithFrame:parentFrame];
		/// [[self webFrame] frameView]
		if([[view superview] isKindOfClass:[NSClipView class]])
			[(NSClipView *) [view superview] setDocumentView:setView];			// make the FrameSetView the document view
		else
			[[view superview] replaceSubview:view with:setView];	// replace
		view=setView;	// use new
		[setView release];
		}
	if(!rows) rows=@"100";	// default to 100% height
	if(!cols) cols=@"100";	// default to 100% width
	erows=[rows _htmlFrameSetEnumerator];
	while((rowHeight=[erows nextObject]))
		{ // rearrange subviews
		float height=[rowHeight floatValue];
		float newHeight=parentFrame.size.height*height;
		ecols=[cols _htmlFrameSetEnumerator];
		while((colWidth=[ecols nextObject]))
			{
			DOMHTMLElement *child=nil;
			NSView *childView;
			NSRect newChildFrame;
			while(childIndex < count)
				{ // find next <frame> or <frameset> child
				child=(DOMHTMLElement *) [children item:childIndex++];
				if([child isKindOfClass:[DOMHTMLFrameSetElement class]] || [child isKindOfClass:[DOMHTMLFrameElement class]])
					break;
				}
			newChildFrame=(NSRect){ last, { parentFrame.size.width*[colWidth floatValue], newHeight } };
			if(subviewIndex < [[view subviews] count])
				{	// (re)position subview
				childView=[[view subviews] objectAtIndex:subviewIndex++];
				[childView setFrame:newChildFrame];
				[childView setNeedsDisplay:YES];
				}
			else
				{ // add a new subview/subframe at the specified location
				  // or should we directly add a WebFrameView
				childView=[[[_WebHTMLDocumentView alloc] initWithFrame:newChildFrame] autorelease];
				[view addSubview:childView];
				subviewIndex++;
				}
#if 0
			NSLog(@"adjust subframe %u to (w=%f, h=%f) %@", subviewIndex, [colWidth floatValue], height, NSStringFromRect(newChildFrame));
			NSLog(@"element: %@", child);
			NSLog(@"view: %@", childView);
#endif
			[child _layout:childView];		// update layout of child (if DOMHTMLElement is present) to fit in new frame
			last.x+=newChildFrame.size.width;	// go to next
			}
		last.x=parentFrame.origin.x;	// set back
		last.y+=newHeight;
		}
	while([[view subviews] count] > subviewIndex)
		{ // delete any additional subviews we find
		[[[view subviews] lastObject] removeFromSuperviewWithoutNeedingDisplay];
		}
}

@end

@implementation DOMHTMLNoFramesElement

- (void) _addAttributesToStyle
{
	[_style setObject:@"block" forKey:DOMHTMLBlockInlineLevel];
}

@end

@implementation DOMHTMLFrameElement

- (void) _addAttributesToStyle
{
	[_style setObject:@"block" forKey:DOMHTMLBlockInlineLevel];
}

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
	return [[[DOMHTMLElement alloc] _initWithName:@"#dummy" namespaceURI:nil document:[[rep _root] ownerDocument]] autorelease];	// return dummy
}

	// FIXME!!!

- (void) _layout:(NSView *) view;
{
	NSString *name=[self getAttribute:@"name"];
	NSString *src=[self getAttribute:@"src"];
	NSString *border=[self getAttribute:@"frameborder"];
	NSString *width=[self getAttribute:@"marginwidth"];
	NSString *height=[self getAttribute:@"marginheight"];
	NSString *scrolling=[self getAttribute:@"scrolling"];
	BOOL noresize=[self hasAttribute:@"noresize"];
	WebFrame *frame;
	WebFrameView *frameView;
	WebView *webView=[[(DOMHTMLDocument *) [[self ownerDocument] lastChild] webFrame] webView];
#if 0
	NSLog(@"_layout: %@", self);
	NSLog(@"attribs: %@", [self _attributes]);
#endif
	if(![view isKindOfClass:[WebFrameView class]])
		{ // substitute with a WebFrameView
		frameView=[[WebFrameView alloc] initWithFrame:[view frame]];
		[[view superview] replaceSubview:view with:frameView];	// replace
		view=frameView;	// use new
		[frameView release];
		frame=[[[WebFrame alloc] initWithName:name
								 webFrameView:frameView
									  webView:webView] autorelease];	// allocate a new WebFrame
		[frameView _setWebFrame:frame];	// create and attach a new WebFrame
		[frame _setFrameElement:self];	// make a link
										//	[parentFrame _addChildFrame:frame];
		if(src)
			[frame loadRequest:[NSURLRequest requestWithURL:[self URLWithAttributeString:@"src"]]];
		}
	else
		{
		frameView=(WebFrameView *) view;
		frame=[frameView webFrame];		// get the webframe
		}
	[frame _setFrameName:name];	// we should be able to change the name if we were originally created from a partial file that stops right within the name argument...
								// FIXME: how to notify the scroll view for all three states: auto, yes, no?
	if([self hasAttribute:@"scrolling"])
		{
		if([scrolling caseInsensitiveCompare:@"auto"] == NSOrderedSame)
			{ // enable autoscroll
			[frameView setAllowsScrolling:YES];
			// hm...
			}
		else
			[frameView setAllowsScrolling:[scrolling _htmlBoolValue]];
		}
	else
		[frameView setAllowsScrolling:YES];	// default
	[frameView setNeedsDisplay:YES];
}

@end

@implementation DOMHTMLIFrameElement

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLNoNesting; }

- (NSTextAttachment *) _attachment;
{
	return nil;	// NSTextAttachmentCell which controls a NSTextView/NSWebFrameView that loads and renders its content
}

@end

@implementation DOMHTMLObjectFrameElement

- (void) _addAttributesToStyle
{
	[_style setObject:@"block" forKey:DOMHTMLBlockInlineLevel];
}

+ (DOMHTMLElement *) _designatedParentNode:(_WebHTMLDocumentRepresentation *) rep;
{ // find matching <table> node
	DOMHTMLElement *n=[rep _lastObject];
	while([n isKindOfClass:[DOMHTMLElement class]])
		{
		if([[n nodeName] isEqualToString:@"FRAMESET"])
			return (DOMHTMLElement *) n;
		n=(DOMHTMLElement *)[n parentNode];	// go one level up
		}	// no <table> found!
	return [[[DOMHTMLElement alloc] _initWithName:@"#dummy" namespaceURI:nil document:[[rep _root] ownerDocument]] autorelease];	// return dummy
}

@end

@implementation DOMHTMLBodyElement

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLSingletonNesting; }

+ (DOMHTMLElement *) _designatedParentNode:(_WebHTMLDocumentRepresentation *) rep;
{
	return [rep _html];
}

- (NSMutableDictionary *) _style;
{ // provide root styles
	NSColor *text=[[self getAttribute:@"text"] _htmlColor];
	if(!_style)
		{
		// FIXME: cache data until we are modified
		WebView *webView=[[(DOMHTMLDocument *) [[self ownerDocument] lastChild] webFrame] webView];
		NSFont *font=[NSFont fontWithName:DEFAULT_FONT size:DEFAULT_FONT_SIZE*[webView textSizeMultiplier]];	// determine default font
		NSMutableParagraphStyle *paragraph=[[NSMutableParagraphStyle new] autorelease];
		[paragraph setParagraphSpacing:DEFAULT_FONT_SIZE/2];	// default
		_style=[[NSMutableDictionary alloc] initWithObjectsAndKeys:
			paragraph, NSParagraphStyleAttributeName,
			font, NSFontAttributeName,
			self, WebElementDOMNodeKey,			// establish a reference into the DOM tree
			[(DOMHTMLDocument *) [[self ownerDocument] lastChild] webFrame], WebElementFrameKey,
			@"inline", DOMHTMLBlockInlineLevel,	// treat as inline (i.e. don't surround by \nl)
									// background color
			text, NSForegroundColorAttributeName,		// default text color - may be nil!
			nil];
#if 0
		NSLog(@"_style for <body> with attribs %@ is %@", [self _attributes], _style);
#endif
		}
	return _style;
}

// FIXME: this might need more elaboration

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

- (void) _layout:(NSView *) view;
{
	DOMHTMLDocument *htmlDocument=(DOMHTMLDocument *) [[self ownerDocument] lastChild];
	WebDataSource *source=[htmlDocument _webDataSource];
	NSString *anchor=[[[source response] URL] fragment];
	NSString *backgroundURL=[self getAttribute:@"background"];		// URL for background image
	NSColor *bg=[[self getAttribute:@"bgcolor"] _htmlColor];
	NSColor *link=[[self getAttribute:@"link"] _htmlColor];
	NSTextStorage *ts;
	NSScrollView *sc=[view enclosingScrollView];
#if 0
	NSLog(@"%@ _layout: %@", NSStringFromClass(isa), view);
	NSLog(@"attribs: %@", [self _attributes]);
#endif
	if(![view isKindOfClass:[_WebHTMLDocumentView class]])
		{ // add/substitute a new _WebHTMLDocumentView view to our parent (NSClipView)
		view=[[_WebHTMLDocumentView alloc] initWithFrame:(NSRect){ NSZeroPoint, [view frame].size }];	// create a new one with same frame
#if 0
		NSLog(@"replace document view %@ by %@", view, textView);
#endif
		[[[self webFrame] frameView] _setDocumentView:view];	// replace - and add whatever notifications the Scrollview needs
		[view release];
#if 0
		NSLog(@"textv=%@", view);
		NSLog(@"mask=%02x", [view autoresizingMask]);
		NSLog(@"horiz=%d", [view isHorizontallyResizable]);
		NSLog(@"vert=%d", [view isVerticallyResizable]);
		NSLog(@"webdoc=%@", [view superview]);
		NSLog(@"mask=%02x", [[view superview] autoresizingMask]);
		NSLog(@"clipv=%@", [[view superview] superview]);
		NSLog(@"mask=%02x", [[[view superview] superview] autoresizingMask]);
		NSLog(@"scrollv=%@", [[[view superview] superview] superview]);
		NSLog(@"mask=%02x", [[[[view superview] superview] superview] autoresizingMask]);
		NSLog(@"autohides=%d", [[[[view superview] superview] superview] autohidesScrollers]);
		NSLog(@"horiz=%d", [[[[view superview] superview] superview] hasHorizontalScroller]);
		NSLog(@"vert=%d", [[[[view superview] superview] superview] hasVerticalScroller]);
		NSLog(@"layoutManager=%@", [view layoutManager]);
		NSLog(@"textContainers=%@", [[view layoutManager] textContainers]);
#endif
		}
	ts=[(NSTextView *) view textStorage];
	[ts replaceCharactersInRange:NSMakeRange(0, [ts length]) withString:@""];	// clear current content
	[self _spliceTo:ts];	// translate DOM-Tree into attributed string
	[self _flushStyles];	// clear style cache in the DOM Tree
	[ts removeAttribute:DOMHTMLBlockInlineLevel range:NSMakeRange(0, [ts length])];	// release some memory
	
	// to handle <pre>:
	// scan through all paragraphs
	// find all non-breaking paras, i.e. those with lineBreakMode == NSLineBreakByClipping
	// determine unlimited width of any such paragraph
	// resize textView to MIN(clipView.width, maxWidth+2*inset)
	// also look for oversized attachments!

	// FIXME: we should recognize this element:
	// <meta name = "format-detection" content = "telephone=no">
	// as described at http://developer.apple.com/documentation/AppleApplications/Reference/SafariWebContent/UsingiPhoneApplications/chapter_6_section_3.html

	[self _processPhoneNumbers:ts];	// update content
	if([self hasAttribute:@"bgcolor"])
		{
		[(_WebHTMLDocumentView *) view setBackgroundColor:bg];
		[(_WebHTMLDocumentView *) view setDrawsBackground:bg != nil];
//	[(_WebHTMLDocumentView *) view setBackgroundImage:load from URL background];
#if 1	// WORKAROUND
	/* the next line is a workaround for the following problem:
		If we show HTML text that is longer than the scrollview it has a vertical scroller.
		Now, if a new page is loaded and the text is shorter and completely fits into the
		NSScrollView, the scroller is automatically hidden.
		Due to a bug we still have to fix, the NSTextView is not aware of this
		before the user resizes the enclosing WebView and NSScrollView.
		And, the background is only drawn for the not-wide-enough NSTextView.
		As a workaround, we set the background also for the ScrollView.
	*/
		if(bg) [sc setBackgroundColor:bg];
#endif
		}
	if([self hasAttribute:@"link"])
		[(_WebHTMLDocumentView *) view setLinkColor:link];	// change link color
	[(_WebHTMLDocumentView *) view setDelegate:[self webFrame]];	// should be someone who can handle clicks on links and knows the base URL
	if([anchor length] != 0)
		{ // locate a matching anchor
		unsigned idx, cnt=[ts length];
		for(idx=0; idx < cnt; idx++)
			{
			NSString *attr=[ts attribute:@"DOMHTMLAnchorElementAnchorName" atIndex:idx effectiveRange:NULL];
			if(attr && [attr isEqualToString:anchor])
				break;
			}
		if(idx < cnt)
			[(_WebHTMLDocumentView *) view scrollRangeToVisible:NSMakeRange(idx, 0)];	// jump to anchor
		}
	//	[view setMarkedTextAttributes: ]	// update for visited link color (assuming that we mark visited links)
	[sc tile];
	[sc reflectScrolledClipView:[sc contentView]];	// make scrollers autohide
#if 0	// show view hierarchy
	{
		NSView *parent;
		//	[textView display];
		NSLog(@"view hierarchy");
		NSLog(@"NSWindow=%@", [view window]);
		parent=view;
		while(parent)
			NSLog(@"%p: %@", parent, parent), parent=[parent superview];
	}
#endif	
}

@end

@implementation DOMHTMLDivElement

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLLazyNesting; }

- (void) _addAttributesToStyle;
{ // add attributes to style
	NSMutableParagraphStyle *paragraph=[[_style objectForKey:NSParagraphStyleAttributeName] mutableCopy];
	NSString *align=[self getAttribute:@"align"];
	if(align)
		[paragraph setAlignment:[align _htmlAlignment]];
	// and modify others...
	[_style setObject:@"block" forKey:DOMHTMLBlockInlineLevel];
	[_style setObject:[paragraph autorelease] forKey:NSParagraphStyleAttributeName];
}

@end

@implementation DOMHTMLSpanElement

- (void) _addAttributesToStyle;
{ // add attributes to style
	NSMutableParagraphStyle *paragraph=[[_style objectForKey:NSParagraphStyleAttributeName] mutableCopy];
	NSString *align=[self getAttribute:@"align"];
	if(align)
		[paragraph setAlignment:[align _htmlAlignment]];
	// and modify others...
	[_style setObject:[paragraph autorelease] forKey:NSParagraphStyleAttributeName];
}

@end

@implementation DOMHTMLCenterElement

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLLazyNesting; }

- (void) _addAttributesToStyle;
{ // add attributes to style
	NSMutableParagraphStyle *paragraph=[[_style objectForKey:NSParagraphStyleAttributeName] mutableCopy];
	NSString *align=[self getAttribute:@"align"];
	if(align)
		[paragraph setAlignment:[align _htmlAlignment]];
	[_style setObject:@"block" forKey:DOMHTMLBlockInlineLevel];
	// and modify others...
	[_style setObject:[paragraph autorelease] forKey:NSParagraphStyleAttributeName];
}

@end

@implementation DOMHTMLHeadingElement

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLLazyNesting; }

- (void) _addAttributesToStyle;
{ // add attributes to style
	NSMutableParagraphStyle *paragraph=[[_style objectForKey:NSParagraphStyleAttributeName] mutableCopy];
	int level=[[[self nodeName] substringFromIndex:1] intValue];
	WebView *webView=[[(DOMHTMLDocument *) [[self ownerDocument] lastChild] webFrame] webView];
	float size=DEFAULT_FONT_SIZE*[webView textSizeMultiplier];
	NSFont *f;
	NSString *align=[self getAttribute:@"align"];
	if(align)
		[paragraph setAlignment:[align _htmlAlignment]];
	[paragraph setHeaderLevel:level];	// if someone wants to convert the attributed string back to HTML...
	switch(level)
		{
		case 1:
			size *= 24.0/12.0;	// 12 -> 24
			break;
		case 2:
			size *= 18.0/12.0;	// 12 -> 18
			break;
		case 3:
			size *= 14.0/12.0;	// 12 -> 14
			break;
		default:
			break;	// standard
		}
	[paragraph setParagraphSpacing:size/2];
	f=[NSFont fontWithName:DEFAULT_BOLD_FONT size:size];
	if(f)
		[_style setObject:f forKey:NSFontAttributeName];	// set header font
	[_style setObject:@"block" forKey:DOMHTMLBlockInlineLevel];
	[_style setObject:[paragraph autorelease] forKey:NSParagraphStyleAttributeName];
}

@end

@implementation DOMHTMLPreElement

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLLazyNesting; }

- (void) _addAttributesToStyle;
{ // add attributes to style
	NSMutableParagraphStyle *paragraph=[[_style objectForKey:NSParagraphStyleAttributeName] mutableCopy];
	NSString *align=[self getAttribute:@"align"];
	// set monospaced font
	[paragraph setLineBreakMode:NSLineBreakByClipping];
	[_style setObject:@"block" forKey:DOMHTMLBlockInlineLevel];
	// and modify others...
	[_style setObject:[paragraph autorelease] forKey:NSParagraphStyleAttributeName];
}

@end

@implementation DOMHTMLFontElement

- (void) _addAttributesToStyle;
{ // add attributes to style
	WebView *webView=[[(DOMHTMLDocument *) [[self ownerDocument] lastChild] webFrame] webView];
	NSArray *names=[[self getAttribute:@"face"] componentsSeparatedByString:@","];	// is a comma separated list of potential font names!
	NSString *size=[self getAttribute:@"size"];
	NSColor *color=[[self getAttribute:@"color"] _htmlColor];
	NSFont *f=[_style objectForKey:NSFontAttributeName];	// style inherited from parent
	if([names count] > 0)
		{ // modify font family
		NSEnumerator *e=[names objectEnumerator];
		NSString *fname;
		while((fname=[e nextObject]))
			{
			NSFont *ff=[[NSFontManager sharedFontManager] convertFont:f toFamily:fname];	// try to convert
			if(ff && ff != f)
				{ // found a different font - replace
				f=ff;	// if we modify face AND size
				[_style setObject:ff forKey:NSFontAttributeName];
				break;	// found
				}
			}
		}
	if(size)
		{ // modify size
		float sz=[[_style objectForKey:NSFontAttributeName] pointSize];
		if([size hasPrefix:@"+"])
			{ // increase
			int s=[[size substringFromIndex:1] intValue];
			if(s > 7) s=7;
			while(s-- > 0)
				sz*=1.2;
			}
		else if([size hasPrefix:@"-"])
			{ // decrease
			int s=[[size substringFromIndex:1] intValue];
			if(s > 7) s=7;
			while(s-- > 0)
				sz*=1.0/1.2;
			}
		else
			{ // absolute
			int s=[size intValue];
			if(s > 7) s=7;
			if(s < 1) s=1;
			sz=12.0*[webView textSizeMultiplier];
			while(s > 3)
				sz*=1.2, s--;
			while(s < 3)
				sz*=1.0/1.2, s++;
			}
		f=[[NSFontManager sharedFontManager] convertFont:f toSize:sz];	// try to convert
		if(f)
			[_style setObject:f forKey:NSFontAttributeName];
		}
	if(color)
		[_style setObject:color forKey:NSForegroundColorAttributeName];
	// and modify others...
}

@end

@implementation DOMHTMLAnchorElement

#if FIXME
- (NSString *) _string;
{
	// if we are a simple anchor without content, add a nonadvancing space that can be the placeholder for the attributes
}

#endif

- (void) _addAttributesToStyle;
{ // add attributes to style
	NSString *urlString=[self getAttribute:@"href"];
	NSString *target=[self getAttribute:@"target"];	// WebFrame name where to show
	NSString *name=[self getAttribute:@"name"];
	NSString *charset=[self getAttribute:@"charset"];
	NSString *accesskey=[self getAttribute:@"accesskey"];
	NSString *shape=[self getAttribute:@"shape"];
	NSString *coords=[self getAttribute:@"coords"];
	if(urlString)
		{ // add a hyperlink
		NSCursor *cursor=[NSCursor pointingHandCursor];
		[_style setObject:urlString forKey:NSLinkAttributeName];	// set the link
		[_style setObject:cursor forKey:NSCursorAttributeName];	// set the cursor
		if(target)
			[_style setObject:target forKey:DOMHTMLAnchorElementTargetWindow];		// set the target window
		}
	if(!name)
		name=[self getAttribute:@"id"];	// XHTML alternative
	if(name)
		{ // add an anchor
		[_style setObject:name forKey:DOMHTMLAnchorElementAnchorName];	// set the cursor
		}
	// and modify others...
}

@end

@implementation DOMHTMLImageElement

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLNoNesting; }

	// 1. we need an official mechanism to postpone loading until we click on the image (e.g. for HTML mails)
	// 2. note that images have to be collected in DOMDocument so that we can access them through "document.images[index]"

- (IBAction) _imgAction:(id) sender;
{
	// make image load in separate window
	// we can also set the link attribute with the URL for the text attachment
}

- (void) _addAttributesToStyle;
{ // add attributes to style
	NSString *align=[self getAttribute:@"align"];
	NSString *urlString=[self getAttribute:@"src"];
	if(urlString && ![_style objectForKey:NSLinkAttributeName])
		{ // add a hyperlink with the image source
		NSCursor *cursor=[NSCursor pointingHandCursor];
		[_style setObject:urlString forKey:NSLinkAttributeName];	// set the link
		[_style setObject:cursor forKey:NSCursorAttributeName];	// set the cursor
// 		[_style setObject:target forKey:DOMHTMLAnchorElementTargetWindow];		// set the target window
		}
}

- (NSString *) string;
{ // if attachment can't be created
	return [self getAttribute:@"alt"];
}

- (NSTextAttachment *) _attachment;
{
	NSTextAttachment *attachment;
	NSCell *cell;
	NSImage *image=nil;
	NSFileWrapper *wrapper;
	NSString *src=[self getAttribute:@"src"];
	NSString *alt=[self getAttribute:@"alt"];
	NSString *height=[self getAttribute:@"height"];
	NSString *width=[self getAttribute:@"width"];
	NSString *border=[self getAttribute:@"border"];
	NSString *hspace=[self getAttribute:@"hspace"];
	NSString *vspace=[self getAttribute:@"vspace"];
	NSString *usemap=[self getAttribute:@"usemap"];
	NSString *name=[self getAttribute:@"name"];
	BOOL hasmap=[self hasAttribute:@"ismap"];
#if 0
	NSLog(@"<img>: %@", [self _attributes]);
#endif
	if(!src)
		return nil;	// can't show
	attachment=[NSTextAttachmentCell textAttachmentWithCellOfClass:[NSActionCell class]];
	cell=(NSCell *) [attachment attachmentCell];	// get the real cell
#if 0
	NSLog(@"cell attachment: %@", [cell attachment]);
#endif
	[cell setTarget:self];
	[cell setAction:@selector(_imgAction:)];
	// if([[webView preferences] loadsImagesAutomatically])
	{
		NSData *data=[self _loadSubresourceWithAttributeString:@"src" blocking:NO];	// get from cache or trigger loading (makes us the WebDocumentRepresentation)
	if(data)
		{ // we got some or all
		image=[[NSImage alloc] initWithData:data];	// try to get as far as we can
		[image setScalesWhenResized:YES];
		}
	}
	if(!image)
		{ // could not convert
		image=[[NSImage alloc] initWithContentsOfFile:[[NSBundle bundleForClass:isa] pathForResource:@"WebKitIMG" ofType:@"png"]];	// substitute default image
		[image setScalesWhenResized:NO];	// hm... does not really work
		}
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
- (void) finishedLoadingWithDataSource:(WebDataSource *) source; { return; }

- (void) receivedData:(NSData *) data withDataSource:(WebDataSource *) source;
{ // simply ask our NSTextView for a re-layout
	NSLog(@"%@ receivedData: %u", NSStringFromClass(isa), [[source data] length]);
	[_visualRepresentation setNeedsLayout:YES];
	[(NSView *) _visualRepresentation setNeedsDisplay:YES];
}

- (void) receivedError:(NSError *) error withDataSource:(WebDataSource *) source;
{ // default error handler
	NSLog(@"%@ receivedError: %@", NSStringFromClass(isa), error);
}

@end

@implementation DOMHTMLBRElement

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLNoNesting; }

- (NSString *) _string;		{ return @"\n"; }

- (void) _addAttributesToStyle
{ // <br> is an inline element
	NSMutableParagraphStyle *paragraph=[[_style objectForKey:NSParagraphStyleAttributeName] mutableCopy];
	[paragraph setParagraphSpacing:0.0];
	// and modify others...
	[_style setObject:[paragraph autorelease] forKey:NSParagraphStyleAttributeName];
}

@end

@implementation DOMHTMLParagraphElement

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLLazyNesting; }

- (NSString *) _string;		{ return @"\n"; }

- (void) _addAttributesToStyle;
{ // add attributes to style
	NSMutableParagraphStyle *paragraph=[[_style objectForKey:NSParagraphStyleAttributeName] mutableCopy];
	NSString *align=[self getAttribute:@"align"];
	[_style setObject:@"block" forKey:DOMHTMLBlockInlineLevel];
	if(align)
		[paragraph setAlignment:[align _htmlAlignment]];
	[paragraph setParagraphSpacing:6.0];
	// and modify others...
	[_style setObject:[paragraph autorelease] forKey:NSParagraphStyleAttributeName];
}

@end

@implementation DOMHTMLHRElement

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLNoNesting; }

- (void) _addAttributesToStyle
{
	[_style setObject:@"block" forKey:DOMHTMLBlockInlineLevel];
}

- (NSTextAttachment *) _attachment;
{
    NSTextAttachment *att;
    NSHRAttachmentCell *cell;
    int size;
    
    att = [NSTextAttachmentCell textAttachmentWithCellOfClass:[NSHRAttachmentCell class]];
    cell=(NSHRAttachmentCell *) [att attachmentCell];        // get the real cell
        
	[cell setShaded:![self hasAttribute:@"noshade"]];
	size = [[self getAttribute:@"size"] intValue];
    
	NSLog(@"<hr> size: %@", [self getAttribute:@"size"]);
    NSLog(@"<hr> width: %@", [self getAttribute:@"width"]);
    return att;
}

@end

@implementation DOMHTMLTableElement

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLLazyNesting; }

- (void) dealloc; { [table release]; [super dealloc]; }

- (void) _addAttributesToStyle;
{ // add attributes to style
	NSMutableParagraphStyle *paragraph=[[_style objectForKey:NSParagraphStyleAttributeName] mutableCopy];
	NSString *align=[[self getAttribute:@"align"] lowercaseString];
	NSString *alignchar=[self getAttribute:@"char"];
	NSString *offset=[self getAttribute:@"charoff"];
	NSString *width=[self getAttribute:@"width"];
	NSString *valign=[self getAttribute:@"valign"];
	NSString *background=[self getAttribute:@"background"];
	unsigned border=[[self getAttribute:@"border"] intValue];
	unsigned spacing=[[self getAttribute:@"cellspacing"] intValue];
	unsigned padding=[[self getAttribute:@"cellpadding"] intValue];
	unsigned cols=[[self getAttribute:@"cols"] intValue];
#if 0
	NSLog(@"<table>: %@", [self _attributes]);
#endif
	if([align isEqualToString:@"left"])
		[paragraph setAlignment:NSLeftTextAlignment];
	if([align isEqualToString:@"center"])
		[paragraph setAlignment:NSCenterTextAlignment];
	if([align isEqualToString:@"right"])
		[paragraph setAlignment:NSRightTextAlignment];
	if([align isEqualToString:@"justify"])
		[paragraph setAlignment:NSJustifiedTextAlignment];
	//			 if([align isEqualToString:@"char"])
	//				 [paragraph setAlignment:NSNaturalTextAlignment];
	table=[[NSClassFromString(@"NSTextTable") alloc] init];
	[table setHidesEmptyCells:YES];
	if(cols)
		[table setNumberOfColumns:cols];	// will be increased automatically as needed!
	[table setBackgroundColor:[NSColor whiteColor]];
	[table setBorderColor:[NSColor blackColor]];
	; // get from attributes...
	[table setWidth:border type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockBorder];	// border width
	[table setWidth:spacing type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockPadding];	// space between border and text
	; // NSTextBlockVerticalAlignment
	[_style setObject:table forKey:@"TableBlock"];	// pass a reference to the NSTextTableBlock of this table down to siblings
	// reset to default paragraph
	// reset font style, color etc. to defaults!
	[_style setObject:@"block" forKey:DOMHTMLBlockInlineLevel];	// is a block element
	[_style setObject:[paragraph autorelease] forKey:NSParagraphStyleAttributeName];	// update paragraph style
#if 0
	NSLog(@"<table> _style=%@", _style);
#endif
}

#if OLD
- (NSAttributedString *) attributedString;
{
	NSTextTable *textTable;
	Class textTableClass=NSClassFromString(@"NSTextTable");
	NSMutableAttributedString *str;
	DOMNodeList *children;
	unsigned int i, cnt;
#if 0
	NSLog(@"<table>: %@", [self _attributes]);
#endif
	if(!textTableClass)
		{ // we can't layout tables
		str=(NSMutableAttributedString *) [super attributedString];	// get content
		}
	else
		{ // use an NSTextTable object and add cells
		NSString *background=[self getAttribute:@"background"];
		NSString *width=[self getAttribute:@"width"];
		unsigned border=[[self getAttribute:@"border"] intValue];
		unsigned spacing=[[self getAttribute:@"cellspacing"] intValue];
		unsigned padding=[[self getAttribute:@"cellpadding"] intValue];
		unsigned cols=[[self getAttribute:@"cols"] intValue];
		unsigned row=1;
		unsigned col=1;
		// to handle all these attributes properly, we might need a subclass of NSTextTable to store them
		str=[[[NSMutableAttributedString alloc] initWithString:@"\n"] autorelease];	// finish last object
		textTable=[[textTableClass alloc] init];
		[textTable setHidesEmptyCells:YES];
		[textTable setNumberOfColumns:cols > 0?cols:0];	// will be increased automatically as needed!
		[textTable setBackgroundColor:[NSColor whiteColor]];
		[textTable setBorderColor:[NSColor blackColor]];
		// get from attributes...
		[textTable setWidth:1.0 type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockBorder];	// border width
		[textTable setWidth:2.0 type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockPadding];	// space between border and text
																								// NSTextBlockVerticalAlignment
		children=[self childNodes];
		cnt=[children length];	// should be a list of DOMHTMLTableRowElements
		for(i=0; i<cnt; i++)
			{
			if([[[children item:i] nodeName] isEqualToString:@"TBODY"])
				{ // FIXME: this is a hack to skip TBODY since we don't guarantee that it is available (which we should!)
				children=[[children item:i] childNodes];
				cnt=[children length];	// should be a list of DOMHTMLTableRowElements
				i=-1;
				continue;
				}
			if(str)
				[str appendAttributedString:[(DOMHTMLElement *) [children item:i] _tableCellsForTable:textTable row:&row col:&col]];
			}
		[(NSObject *) textTable release];
		[str appendAttributedString:[[[NSMutableAttributedString alloc] initWithString:@"\n"] autorelease]];	// finish table
		}
#if 0
	NSLog(@"<table>: %@", str);
#endif
	return str;
}
#endif

@end

@implementation DOMHTMLTBodyElement

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLSingletonNesting; }

+ (DOMHTMLElement *) _designatedParentNode:(_WebHTMLDocumentRepresentation *) rep;
{ // find matching <table> node
	DOMHTMLElement *n=[rep _lastObject];
	while([n isKindOfClass:[DOMHTMLElement class]])
		{
		if([[n nodeName] isEqualToString:@"TABLE"])
			return (DOMHTMLElement *) n;	// we have found the table node
		n=(DOMHTMLElement *)[n parentNode];	// go one level up
		}	// no <table> found!
	return [[[DOMHTMLElement alloc] _initWithName:@"#dummy#tbody" namespaceURI:nil document:[[rep _root] ownerDocument]] autorelease];	// return dummy table
}

@end

@implementation DOMHTMLTableRowElement

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
			tbe=[[[DOMHTMLTBodyElement alloc] _initWithName:@"TBODY" namespaceURI:nil document:[n ownerDocument]] autorelease];	// create new <tbody>
			[n appendChild:tbe];	// insert a fresh <tbody> element
			return tbe;
			}
		n=(DOMHTMLElement *)[n parentNode];	// go one level up
		}	// no <table> found!
	return [[[DOMHTMLElement alloc] _initWithName:@"#dummy#tr" namespaceURI:nil document:[[rep _root] ownerDocument]] autorelease];	// return dummy
}

- (void) _addAttributesToStyle;
{ // add attributes to style
	NSMutableParagraphStyle *paragraph=[[_style objectForKey:NSParagraphStyleAttributeName] mutableCopy];
	NSString *align=[[self getAttribute:@"align"] lowercaseString];
	NSString *alignchar=[self getAttribute:@"char"];
	NSString *offset=[self getAttribute:@"charoff"];
	NSString *valign=[self getAttribute:@"valign"];
	id blocks=[paragraph textBlocks];
	if([align isEqualToString:@"left"])
		[paragraph setAlignment:NSLeftTextAlignment];
	if([align isEqualToString:@"center"])
		[paragraph setAlignment:NSCenterTextAlignment];
	if([align isEqualToString:@"right"])
		[paragraph setAlignment:NSRightTextAlignment];
	if([align isEqualToString:@"justify"])
		[paragraph setAlignment:NSJustifiedTextAlignment];
	//			 if([align isEqualToString:@"char"])
	//				 [paragraph setAlignment:NSNaturalTextAlignment];
	[_style setObject:[paragraph autorelease] forKey:NSParagraphStyleAttributeName];
}

#if OLD
- (NSAttributedString *) _tableCellsForTable:(NSTextTable *) table row:(unsigned *) row col:(unsigned *) col;
{ // go down and merge
	NSMutableAttributedString *str=[[NSMutableAttributedString alloc] initWithString:@""];
	unsigned int i=0;
	unsigned maxrow=*row;
	//		NSString *align=[self getAttribute:@"align"];
	//	NSString *alignchar=[self getAttribute:@"char"];
	//	NSString *offset=[self getAttribute:@"charoff"];
	//	NSString *valign=[self getAttribute:@"valign"];
	*col=1;	// start over leftmost
	while(i<[_childNodes length])
		{ // should be <th> or <td> entries
		unsigned r=*row;	// have them all start on the same row
		[str appendAttributedString:[(DOMHTMLElement *) [_childNodes item:i++] _tableCellsForTable:table row:&r col:col]];
		if(r > *row)
			maxrow=r;	// determine maximum of all rowspans
		if(*col > [table numberOfColumns])
			[table setNumberOfColumns:*col];	// new max column
		}
	*row=maxrow;	// take maximum
	return str;
}

- (NSAttributedString *) attributedString;
{ // if we are called we can't use the NSTextTable mechanism - try the best with tabs and new line
	NSMutableAttributedString *str=[[NSMutableAttributedString alloc] initWithString:@"\n"];	// prefix and suffix with newline
	NSString *tag=[self nodeName];
	unsigned int i=0;
	while(i<[_childNodes length])
		{
		[str appendAttributedString:[(DOMHTMLElement *) [_childNodes item:i++] attributedString]];
		[str appendAttributedString:[[[NSAttributedString alloc] initWithString:(i == [_childNodes length])?@"\n":@"\t"] autorelease]];
		}
	// add a paragraph style
	return str;
}

#endif

@end

@implementation DOMHTMLTableCellElement

// + (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLLazyNesting; }

- (void) _addAttributesToStyle;
{ // add attributes to style
	NSMutableParagraphStyle *paragraph=[[_style objectForKey:NSParagraphStyleAttributeName] mutableCopy];
	NSString *axis=[self getAttribute:@"axis"];
	NSString *align=[[self getAttribute:@"align"] lowercaseString];
	NSString *valign=[[self getAttribute:@"valign"] lowercaseString];
	NSString *alignchar=[self getAttribute:@"char"];
	NSString *offset=[self getAttribute:@"charoff"];
	NSTextTable *table;	// the table we belong to
	NSMutableArray *blocks=[[paragraph textBlocks] mutableCopy];	// the text blocks
	NSTextTableBlock *cell;
	int row=1;	// where do we get this from??? we either have to ask our parent node or we need a special layout algorithm here
	int rowspan=[[self getAttribute:@"rowspan"] intValue];
	int col=1;
	int colspan=[[self getAttribute:@"colspan"] intValue];
	NSString *width=[self getAttribute:@"width"];	// in pixels or % of <table>
	if([[self nodeName] isEqualToString:@"TH"])
		{ // make centered and bold paragraph for header cells
		NSFont *f=[_style objectForKey:NSFontAttributeName];	// get current font
		f=[[NSFontManager sharedFontManager] convertFont:f toHaveTrait:NSBoldFontMask];
		if(f) [_style setObject:f forKey:NSFontAttributeName];
		[paragraph setAlignment:NSCenterTextAlignment];	// modify alignment
		}
	if([align isEqualToString:@"left"])
		[paragraph setAlignment:NSLeftTextAlignment];
	if([align isEqualToString:@"center"])
		[paragraph setAlignment:NSCenterTextAlignment];
	if([align isEqualToString:@"right"])
		[paragraph setAlignment:NSRightTextAlignment];
	if([align isEqualToString:@"justify"])
		[paragraph setAlignment:NSJustifiedTextAlignment];
	//			 if([align isEqualToString:@"char"])
	//				 [paragraph setAlignment:NSNaturalTextAlignment];
	table=[_style objectForKey:@"TableBlock"];	// inherited from enclosing table
	if(!table)
		return;	// error...
	cell=[[NSClassFromString(@"NSTextTableBlock") alloc] initWithTable:table
														   startingRow:row
															   rowSpan:rowspan
														startingColumn:col
															columnSpan:colspan];
	// get from attributes or inherit from parent/table
	[cell setBackgroundColor:[NSColor lightGrayColor]];
	[cell setBorderColor:[NSColor blackColor]];
	[cell setWidth:1.0 type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockBorder];	// border width
	[cell setWidth:2.0 type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockPadding];	// space between border and text
	[cell setWidth:2.0 type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockMargin];	// margin between cells
	if([valign isEqualToString:@"top"])
		// [block setVerticalAlignment:...]
		;
	if(col+colspan > [table numberOfColumns])
		[table setNumberOfColumns:col+colspan];			// adjust number of columns of our enclosing table
	if(!blocks)
		blocks=[NSMutableArray arrayWithCapacity:2];	// rarely more nesting
	[blocks addObject:cell];	// add to list of text blocks
	[paragraph setTextBlocks:blocks];	// add to paragraph style
#if 0
	NSLog(@"<td> _style=%@", _style);
#endif
	[_style setObject:[paragraph autorelease] forKey:NSParagraphStyleAttributeName];
}

@end

@implementation DOMHTMLFormElement

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLLazyNesting; }

- (void) _addAttributesToStyle;
{ // add attributes to style
	[_style setObject:@"block" forKey:DOMHTMLBlockInlineLevel];
	[_style setObject:self forKey:@"<form>"];	// make available to attributed string
}

- (void) submit:(id) sender;
{ // post current request
	NSMutableURLRequest *request;
	DOMHTMLDocument *htmlDocument;
	NSString *action;
	NSString *method;
	NSString *target;
	NSMutableData *body=nil;
	[self _triggerEvent:@"onsubmit"];
	// can the trigger abort sending?
	htmlDocument=(DOMHTMLDocument *) [[self ownerDocument] lastChild];	// may have been changed by script
	action=[self getAttribute:@"action"];
	method=[self getAttribute:@"method"];
	target=[self getAttribute:@"target"];
	if([method caseInsensitiveCompare:@"post"])
		body=[NSMutableData new];
	if(!action)
		action=@"";	// we simply reuse the current - FIXME: we should remove all ? components
					// walk through all input fields
	while(NO)
		{
		if(body)
			; // add to the body as [@"name=value\n" dataWithEncoding:]
		else
			; // append to URL as &name=value - add a ? for the first one if there is no ? component as part of the action
		}
	request=(NSMutableURLRequest *)[NSMutableURLRequest requestWithURL:[NSURL URLWithString:action relativeToURL:[[[htmlDocument _webDataSource] response] URL]]];
	if(method)
		[request setHTTPMethod:[method uppercaseString]];	// use default "GET" otherwise
	if(body)
		[request setHTTPBody:body];
	[body release];
#if 0
	NSLog(@"submit <form> to %@ using method %@", [request URL], [request HTTPMethod]);
#endif
	[request setMainDocumentURL:[[[htmlDocument _webDataSource] request] URL]];
	[[self webFrame] loadRequest:request];	// and submit the request
}

- (void) reset;
{
	[self _triggerEvent:@"onreset"];
	// clear all form entries
}

@end

@implementation DOMHTMLInputElement

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLNoNesting; }

- (void) _updateRadioButtonsWithName:(NSString *) name state:(BOOL) state;
{
	// recursively go down
}

- (NSTextAttachment *) _attachment;
{
	NSTextAttachment *attachment;
	NSCell *cell;
	NSString *type=[[self getAttribute:@"type"] lowercaseString];
	NSString *name=[self getAttribute:@"name"];
	NSString *val=[self getAttribute:@"value"];
	NSString *title=[self getAttribute:@"title"];
	NSString *placeholder=[self getAttribute:@"placeholder"];
	NSString *size=[self getAttribute:@"size"];
	NSString *maxlen=[self getAttribute:@"maxlength"];
	NSString *results=[self getAttribute:@"results"];
	NSString *autosave=[self getAttribute:@"autosave"];
	if([type isEqualToString:@"hidden"])
		{ // ignore for rendering purposes - will be collected when sending the <form>
		return nil;
		}
#if 0
	NSLog(@"<input>: %@", [self _attributes]);
#endif
	if([type isEqualToString:@"submit"] || [type isEqualToString:@"reset"] ||
	   [type isEqualToString:@"checkbox"] || [type isEqualToString:@"radio"] ||
	   [type isEqualToString:@"button"])
		attachment=[NSTextAttachmentCell textAttachmentWithCellOfClass:[NSButtonCell class]];
	else if([type isEqualToString:@"search"])
		attachment=[NSTextAttachmentCell textAttachmentWithCellOfClass:[NSSearchFieldCell class]];
	else if([type isEqualToString:@"password"])
		attachment=[NSTextAttachmentCell textAttachmentWithCellOfClass:[NSSecureTextFieldCell class]];
	else
		attachment=[NSTextAttachmentCell textAttachmentWithCellOfClass:[NSTextFieldCell class]];
	cell=(NSCell *) [attachment attachmentCell];	// get the real cell
	[cell setTarget:[_style objectForKey:@"<form>"]];
	[(NSTextFieldCell *) cell setAction:@selector(submit:)];
	[cell setEditable:![self hasAttribute:@"disabled"] && ![self hasAttribute:@"readonly"]];
	if([cell isKindOfClass:[NSTextFieldCell class]])
		{ // set text field, placeholder etc.
		[(NSTextFieldCell *) cell setBezeled:YES];
		[(NSTextFieldCell *) cell setStringValue: (val != nil) ? val : (NSString *)@""];
		// how to handle the size attribute?
		// an NSCell has no inherent size
		// should we pad the placeholder string?
		if([cell respondsToSelector:@selector(setPlaceholderString:)])
		   [(NSTextFieldCell *) cell setPlaceholderString:placeholder];
		}
	else
		{ // button
		[(NSButtonCell *) cell setButtonType:NSMomentaryLightButton];
		[(NSButtonCell *) cell setBezelStyle:NSRoundedBezelStyle];
		if([type isEqualToString:@"submit"])
			[(NSButtonCell *) cell setTitle:val?val: (NSString *)@"Submit"];
		else if([type isEqualToString:@"reset"])
			[(NSButtonCell *) cell setTitle:val?val: (NSString *)@"Cancel"];
		else if([type isEqualToString:@"checkbox"])
			{
			[(NSButtonCell *) cell setState:[self hasAttribute:@"checked"]];
			[(NSButtonCell *) cell setButtonType:NSSwitchButton];
			[(NSButtonCell *) cell setTitle:@""];
			}
		else if([type isEqualToString:@"radio"])
			{
			[(NSButtonCell *) cell setState:[self hasAttribute:@"checked"]];
			[(NSButtonCell *) cell setButtonType:NSRadioButton];
			[(NSButtonCell *) cell setTitle:@""];
			_visualRepresentation=(NSObject <WebDocumentView> *) cell;
			}
		else
			[(NSButtonCell *) cell setTitle:val?val:(NSString *)@"Button"];
		}
#if 0
	NSLog(@"  cell: %@", cell);
	NSLog(@"  cell control view: %@", [cell controlView]);
#endif
	return attachment;
}

@end

@implementation DOMHTMLButtonElement

- (NSTextAttachment *) _attachment;
{ // 
	NSMutableAttributedString *value=[[[NSMutableAttributedString alloc] init] autorelease];
	NSTextAttachment *attachment;
	NSButtonCell *cell;
	// search for enclosing <form> element to know how to set target/action etc.
	NSString *name=[self getAttribute:@"name"];
	NSString *size=[self getAttribute:@"size"];
	[(DOMHTMLElement *) [self firstChild] _spliceTo:value];	// recursively splice all child element strings into our value string
#if 0
	NSLog(@"<button>: %@", [self _attributes]);
#endif
	attachment=[NSTextAttachmentCell textAttachmentWithCellOfClass:[NSButtonCell class]];
	cell=(NSButtonCell *) [attachment attachmentCell];	// get the real cell
	[cell setBezelStyle:0];	// select a grey square button bezel by default
	[cell setAttributedTitle:value];	// formatted by contents between <buton> and </button>
	[cell setTarget:[_style objectForKey:@"<form>"]];
	[cell setAction:@selector(submit:)];
#if 0
	NSLog(@"  cell: %@", cell);
#endif
	return attachment;
}

- (NSString *) _string; { return nil; }	// don't process content

@end

@implementation DOMHTMLSelectElement

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLNoNesting; }

- (NSTextAttachment *) _attachment
{ // 
	NSTextAttachment *attachment;
	NSPopUpButtonCell *cell;
	// search for enclosing <form> element to know how to set target/action etc.
	NSString *name=[self getAttribute:@"name"];
	NSString *val=[self getAttribute:@"value"];
	NSString *size=[self getAttribute:@"size"];
	BOOL multiSelect=[self hasAttribute:@"multiple"];
	if(!val)
		val=@"";
#if 0
	NSLog(@"<button>: %@", [self _attributes]);
#endif
	if([size intValue] <= 1)
		{ // dropdown
		  // how to handle multiSelect flag?
		// we may have to use a private subclass that has our own selectItem which does not disable the previous
		attachment=[NSTextAttachmentCell textAttachmentWithCellOfClass:[NSPopUpButtonCell class]];
		cell=(NSPopUpButtonCell *) [attachment attachmentCell];	// get the real cell
		[cell setTitle:val];
		[cell setTarget:[_style objectForKey:@"<form>"]];
		[cell setAction:@selector(submit:)];
		// process children to get the option items
		// we could remove to return _string nil
		// and add [_style setObject:self forKey:@"<select>"]
		// and add [_style setObject:[cell menu] forKey:@"<select-menu>"]
		// and use that to add items when processed by OptGroup and OptionElement
		// this would allow to create submenus (if OptGroup overwrites select-menu)
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

- (NSString *) _string; { return nil; }	// don't process content

@end

// FIXME:

@implementation DOMHTMLOptionElement

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLLazyNesting; }

@end

@implementation DOMHTMLOptGroupElement

@end

@implementation DOMHTMLLabelElement

@end

// FIXME:

@implementation DOMHTMLTextAreaElement

- (NSTextAttachment *) _attachment;
{ // <textarea cols=xxx lines=yyy>value</textarea> 
	NSMutableAttributedString *value=[[[NSMutableAttributedString alloc] init] autorelease];
	NSTextAttachment *attachment;
	NSTextFieldCell *cell;
	// search for enclosing <form> element to know how to set target/action etc.
	NSString *name=[self getAttribute:@"name"];
	NSString *cols=[self getAttribute:@"cols"];
	NSString *lines=[self getAttribute:@"lines"];
	[(DOMHTMLElement *) [self firstChild] _spliceTo:value];	// recursively splice all child element strings into our value string
#if 0
	NSLog(@"<button>: %@", [self _attributes]);
#endif
	attachment=[NSTextAttachmentCell textAttachmentWithCellOfClass:[NSTextFieldCell class]];
	cell=(NSTextFieldCell *) [attachment attachmentCell];	// get the real cell
//	[cell setBezelStyle:0];	// select a grey square button bezel by default
	[cell setAttributedStringValue:value];	// formatted by contents between <textarea> and </textarea>
	[cell setTarget:[_style objectForKey:@"<form>"]];
	[cell setAction:@selector(submit:)];
#if 0
	NSLog(@"  cell: %@", cell);
#endif
	return attachment;
}

- (NSString *) _string; { return nil; }	// don't process content

@end

// FIXME:
// NSTextList is just descriptors. The Text system does interpret it only when (re)generating new-lines
// List entries are not automatically generated when building attributed strings!
// i.e. we must generate and store the marker string explicitly

@implementation DOMHTMLLIElement	// <li>, <dt>, <dd>

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLLazyNesting; }

- (NSString *) _string;
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

- (void) _addAttributesToStyle
{
	[_style setObject:@"block" forKey:DOMHTMLBlockInlineLevel];
	// modify paragraph head indent etc. so that we have proper indentation of the list entries
}

@end

@implementation DOMHTMLDListElement		// <dl>

- (void) _addAttributesToStyle
{
	NSMutableParagraphStyle *paragraph=[[_style objectForKey:NSParagraphStyleAttributeName] mutableCopy];
	NSString *align=[self getAttribute:@"align"];
	NSArray *lists=[paragraph textLists];	// get (nested) list
	NSTextList *list;
	// FIXME: decode HTML list formats and options and translate
	list=[[NSClassFromString(@"NSTextList") alloc] initWithMarkerFormat:@"\t" options:NSTextListPrependEnclosingMarker];
	if(list)
		{ // add initial list marker
		if(!lists) lists=[NSMutableArray new];	// start new one
		else lists=[lists mutableCopy];			// make mutable
		[(NSMutableArray *) lists addObject:list];
		[list release];
		[paragraph setTextLists:lists];
		}
#if 0
	NSLog(@"lists=%@", lists);
#endif
	[_style setObject:@"block" forKey:DOMHTMLBlockInlineLevel];
	[_style setObject:[paragraph autorelease] forKey:NSParagraphStyleAttributeName];
}

@end

@implementation DOMHTMLOListElement		// <ol>

- (void) _addAttributesToStyle;
{ 
  NSMutableParagraphStyle *paragraph=
    [[_style objectForKey:NSParagraphStyleAttributeName] mutableCopy];
  NSString *align=[self getAttribute:@"align"];
  NSArray *lists=[paragraph textLists];	// get (nested) list
  NSTextList *list;
  // add attributes to style

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
    }
#if 0
  NSLog(@"lists=%@", lists);
#endif
  [_style setObject: @"block" 
          forKey:DOMHTMLBlockInlineLevel];
  [_style setObject: [paragraph autorelease] 
          forKey: NSParagraphStyleAttributeName];
}

@end

@implementation DOMHTMLUListElement		// <ul>

- (void) _addAttributesToStyle;
{ // add attributes to style
  NSMutableParagraphStyle *paragraph=[[_style objectForKey:NSParagraphStyleAttributeName] mutableCopy];
  NSArray *lists=[paragraph textLists];	// get (nested) list
  NSTextList *list;
  
  // FIXME: decode list formats and options
  // e.g. change the marker style depending on nesting level disc -> circle -> hyphen
  
  list=[[NSClassFromString(@"NSTextList") alloc] initWithMarkerFormat:@"{disc}" options:0];
  if(list)
    {
      if(!lists) lists=[NSMutableArray new];	// start new one
      else lists=[lists mutableCopy];			// make mutable
      [(NSMutableArray *) lists addObject:list];
      [list release];
      [paragraph setTextLists:lists];
      [lists release];
    }
#if 0
  NSLog(@"lists=%@", lists);
#endif
  [_style setObject:@"block" forKey:DOMHTMLBlockInlineLevel];
  [_style setObject:[paragraph autorelease] forKey:NSParagraphStyleAttributeName];
}

@end

@implementation DOMHTMLCanvasElement		// <canvas>

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLNoNesting; }

@end
