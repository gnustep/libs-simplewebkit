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
// FIXME: we should separate code from DOM Tree management, HTML parsing, and visual representation

#import <WebKit/WebView.h>
#import <WebKit/WebResource.h>
#import "WebHTMLDocumentView.h"
#import "WebHTMLDocumentRepresentation.h"
#import "Private.h"

static NSString *DOMHTMLElementAttribute=@"DOMHTMLElementAttribute";
static NSString *DOMHTMLAnchorElementTargetWindow=@"DOMHTMLAnchorElementTargetName";
static NSString *DOMHTMLAnchorElementAnchorName=@"DOMHTMLAnchorElementAnchorName";

#if !defined(__APPLE__)

// surrogate declarations for headers of optional classes

@interface NSTextBlock : NSObject
- (void) setBackgroundColor:(NSColor *) color;
- (void) setBorderColor:(NSColor *) color;
- (void) setWidth:(float) width type:(int) type forLayer:(int) layer;
		 // FIXME: values must nevertheless match implementation in AppKit!
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

// read this from WebPreferences!

#define DEFAULT_FONT_SIZE 16.0
#define DEFAULT_FONT @"Times"
#define DEFAULT_BOLD_FONT @"Times-Bold"
#define DEFAULT_TT_SIZE 13.0
#define DEFAULT_TT_FONT @"Courier"

@implementation DOMElement (DOMHTMLElement)

+ (BOOL) _closeNotRequired; { return NO; }	// default implementation
+ (BOOL) _goesToHead;		{ return NO; }
+ (BOOL) _ignore;			{ return NO; }
+ (NSString *) _makeChildOf;	{ return nil; }
+ (BOOL) _singleton;			{ return NO; }

- (BOOL) _shouldSpliceNewline:(NSMutableAttributedString *) str;
{ // default - subclasses can also check if str ends with a newline and add one only if there isn't one or YES to force to add a new one
	return NO;	
}

- (void) _spliceTo:(NSMutableAttributedString *) str;
{ // splice node and subnodes taking end of last fragment into account
	unsigned i;
	if([self _shouldSpliceNewline:str])
		{ // yes, add a newline with same formatting as previous character
		NSRange range=NSMakeRange([str length], 0);	// append
		if([[str string] hasSuffix:@" "])
			range.location--, range.length++;	// remove final whitespace as well
		if(range.location != 0)
			[str replaceCharactersInRange:range withString:@"\n"];	// this operation inherits attributes of previous section
		else
			[str replaceCharactersInRange:range withString:@""];	// remove ending space character
		}
	for(i=0; i<[_childNodes length]; i++)
		[(DOMHTMLElement *) [_childNodes item:i] _spliceTo:str];	// splice child segments
}

- (NSAttributedString *) attributedString;
{ // get part as attributed string
	NSMutableAttributedString *str=[[[NSMutableAttributedString alloc] init] autorelease];
	[self _spliceTo:str];	// recursively splice all child element strings into our string
	return str;
}

- (WebFrame *) webFrame
{
	return [(DOMHTMLDocument *) [[self ownerDocument] lastChild] webFrame];
}

- (NSString *) outerHTML;
{
	NSString *str=[NSString stringWithFormat:@"<%@>\n%@", [self nodeName], [self innerHTML]];
	if(![isa _closeNotRequired])
		str=[str stringByAppendingFormat:@"</%@>\n", [self nodeName]];	// close
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

- (NSURL *) URLWithAttributeString:(NSString *) string;	// we don't inherit from DOMDocument...
{
	DOMHTMLDocument *htmlDocument=(DOMHTMLDocument *) [[self ownerDocument] lastChild];
	return [NSURL URLWithString:[self getAttribute:string] relativeToURL:[[[htmlDocument _webDataSource] response] URL]];
}

- (NSData *) _loadSubresourceWithAttributeString:(NSString *) string;
{
	DOMHTMLDocument *htmlDocument=(DOMHTMLDocument *) [[self ownerDocument] lastChild];
	WebDataSource *source=[htmlDocument _webDataSource];
	NSString *urlstring=[self getAttribute:string];
	NSURL *url=[[NSURL URLWithString:urlstring relativeToURL:[[source response] URL]] absoluteURL];
	if(url)
		{
		WebDataSource *sub;
		WebResource *res=[source subresourceForURL:url];
		if(res)
			{
#if 1
			NSLog(@"sub: completely loaded: %@ (%u bytes)", url, [[res data] length]);
#endif
			return [res data];	// already completely loaded
			}
		sub=[source _subresourceWithURL:url delegate:(id <WebDocumentRepresentation>) self];	// triggers loading if not yet and make me receive notification
#if 1
		NSLog(@"sub: loading: %@ (%u bytes)", url, [[sub data] length]);
#endif
		return [sub data];	// may return incomplete data or even nil!
		}
	return nil;
}

- (void) _layout:(NSView *) parent;
{
	NIMP;	// no default implementation!
}

- (NSMutableDictionary *) _style;
{ // get attributes to apply to this node, process appropriate CSS definition by tag, tag level, id, class, etc.
	NSString *node=[self nodeName];
	NSMutableDictionary *s;
	s=[(DOMHTMLElement *) _parentNode _style];	// inherit style from parent
	if(!s)
		{
		NSParagraphStyle *p;
		s=[NSMutableDictionary dictionary];	// empty (e.g. no parentNode)
		[s setObject:self forKey:WebElementDOMNodeKey];
		[s setObject:[(DOMHTMLDocument *) [[self ownerDocument] lastChild] webFrame] forKey:WebElementFrameKey];
		p=[[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
		[s setObject:p forKey:NSParagraphStyleAttributeName];
		//		WebElementIsSelected = 0; 
		//		WebElementTargetFrame = <WebFrame: 0x381780>; 
		}
	if([node isEqualToString:@"B"] || [node isEqualToString:@"STRONG"])
		{ // make bold
		NSFont *f=[s objectForKey:NSFontAttributeName];	// get current font
		f=[[NSFontManager sharedFontManager] convertFont:f toHaveTrait:NSBoldFontMask];
		if(f) [s setObject:f forKey:NSFontAttributeName];
		else NSLog(@"could not convert %ƒ to Bold", [s objectForKey:NSFontAttributeName]);
		}
	else if([node isEqualToString:@"I"] || [node isEqualToString:@"EM"] || [node isEqualToString:@"VAR"] || [node isEqualToString:@"CITE"])
		{ // make italics
		NSFont *f=[s objectForKey:NSFontAttributeName];	// get current font
		f=[[NSFontManager sharedFontManager] convertFont:f toHaveTrait:NSItalicFontMask];
		if(f) [s setObject:f forKey:NSFontAttributeName];
		else NSLog(@"could not convert %ƒ to Italics", [s objectForKey:NSFontAttributeName]);
		}
	else if([node isEqualToString:@"TT"] || [node isEqualToString:@"CODE"] || [node isEqualToString:@"KBD"] || [node isEqualToString:@"SAMP"])
		{ // make monospaced
		WebView *webView=[[(DOMHTMLDocument *) [[self ownerDocument] lastChild] webFrame] webView];
		NSFont *f=[s objectForKey:NSFontAttributeName];	// get current font
		f=[[NSFontManager sharedFontManager] convertFont:f toFamily:DEFAULT_TT_FONT];
		f=[[NSFontManager sharedFontManager] convertFont:f toSize:DEFAULT_TT_SIZE*[webView textSizeMultiplier]];
		if(f) [s setObject:f forKey:NSFontAttributeName];
		}
	else if([node isEqualToString:@"U"])
		{ // make underlined
#if defined(GNUSTEP) || MAC_OS_X_VERSION_10_2 >= MAC_OS_X_VERSION_MAX_ALLOWED
		[s setObject:[NSNumber numberWithInt:NSSingleUnderlineStyle] forKey:NSUnderlineStyleAttributeName];
#else	// MacOS X >= 10.3 and mySTEP
		[s setObject:[NSNumber numberWithInt:NSUnderlineStyleSingle] forKey:NSUnderlineStyleAttributeName];
#endif
		}
	else if([node isEqualToString:@"STRIKE"])
		{ // make strike-through
#if defined(GNUSTEP) || MAC_OS_X_VERSION_10_2 >= MAC_OS_X_VERSION_MAX_ALLOWED
		//		[s setObject:[NSNumber numberWithInt:NSSingleUnderlineStyle] forKey:NSStrikethroughStyleAttributeName];
#else	// MacOS X >= 10.3 and mySTEP
		[s setObject:[NSNumber numberWithInt:NSUnderlineStyleSingle] forKey:NSStrikethroughStyleAttributeName];
#endif		
		}
	else if([node isEqualToString:@"SUP"])
		{ // make superscript
		NSFont *f=[s objectForKey:NSFontAttributeName];	// get current font
		f=[[NSFontManager sharedFontManager] convertFont:f toSize:[f pointSize]/1.2];
		if(f) [s setObject:f forKey:NSFontAttributeName];
		[s setObject:[NSNumber numberWithInt:1] forKey:NSSuperscriptAttributeName];
		}
	else if([node isEqualToString:@"SUB"])
		{ // make subscript
		NSFont *f=[s objectForKey:NSFontAttributeName];	// get current font
		f=[[NSFontManager sharedFontManager] convertFont:f toSize:[f pointSize]/1.2];
		if(f)
			[s setObject:f forKey:NSFontAttributeName];
		[s setObject:[NSNumber numberWithInt:-1] forKey:NSSuperscriptAttributeName];
		}
	else if([node isEqualToString:@"BIG"])
		{ // make font larger +1
		NSFont *f=[s objectForKey:NSFontAttributeName];	// get current font
		[s setObject:[NSFont fontWithName:[f fontName] size:[f pointSize]*1.2] forKey:NSFontAttributeName];
		f=[[NSFontManager sharedFontManager] convertFont:f toSize:[f pointSize]*1.2];
		if(f) [s setObject:f forKey:NSFontAttributeName];
		}
	else if([node isEqualToString:@"SMALL"])
		{ // make font smaller -1
		NSFont *f=[s objectForKey:NSFontAttributeName];	// get current font
		f=[[NSFontManager sharedFontManager] convertFont:f toSize:[f pointSize]/1.2];
		if(f) [s setObject:f forKey:NSFontAttributeName];
		}
	// FIXME: apply (additional) CSS style processing here
	return s;
}

- (void) _triggerEvent:(NSString *) event;
{
	NSString *code=[self getAttribute:event];
	if(code)
		{
		// FIXME: make an event object available to the script
		[self evaluateWebScript:code];	// evaluate code defined by event attribute
		}
}

- (void) _elementDidAwakeFromDocumentRepresentation:(_WebDocumentRepresentation *) rep;
{ // subclasses should call [super _elementDidAwakeFromDocumentRepresentation:rep];
	[self _triggerEvent:@"onLoad"];
	return;
}

- (void) _elementLoaded; { return; } // ignore

@end

@implementation DOMHTMLElement
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

- (void) _spliceTo:(NSMutableAttributedString *) str;
{
	NSMutableString *s=[[[self data] mutableCopy] autorelease];
	[s replaceOccurrencesOfString:@"\r" withString:@"" options:0 range:NSMakeRange(0, [s length])];	// remove
	[s replaceOccurrencesOfString:@"\n" withString:@" " options:0 range:NSMakeRange(0, [s length])];	// convert to space
	[s replaceOccurrencesOfString:@"\t" withString:@" " options:0 range:NSMakeRange(0, [s length])];	// convert to space
#if QUESTIONABLE_OPTIMIZATION
	while([s replaceOccurrencesOfString:@"        " withString:@" " options:0 range:NSMakeRange(0, [s length])])	// convert long space sequences into single one
		;
#endif
	while([s replaceOccurrencesOfString:@"  " withString:@" " options:0 range:NSMakeRange(0, [s length])])	// convert double spaces into single one
		;	// trim multiple spaces as long as we find them
	if([s length] == 0)
		return;
	if([s hasPrefix:@" "])
		{ // remove any remaining initial space if str already ends with as space or a \n
		NSString *ss=[str string];
		if([ss hasSuffix:@" "] || [ss hasSuffix:@"\n"])
			[s deleteCharactersInRange:NSMakeRange(0, 1)];	// delete trailing space
		}
	[str appendAttributedString:[[[NSMutableAttributedString alloc] initWithString:s attributes:[(DOMHTMLElement *) _parentNode _style]] autorelease]];
}

- (void) _layout:(NSView *) parent;
{
	return;	// ignore if mixed with <frame> and <frameset> elements
}

@end

@implementation DOMCDATASection (DOMHTMLElement)

- (NSString *) outerHTML;
{
	return [NSString stringWithFormat:@"<!CDATA>\n%@\n</!CDATA>", [(DOMHTMLElement *)self innerHTML]];
}

- (void) _spliceTo:(NSMutableAttributedString *) str;
{ // ignore CData
}

@end

@implementation DOMComment (DOMHTMLElement)

- (NSString *) outerHTML;
{
	return [NSString stringWithFormat:@"<!-- %@ -->\n", [(DOMHTMLElement *)self innerHTML]];
}

- (void) _spliceTo:(NSMutableAttributedString *) str;
{ // ignore comments
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
+ (BOOL) _ignore;	{ return YES; }
@end

@implementation DOMHTMLHeadElement
+ (BOOL) _ignore;	{ return YES; }
+ (NSString *) _makeChildOf;	{ return @"html"; }
@end

@implementation DOMHTMLTitleElement
+ (BOOL) _goesToHead;	{ return YES; }

- (void) _elementDidAwakeFromDocumentRepresentation:(_WebDocumentRepresentation *) rep;
{
	[[(_WebHTMLDocumentRepresentation *) rep _parser] _setReadMode:2];	// switch parser mode to read up to </title> and translate entities
}
@end

@implementation DOMHTMLMetaElement

+ (BOOL) _closeNotRequired; { return YES; }
+ (BOOL) _goesToHead;	{ return YES; }

- (void) _elementDidAwakeFromDocumentRepresentation:(_WebDocumentRepresentation *) rep;
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
			NSURLRequest *request;
			NSTimeInterval seconds;
			if([[u lowercaseString] hasPrefix:@"url="])
				u=[u substringFromIndex:4];	// cut off url= prefix
			url=[NSURL URLWithString:u relativeToURL:[[[htmlDocument _webDataSource] response] URL]];
			seconds=[[c objectAtIndex:0] doubleValue];
#if 1
			NSLog(@"should redirect to %@ after %lf seconds", url, seconds);
#endif
			[[(DOMHTMLDocument *) [[self ownerDocument] lastChild] webFrame] _performClientRedirectToURL:url delay:seconds];
			}
		}
	[super _elementDidAwakeFromDocumentRepresentation:rep];
}

@end

@implementation DOMHTMLLinkElement

+ (BOOL) _closeNotRequired; { return YES; }
+ (BOOL) _goesToHead;	{ return YES; }

- (void) _elementDidAwakeFromDocumentRepresentation:(_WebDocumentRepresentation *) rep;
{ // e.g. <link rel="stylesheet" type="text/css" href="test.css" />
	NSString *rel=[[self getAttribute:@"rel"] lowercaseString];
	if([rel isEqualToString:@"stylesheet"] && [[self getAttribute:@"type"] isEqualToString:@"text/css"])
		{ // load stylesheet
		[self _loadSubresourceWithAttributeString:@"href"];
		// we don't stall here!
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

+ (BOOL) _goesToHead;	{ return YES; }

- (void) _elementDidAwakeFromDocumentRepresentation:(_WebDocumentRepresentation *) rep;
{
	[[(_WebHTMLDocumentRepresentation *) rep _parser] _setReadMode:1];	// switch parser mode to read up to </style>
}

// FIXME: process "@import URL" subresources

@end

@implementation DOMHTMLScriptElement

// FIXME: implement the WebDocumentRepresentation protocol

- (void) _spliceTo:(NSMutableAttributedString *) str;
{ // ignore scripts for rendering
}

- (void) _elementDidAwakeFromDocumentRepresentation:(_WebDocumentRepresentation *) rep;
{
	[[(_WebHTMLDocumentRepresentation *) rep _parser] _setReadMode:1];	// switch parser mode to read up to </script>
	if([self hasAttribute:@"src"])
		{ // external script to load
		[[(_WebHTMLDocumentRepresentation *) rep _parser] _stall:YES];	// make parser stall until we have loaded
		[self _loadSubresourceWithAttributeString:@"src"];	// trigger loading of script or get from cache
															// FIXME: clear only after we received the script!
		[[(_WebHTMLDocumentRepresentation *) rep _parser] _stall:NO];
		}
}

- (void) _elementLoaded;
{ // <script> element has been completely loaded, i.e. we are called from the </script> tag
	NSString *type=[self getAttribute:@"type"];	// should be "text/javascript" or "application/javascript"
	NSString *lang=[[self getAttribute:@"lang"] lowercaseString];	// optional language "JavaScript" or "JavaScript1.2"
	NSString *script;
	if(![type isEqualToString:@"text/javascript"] && ![type isEqualToString:@"application/javascript"] && ![lang hasPrefix:@"javascript"])
		return;	// ignore
	if([self hasAttribute:@"src"])
		{ // external script
		NSData *data=[self _loadSubresourceWithAttributeString:@"src"];	// get from cache
		script=[[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
		NSLog(@"external script: %@", script);
		}
	else
		script=[(DOMCharacterData *) [self firstChild] data];
	if(script)
		{ // not empty
		if([script hasPrefix:@"<!--"])
			script=[script substringFromIndex:4];	// remove
													// checkme: is it permitted to write <script><!CDATA[....?
		NSLog(@"evaluate <script>%@</script>", script);
		// FIXME: we should just parse the script and attach to the existing script tree, i.e. build function and statement nodes
		[[self ownerDocument] evaluateWebScript:script];	// try to parse and directly execute script in current document context
		}
}

// WebDocumentRepresentation callbacks

- (void) setDataSource:(WebDataSource *) dataSource; { return; }
- (void) finishedLoadingWithDataSource:(WebDataSource *) source; { return; }

- (void) receivedData:(NSData *) data withDataSource:(WebDataSource *) source;
{
	NSLog(@"%@ receivedData: %u", NSStringFromClass(isa), [[source data] length]);
	[_visualRepresentation setNeedsLayout:YES];
	[(NSView *) _visualRepresentation setNeedsDisplay:YES];
}

- (void) receivedError:(NSError *) error withDataSource:(WebDataSource *) source;
{ // default error handler
	NSLog(@"%@ receivedError: %@", NSStringFromClass(isa), error);
}

@end

@implementation DOMHTMLObjectElement

@end

@implementation DOMHTMLParamElement

@end

@implementation DOMHTMLNoFramesElement

- (void) _spliceTo:(NSMutableAttributedString *) str;
{ // ignore content
}

@end

@implementation DOMHTMLFrameSetElement

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
#if 1
	NSLog(@"_layout: %@", self);
	NSLog(@"attribs: %@", [self _attributes]);
#endif
	if(![view isKindOfClass:[_WebHTMLDocumentView class]])
		{ // add/substitute a new _WebHTMLDocumentFrameSetView view of same dimensions
		_WebHTMLDocumentFrameSetView *setView=[[_WebHTMLDocumentFrameSetView alloc] initWithFrame:parentFrame];
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
#if 1
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

@implementation DOMHTMLFrameElement

+ (BOOL) _closeNotRequired; { return YES; }

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
#if 1
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

- (void) _spliceTo:(NSMutableAttributedString *) str;
{ // make a NSTextAttachmentCell which controls a NSTextView (not part of the view hierarchy???) that loads and renders the frame
}

@end

@implementation DOMHTMLObjectFrameElement
@end

@implementation DOMHTMLBodyElement

+ (BOOL) _singleton;			{ return YES; }
+ (NSString *) _makeChildOf;	{ return @"html"; }

- (NSMutableDictionary *) _style;
{ // provide default styles
  // FIXME: cache data until we are modified
	WebView *webView=[[(DOMHTMLDocument *) [[self ownerDocument] lastChild] webFrame] webView];
	NSFont *font=[NSFont fontWithName:DEFAULT_FONT size:DEFAULT_FONT_SIZE*[webView textSizeMultiplier]];	// determine default font
	NSMutableParagraphStyle *paragraph=[[NSMutableParagraphStyle new] autorelease];
	//	NSColor *background=[[self getAttribute:@"background"] _htmlColor];	// not processed here
	//	NSColor *bgcolor=[[self getAttribute:@"bgcolor"] _htmlColor];
#if 0
	NSLog(@"_style for <body>: attribs=%@", [self _attributes]);
#endif
	return [NSMutableDictionary dictionaryWithObjectsAndKeys:
		paragraph, NSParagraphStyleAttributeName,
		font, NSFontAttributeName,
		// background color
		// default text color
		nil];
}

- (void) _layout:(NSView *) view;
{
	NSMutableAttributedString *str;
	
	// FIXME: how do we handle <pre> which should not respond to width changes?
	// maybe, by an NSParagraphStyle
	
#if 1
	NSLog(@"%@ _layout: %@", NSStringFromClass(isa), view);
	NSLog(@"attribs: %@", [self _attributes]);
#endif
	if(![view isKindOfClass:[_WebHTMLDocumentView class]])
		{ // add/substitute a new _WebHTMLDocumentView view to our parent (NSClipView)
		_WebHTMLDocumentView *textView=[[_WebHTMLDocumentView alloc] initWithFrame:[view frame]];
#if 1
		NSLog(@"replace document view %@ by %@", view, textView);
#endif
		[(NSClipView *) [view superview] setDocumentView:view];	// replace
		view=textView;	// use new
		[textView release];
#if 0
		NSLog(@"textv=%@", textView);
		NSLog(@"mask=%02x", [textView autoresizingMask]);
		NSLog(@"horiz=%d", [textView isHorizontallyResizable]);
		NSLog(@"vert=%d", [textView isVerticallyResizable]);
		NSLog(@"webdoc=%@", [textView superview]);
		NSLog(@"mask=%02x", [[textView superview] autoresizingMask]);
		NSLog(@"clipv=%@", [[textView superview] superview]);
		NSLog(@"mask=%02x", [[[textView superview] superview] autoresizingMask]);
		NSLog(@"scrollv=%@", [[[textView superview] superview] superview]);
		NSLog(@"mask=%02x", [[[[textView superview] superview] superview] autoresizingMask]);
		NSLog(@"autohides=%d", [[[[textView superview] superview] superview] autohidesScrollers]);
		NSLog(@"horiz=%d", [[[[textView superview] superview] superview] hasHorizontalScroller]);
		NSLog(@"vert=%d", [[[[textView superview] superview] superview] hasVerticalScroller]);
#endif
		}
	str=(NSMutableAttributedString *) [self attributedString];
#if 1
	NSLog(@"astr length for NSTextView=%u", [str length]);
#endif
#if 1
	NSLog(@"astr for NSTextView=%@", str);
#endif
	[[(NSTextView *) view textStorage] setAttributedString:str];	// update content
	[(NSTextView *) view setDelegate:[self webFrame]];	// should be someone who can handle clicks on links and knows the base URL
														//	[view setLinkTextAttributes: ]	// update for link color
														//	[view setMarkedTextAttributes: ]	// update for visited link color (assuming that we mark visited links)
	[view setNeedsDisplay:YES];
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

- (NSMutableDictionary *) _style;
{ // provide default styles
	NSMutableDictionary *s=[super _style];	// inherit style
	NSMutableParagraphStyle *paragraph=[s objectForKey:NSParagraphStyleAttributeName];
	NSString *align=[self getAttribute:@"align"];
	if(align)
		[paragraph setAlignment:[align _htmlAlignment]];
	// and modify others...
	return s;
}

- (BOOL) _shouldSpliceNewline:(NSMutableAttributedString *) str;
{
	return ![[str string] hasSuffix:@"\n"];	// did already end a paragraph
}

@end

@implementation DOMHTMLSpanElement

- (NSMutableDictionary *) _style;
{ // provide default styles
  // FIXME: cache result until we are modified
	NSMutableDictionary *s=[super _style];	// inherit style
	NSMutableParagraphStyle *paragraph=[s objectForKey:NSParagraphStyleAttributeName];
	NSString *align=[self getAttribute:@"align"];
	if(align)
		[paragraph setAlignment:[align _htmlAlignment]];
	// and modify others...
	return s;
}

@end

@implementation DOMHTMLCenterElement

- (NSMutableDictionary *) _style;
{
	NSMutableDictionary *s=[super _style];
	NSMutableParagraphStyle *paragraph=[s objectForKey:NSParagraphStyleAttributeName];
	if([[self nodeName] isEqualToString:@"CENTER"])
		[paragraph setAlignment:NSCenterTextAlignment];	// modify paragraph alignment
	else if([[self nodeName] isEqualToString:@"BLOCKQUOTE"])
		{
		[paragraph setFirstLineHeadIndent:[paragraph firstLineHeadIndent]+20.0];
		[paragraph setHeadIndent:[paragraph headIndent]+20.0];
		[paragraph setTailIndent:[paragraph tailIndent]-20.0];
		}
	return s;
}

- (BOOL) _shouldSpliceNewline:(NSMutableAttributedString *) str;
{
	return ![[str string] hasSuffix:@"\n"];	// did already end a paragraph
}

- (void) _spliceTo:(NSMutableAttributedString *) str;
{ // handle special cases
	[super _spliceTo:str];	// add content according to standard rules
	[str replaceCharactersInRange:NSMakeRange([str length], 0) withString:@"\n"];	// inherits previous attributes
}

@end

@implementation DOMHTMLHeadingElement

- (NSMutableDictionary *) _style;
{ // make header (bold)
	NSMutableDictionary *s=[super _style];
	NSMutableParagraphStyle *paragraph=[s objectForKey:NSParagraphStyleAttributeName];
	int level=[[[self nodeName] substringFromIndex:1] intValue];
	WebView *webView=[[(DOMHTMLDocument *) [[self ownerDocument] lastChild] webFrame] webView];
	float size=DEFAULT_FONT_SIZE*[webView textSizeMultiplier];
	NSFont *f;
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
	f=[NSFont fontWithName:DEFAULT_BOLD_FONT size:size];
	if(f)
		[s setObject:f forKey:NSFontAttributeName];	// set header font
	return s;
}

- (BOOL) _shouldSpliceNewline:(NSMutableAttributedString *) str;
{
	return ![[str string] hasSuffix:@"\n"];	// did already end a paragraph
}

- (void) _spliceTo:(NSMutableAttributedString *) str;
{ // handle special cases
	[super _spliceTo:str];	// add content according to standard rules
	[str replaceCharactersInRange:NSMakeRange([str length], 0) withString:@"\n"];	// inherits previous attributes
}

@end

@implementation DOMHTMLPreElement

- (NSMutableDictionary *) _style;
{
	NSMutableDictionary *s=[super _style];
	NSMutableParagraphStyle *paragraph=[s objectForKey:NSParagraphStyleAttributeName];
	// make monospaced and unlimited length and/or determine length from content
	return s;
}

- (BOOL) _shouldSpliceNewline:(NSMutableAttributedString *) str;
{
	return ![[str string] hasSuffix:@"\n"];	// did already end a paragraph
}

- (void) _spliceTo:(NSMutableAttributedString *) str;
{ // handle special cases
	[super _spliceTo:str];	// add content according to standard rules
	[str replaceCharactersInRange:NSMakeRange([str length], 0) withString:@"\n"];	// inherits previous attributes
}

@end

@implementation DOMHTMLFontElement

- (NSMutableDictionary *) _style;
{ // provide font styles
  // FIXME: cache result until we are modified
	WebView *webView=[[(DOMHTMLDocument *) [[self ownerDocument] lastChild] webFrame] webView];
	NSMutableDictionary *s=[super _style];	// inherit style
	NSArray *names=[[self getAttribute:@"face"] componentsSeparatedByString:@","];	// is a comma separated list of potential font names!
	NSString *size=[self getAttribute:@"size"];
	NSColor *color=[[self getAttribute:@"color"] _htmlColor];
	NSFont *f=[s objectForKey:NSFontAttributeName];	// style inherited from parent
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
				[s setObject:ff forKey:NSFontAttributeName];
				break;	// found
				}
			}
		}
	if(size)
		{ // modify size
		float sz=[[s objectForKey:NSFontAttributeName] pointSize];
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
			[s setObject:f forKey:NSFontAttributeName];
		}
	if(color)
		[s setObject:color forKey:NSForegroundColorAttributeName];
	// and modify others...
	return s;
}

@end

@implementation DOMHTMLAnchorElement

- (NSMutableDictionary *) _style;
{ // provide font styles
  // FIXME: cache result until we are modified
	NSMutableDictionary *s=[super _style];	// inherit style
	NSString *urlString=[self getAttribute:@"href"];
	NSString *target=[self getAttribute:@"target"];	// WebFrame name where to show
	if(urlString)
		{
		NSCursor *cursor=[NSCursor pointingHandCursor];
		[s setObject:urlString forKey:NSLinkAttributeName];	// set the link
		[s setObject:cursor forKey:NSCursorAttributeName];	// set the cursor
		if(target)
			[s setObject:target forKey:DOMHTMLAnchorElementTargetWindow];		// set the target window
		}
	return s;
}

- (void) _spliceTo:(NSMutableAttributedString *) str;
{ // 
  // check if we are an empty but named anchor
  // then, insert an invisible NSTextAttachmentCell
	[super _spliceTo:str];
}

#if OLD	// move as much as possible to to _style
- (NSAttributedString *) attributedString;
{
	NSMutableAttributedString *str=(NSMutableAttributedString *) [super attributedString];
	NSString *name=[self getAttribute:@"name"];
	NSString *charset=[self getAttribute:@"charset"];
	NSString *accesskey=[self getAttribute:@"accesskey"];
	NSString *shape=[self getAttribute:@"shape"];
	NSString *coords=[self getAttribute:@"coords"];
#if 0
	NSLog(@"<a>: %@", [self _attributes]);
#endif
	if(name)
		{ // named anchor
		  // how do we handle an empty anchor???
		[str addAttribute:DOMHTMLAnchorElementAnchorName value:name range:NSMakeRange(0, [str length])];		// set the anchor
		}
	return str;
}
#endif

@end

@implementation DOMHTMLImageElement

+ (BOOL) _closeNotRequired; { return YES; }

	// 1. we need an official mechanism to postpone loading until we click on the image (e.g. for HTML mails)
	// 2. note that images have to be collected in DOMDocument so that we can access them through "document.images[index]"

- (IBAction) _imgAction:(id) sender;
{
	// make image load in separate window
	// we can also set the link attribute with the URL for the text attachment
}

- (void) _spliceTo:(NSMutableAttributedString *) str;
{
	NSCell *cell;
	NSData *data;
	NSImage *image=nil;
	NSTextAttachment *attachment;
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
		{
		if(!alt) alt=@" <img> ";
		[str replaceCharactersInRange:NSMakeRange([str length], 0) withString:alt];
		return;
		}
	attachment=[NSTextAttachmentCell textAttachmentWithCellOfClass:[NSActionCell class]];
	cell=(NSCell *) [attachment attachmentCell];	// get the real cell
#if 0
	NSLog(@"cell attachment: %@", [cell attachment]);
#endif
	[cell setTarget:self];
	[cell setAction:@selector(_imgAction:)];
	data=[self _loadSubresourceWithAttributeString:@"src"];	// get from cache or trigger loading (makes us the WebDocumentRepresentation)
	if(data)
		{
		image=[[NSImage alloc] initWithData:data];	// try to get as far as we can
		[image setScalesWhenResized:YES];
		}
	if(!image)
		{
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
	[str appendAttributedString:[NSMutableAttributedString attributedStringWithAttachment:attachment]];
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

+ (BOOL) _closeNotRequired; { return YES; }

- (BOOL) _shouldSpliceNewline:(NSMutableAttributedString *) str;
{
	return YES;	// yes - always
}

@end

@implementation DOMHTMLParagraphElement

+ (BOOL) _closeNotRequired; { return YES; }

- (BOOL) _shouldSpliceNewline:(NSMutableAttributedString *) str;
{
	return YES;	// yes
}

- (NSMutableDictionary *) _style;
{ // provide default styles
  // FIXME: cache result until we are modified
	NSMutableDictionary *s=[super _style];	// inherit style
	NSMutableParagraphStyle *paragraph=[s objectForKey:NSParagraphStyleAttributeName];
	NSString *align=[self getAttribute:@"align"];
	if(align)
		[paragraph setAlignment:[align _htmlAlignment]];
	return s;
}

@end

@implementation DOMHTMLHRElement

+ (BOOL) _closeNotRequired; { return YES; }

- (BOOL) _shouldSpliceNewline:(NSMutableAttributedString *) str;
{
	return YES;
}

- (void) _spliceTo:(NSMutableAttributedString *) str;
{ // add a horizontal line element
	NSTextAttachment *attachment=[NSTextAttachmentCell textAttachmentWithCellOfClass:[NSHRAttachmentCell class]];
	NSHRAttachmentCell *cell=(NSHRAttachmentCell *) [attachment attachmentCell];	// get the real cell
	[str appendAttributedString:[NSMutableAttributedString attributedStringWithAttachment:attachment]];
}

@end

@implementation DOMHTMLTableElement

+ (BOOL) _closeNotRequired; { return NO; }	// be lazy

- (void) _elementDidAwakeFromDocumentRepresentation:(_WebDocumentRepresentation *) rep;	// node has just been decoded but not processed otherwise
{ // always create a tbody
	DOMHTMLTBodyElement *tbody=[[DOMHTMLTBodyElement alloc] _initWithName:@"TBODY" namespaceURI:nil document:[self ownerDocument]];
	[self appendChild:tbody];
}

- (void) dealloc; { [table release]; [super dealloc]; }

- (NSMutableDictionary *) _style;
{
	NSMutableDictionary *s=[super _style];
	NSMutableParagraphStyle *paragraph=[s objectForKey:NSParagraphStyleAttributeName];
	NSString *align=[[self getAttribute:@"align"] lowercaseString];
	NSString *alignchar=[self getAttribute:@"char"];
	NSString *offset=[self getAttribute:@"charoff"];
	NSString *width=[self getAttribute:@"width"];
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
	if(!table)
		{ // try to create and cache table element
		NSString *valign=[self getAttribute:@"valign"];
		NSString *background=[self getAttribute:@"background"];
		unsigned border=[[self getAttribute:@"border"] intValue];
		unsigned spacing=[[self getAttribute:@"cellspacing"] intValue];
		unsigned padding=[[self getAttribute:@"cellpadding"] intValue];
		unsigned cols=[[self getAttribute:@"cols"] intValue];
#if 1
		NSLog(@"<table>: %@", [self _attributes]);
#endif
		table=[[NSClassFromString(@"NSTextTable") alloc] init];
		if(table)
			{ // exists/was allocated
			[table setHidesEmptyCells:YES];
			if(cols) [table setNumberOfColumns:cols];	// will be increased automatically as needed!
			[table setBackgroundColor:[NSColor whiteColor]];
			[table setBorderColor:[NSColor blackColor]];
			// get from attributes...
			[table setWidth:1.0 type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockBorder];	// border width
			[table setWidth:2.0 type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockPadding];	// space between border and text
																								// NSTextBlockVerticalAlignment
			}
		}
	if(table) [s setObject:table forKey:@"<table>"];	// make available to lower table levels
														// we might also override the font attributes
#if 1
	NSLog(@"<table> _style=%@", s);
#endif
	return s;
}

- (BOOL) _shouldSpliceNewline:(NSMutableAttributedString *) str;
{
	return YES;
}

#if OLD
- (NSAttributedString *) attributedString;
{
	NSTextTable *textTable;
	Class textTableClass=NSClassFromString(@"NSTextTable");
	NSMutableAttributedString *str;
	DOMNodeList *children;
	unsigned int i, cnt;
#if 1
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
#if 1
	NSLog(@"<table>: %@", str);
#endif
	return str;
}
#endif

@end

@implementation DOMHTMLTBodyElement

+ (BOOL) _closeNotRequired;		{ return NO; }	// be lazy
+ (NSString *) _makeChildOf;	{ return @"table"; }

@end

@implementation DOMHTMLTableRowElement

+ (BOOL) _closeNotRequired;		{ return NO; }	// be lazy
+ (NSString *) _makeChildOf;	{ return @"tbody"; }

- (NSMutableDictionary *) _style;
{
	NSMutableDictionary *s=[super _style];
	NSMutableParagraphStyle *paragraph=[s objectForKey:NSParagraphStyleAttributeName];
	NSString *align=[[self getAttribute:@"align"] lowercaseString];
	NSString *alignchar=[self getAttribute:@"char"];
	NSString *offset=[self getAttribute:@"charoff"];
	NSString *valign=[self getAttribute:@"valign"];
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
#if 1
	NSLog(@"<tr> _style=%@", s);
#endif
	return s;
}

- (BOOL) _shouldSpliceNewline:(NSMutableAttributedString *) str;
{
	return YES;
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

+ (BOOL) _closeNotRequired;		{ return NO; }	// be lazy
+ (NSString *) _makeChildOf;	{ return @"tr"; }

- (void) dealloc; { [cell release]; [super dealloc]; }

- (NSMutableDictionary *) _style;
{ // derive default style within a cell
	NSMutableDictionary *s=[super _style];
	NSTextTable *table=[s objectForKey:@"<table>"];	// property should be inherited from enclosing DOMHTMLTableNode
	NSMutableParagraphStyle *paragraph=[s objectForKey:NSParagraphStyleAttributeName];
	NSString *axis=[self getAttribute:@"axis"];
	NSString *align=[[self getAttribute:@"align"] lowercaseString];
	NSString *valign=[[self getAttribute:@"valign"] lowercaseString];
	NSString *alignchar=[self getAttribute:@"char"];
	NSString *offset=[self getAttribute:@"charoff"];
	int row=1;	// where do we get this from??? we either have to ask our parent node or we need a special layout algorithm here
	int rowspan=[[self getAttribute:@"rowspan"] intValue];
	int col=1;
	int colspan=[[self getAttribute:@"colspan"] intValue];
	NSString *width=[self getAttribute:@"width"];	// in pixels or % of <table>
	if([[self nodeName] isEqualToString:@"TH"])
		{ // make centered and bold paragraph for header cells
		NSFont *f=[s objectForKey:NSFontAttributeName];	// get current font
		f=[[NSFontManager sharedFontManager] convertFont:f toHaveTrait:NSBoldFontMask];
		if(f) [s setObject:f forKey:NSFontAttributeName];
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
	if(!cell)
		{ // needs to allocate one
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
			[table setNumberOfColumns:col+colspan];	// adjust number of columns of our enclosing table
		}
	if(cell)
		[paragraph setTextBlocks:[NSArray arrayWithObject:cell]];	// add to paragraph style
#if 1
	NSLog(@"<td> _style=%@", s);
#endif
	return s;
}

- (BOOL) _shouldSpliceNewline:(NSMutableAttributedString *) str;
{
	return YES;
}

@end

@implementation DOMHTMLFormElement

- (NSMutableDictionary *) _style;
{
	NSMutableDictionary *s=[super _style];
	[s setObject:self forKey:@"<form>"];	// make available to attributed string
	return s;
}

- (void) submit;
{ // post current request
	NSMutableURLRequest *request;
	DOMHTMLDocument *htmlDocument;
	NSString *action;
	NSString *method;
	NSString *target;
	NSMutableData *body=nil;
	[self _triggerEvent:@"onsubmit"];
	// can the script abort sending?
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
#if 1
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

+ (BOOL) _closeNotRequired; { return YES; }

- (void) _updateRadioButtonsWithName:(NSString *) name state:(BOOL) state;
{
	// recursively go down
}

- (IBAction) _formAction:(id) sender;
{
	// find the enclosing <form>
	// if it is a radio button, update the state of the others with the same name
	// for doing that we must be able to attach the visual rep to a node
	// and recursively go down
	// collect all values
	// POST
}

- (void) _spliceTo:(NSMutableAttributedString *) str;
{ // 
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
		return;
		}
#if 1
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
	[(NSTextFieldCell *) cell setTarget:self];
	[(NSTextFieldCell *) cell setAction:@selector(_formAction:)];
	[cell setEditable:![self hasAttribute:@"disabled"] && ![self hasAttribute:@"readonly"]];
	if([cell isKindOfClass:[NSTextFieldCell class]])
		{ // set text field, placeholder etc.
		[(NSTextFieldCell *) cell setBezeled:YES];
		[(NSTextFieldCell *) cell setStringValue:val?val:@""];
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
			[(NSButtonCell *) cell setTitle:val?val:@"Submit"];
		else if([type isEqualToString:@"reset"])
			[(NSButtonCell *) cell setTitle:val?val:@"Cancel"];
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
			[(NSButtonCell *) cell setTitle:val?val:@"Button"];
		}
#if 1
	NSLog(@"  cell: %@", cell);
	NSLog(@"  cell control view: %@", [cell controlView]);
#endif
	[str appendAttributedString:[NSMutableAttributedString attributedStringWithAttachment:attachment]];
	//	[str addAttribute:DOMHTMLElementAttribute value:self range:NSMakeRange(0, [str length])];
#if 1
	NSLog(@"  str: %@", str);
#endif
}

@end

@implementation DOMHTMLButtonElement

- (IBAction) _formAction:(id) sender;
{
	// find the enclosing <form>
	// collect all values
	// POST
}

- (void) _spliceTo:(NSMutableAttributedString *) str;
{ // 
	NSMutableAttributedString *value=[[[NSMutableAttributedString alloc] init] autorelease];
	NSTextAttachment *attachment;
	NSButtonCell *cell;
	// search for enclosing <form> element to know how to set target/action etc.
	NSString *name=[self getAttribute:@"name"];
	NSString *size=[self getAttribute:@"size"];
	// ?? NSString *val=[self getAttribute:@"value"];
	[self _spliceTo:value];	// recursively splice all child element strings into our string
#if 1
	NSLog(@"<button>: %@", [self _attributes]);
#endif
	attachment=[NSTextAttachmentCell textAttachmentWithCellOfClass:[NSButtonCell class]];
	cell=(NSButtonCell *) [attachment attachmentCell];	// get the real cell
	[cell setBezelStyle:0];	// select a grey square button bezel by default
	[cell setAttributedTitle:value];	// formatted by contents between <buton> and </button>
	[cell setTarget:self];
	[cell setAction:@selector(_formAction:)];
#if 1
	NSLog(@"  cell: %@", cell);
#endif
	[str appendAttributedString:[NSMutableAttributedString attributedStringWithAttachment:attachment]];
	// [str addAttribute:DOMHTMLElementAttribute value:self range:NSMakeRange(0, [str length])];
}

@end

@implementation DOMHTMLSelectElement

- (void) _spliceTo:(NSMutableAttributedString *) str;
{ // 
	NSTextAttachment *attachment;
	NSCell *cell;
	// search for enclosing <form> element to know how to set target/action etc.
	NSString *name=[self getAttribute:@"name"];
	NSString *val=[self getAttribute:@"value"];
	NSString *size=[self getAttribute:@"size"];
	BOOL multiSelect=[self hasAttribute:@"multiple"];
	if(!val)
		val=@"";
#if 1
	NSLog(@"<button>: %@", [self _attributes]);
#endif
	if([size intValue] <= 1)
		{ // dropdown
		  // how to handle multiSelect flag?
		attachment=[NSTextAttachmentCell textAttachmentWithCellOfClass:[NSPopUpButtonCell class]];
		cell=(NSCell *) [attachment attachmentCell];	// get the real cell
		[cell setTitle:val];
		[cell setTarget:self];
		[cell setAction:@selector(_formAction:)];
		}
	else
		{ // embed NSTableView with [size intValue] visible lines
		attachment=nil;
		cell=nil;
		}
#if 1
	NSLog(@"  cell: %@", cell);
#endif
	[str appendAttributedString:[NSMutableAttributedString attributedStringWithAttachment:attachment]];
	//	[str addAttribute:DOMHTMLElementAttribute value:self range:NSMakeRange(0, [str length])];
}

@end

@implementation DOMHTMLOptionElement
@end

@implementation DOMHTMLOptGroupElement
@end

@implementation DOMHTMLLabelElement
@end

@implementation DOMHTMLTextAreaElement

- (void) _spliceTo:(NSMutableAttributedString *) str;
{ // 
	NSAttributedString *value=[self attributedString];	// get content between <textarea> and </textarea>
	NSString *name=[self getAttribute:@"name"];
	NSString *size=[self getAttribute:@"cols"];
	NSString *type=[self getAttribute:@"lines"];
#if 1
	NSLog(@"<textarea>: %@", [self _attributes]);
#endif
	// we should create a NSTextAttachment which includes an NSTextField with scrollbar (!) that is initialized with str
	//	return [NSMutableAttributedString attributedStringWithAttachment:];
}

@end

@implementation DOMHTMLLIElement	// <li>, <dt>, <dd>

+ (BOOL) _closeNotRequired; { return YES; }

- (BOOL) _shouldSpliceNewline:(NSMutableAttributedString *) str;
{
	return YES;
}

@end

@implementation DOMHTMLDListElement		// <dl>
@end

@implementation DOMHTMLOListElement		// <ol>

- (NSMutableDictionary *) _style;
{ // derive default style within a cell
	NSMutableDictionary *s=[super _style];
	NSMutableParagraphStyle *paragraph=[s objectForKey:NSParagraphStyleAttributeName];
	NSArray *lists=[paragraph textLists];	// get (nested) list
	NSTextList *list;
	if(!lists) lists=[NSMutableArray new];	// start new one
	else lists=[lists mutableCopy];			// make mutable
	// FIXME: decode list formats and options
	// NSTextListPrependEnclosingMarker
	list=[[NSClassFromString(@"NSTextList") alloc] initWithMarkerFormat:@"{decimal}." options:0];
	if(list)
		{
		[(NSMutableArray *) lists addObject:list];
		[list release];
		[paragraph setTextLists:lists];
		}
#if 1
	NSLog(@"lists=%@", lists);
#endif
	[lists release];
	return s;	// paragraph style has been adjusted
}

@end

@implementation DOMHTMLUListElement		// <ul>

- (NSMutableDictionary *) _style;
{ // derive default style within a cell
	NSMutableDictionary *s=[super _style];
	NSMutableParagraphStyle *paragraph=[s objectForKey:NSParagraphStyleAttributeName];
	NSArray *lists=[paragraph textLists];	// get (nested) list
	NSTextList *list;
	if(!lists) lists=[NSMutableArray new];	// start new one
	else lists=[lists mutableCopy];			// make mutable

		// FIXME: decode list formats and options
		// e.g. change the marker style depending on level
		// NSTextListPrependEnclosingMarker
		
	list=[[NSClassFromString(@"NSTextList") alloc] initWithMarkerFormat:@"{circle}" options:0];
	if(list)
		{
		[(NSMutableArray *) lists addObject:list];
		[list release];
		[paragraph setTextLists:lists];
		}
#if 1
	NSLog(@"lists=%@", lists);
#endif
	return s;	// paragraph style has been adjusted
}

@end
