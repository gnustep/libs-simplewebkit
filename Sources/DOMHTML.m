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
#import <WebKit/WebPreferences.h>
#import "WebHTMLDocumentView.h"
#import "WebHTMLDocumentRepresentation.h"
#import "Private.h"

NSString *DOMHTMLAnchorElementTargetWindow=@"DOMHTMLAnchorElementTargetName";
NSString *DOMHTMLAnchorElementAnchorName=@"DOMHTMLAnchorElementAnchorName";
NSString *DOMHTMLBlockInlineLevel=@"display";

#if !defined (GNUSTEP) && !defined (__mySTEP__)
#if (MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_3)	

// Tiger (10.4) and later - include (through WebKit/WebView.h and Cocoa/Cocoa.h) and implements Tables

#else

// declarations for headers of classes introduced in OSX 10.4 (#import <NSTextTable.h>) on systems that don't have it

@interface NSTextBlock : NSObject <NSCoding, NSCopying>
- (void) setBackgroundColor:(NSColor *) color;
- (void) setBorderColor:(NSColor *) color;
- (void) setWidth:(float) width type:(int) type forLayer:(int) layer;

// NOTE: values must match implementation in Apple AppKit!

#define NSTextBlockBorder 0
#define NSTextBlockPadding -1
#define NSTextBlockMargin 1

#define NSTextBlockAbsoluteValueType 0
#define NSTextBlockPercentageValueType 1

#define NSTextBlockTopAlignment	0
#define NSTextBlockMiddleAlignment 1
#define NSTextBlockBottomAlignment 2
#define NSTextBlockBaselineAlignment 3

#define NSTextBlockWidth	0
#define NSTextBlockMinimumWidth	1
#define NSTextBlockMaximumWidth	2
#define NSTextBlockHeight	4
#define NSTextBlockMinimumHeight	5
#define NSTextBlockMaximumHeight	6

#define NSTextTableAutomaticLayoutAlgorithm	0
#define NSTextTableFixedLayoutAlgorithm	1

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

enum
{
    NSTextListPrependEnclosingMarker = 1
};

@interface NSParagraphStyle (NSTextBlock)
- (NSArray *) textBlocks;
- (NSArray *) textLists;
@end

@interface SWKTextTableCell : NSTextAttachmentCell
{
	NSAttributedString *table;
}
@end

@implementation NSParagraphStyle (NSTextBlock)
- (NSArray *) textBlocks; { return nil; }
- (NSArray *) textLists; { return nil; }
@end

@interface NSMutableParagraphStyle (NSTextBlock)
- (void) setTextBlocks:(NSArray *) array;
- (void) setTextLists:(NSArray *) array;
@end

@implementation NSMutableParagraphStyle (NSTextBlock)
- (void) setTextBlocks:(NSArray *) array; { return; }	// ignore
- (void) setTextLists:(NSArray *) array; { return; }	// ignore
@end

@implementation SWKTextTableCell

// when asked to draw, analyse the table blocks and draw a table

@end

#endif
#endif

@interface DOMHTMLFormElement (Private)
- (void) _submitForm:(DOMHTMLElement *) clickedElement;
@end

@interface DOMCSSValue (Private)
- (NSString *) _toString;
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

@implementation NSString (HTMLAttributes)

- (BOOL) _htmlBoolValue;
{
	if([self length] == 0)
		return YES;	// pure existence means YES
	if([[self lowercaseString] isEqualToString:@"yes"])
		return YES;
	return NO;
}

- (NSColor *) _htmlNamedColor;
{ // look up in catalog
	static NSMutableDictionary *list;
	if(!list)
		{ // load color list (based on table 4.3 in http://www.w3.org/TR/css3-color/) from resource file
			NSDictionary *dict=[NSDictionary dictionaryWithContentsOfFile:[[NSBundle bundleForClass:[DOMHTMLElement class]] pathForResource:@"DOMHTMLColors" ofType:@"plist"]];
			NSEnumerator *e=[dict keyEnumerator];
			NSString *color;
			list=[[NSMutableDictionary alloc] initWithCapacity:[dict count]];
			while((color=[e nextObject]))
				{
				NSColor *c=[[dict objectForKey:color] _htmlColor];	 // try to translate (may be recursive!)
				if(c)
					[list setObject:c forKey:color];
				}
		}
	return [list objectForKey:[self lowercaseString]];
}

- (NSColor *) _htmlColor;
{
	unsigned hex;
	NSScanner *sc=[NSScanner scannerWithString:self];
	if([sc scanString:@"#" intoString:NULL] && [sc scanHexInt:&hex])
		{ // hex string
			if([self length] <= 4)	// short hex - convert into full value
				return [NSColor colorWithCalibratedRed:((hex>>8)&0xf)/15.0 green:((hex>>4)&0xf)/15.0 blue:(hex&0xf)/15.0 alpha:1.0];
			return [NSColor colorWithCalibratedRed:((hex>>16)&0xff)/255.0 green:((hex>>8)&0xff)/255.0 blue:(hex&0xff)/255.0 alpha:1.0];
		}
	return [self _htmlNamedColor];
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
			strech+=1.0;	// count number of '*' positions
		else
			{
			width=[element floatValue];
			if(width > 0.0)
				total+=width;	// accumulate
			}
		}
	if(strech > 0)
		{
		strech=(100.0-total)/strech;	// how much is missing to 100% for each *
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

// - (DOMNodeList *) childNodes;
// - (DOMElement *) cloneNode:(BOOL) deep;
- (DOMElement *) firstChild; { return [elements objectAtIndex:0]; }
- (BOOL) hasChildNodes; { return [elements count] > 0; }
// - (DOMElement *) insertBefore:(DOMElement *) node :(DOMElement *) ref;
- (DOMElement *) lastChild; { return [elements lastObject]; }
// - (DOMElement *) nextSibling;
// - (DOMElement *) previousSibling;
- (DOMElement *) removeChild:(DOMNode *) node; { [elements removeObject:node]; return (DOMElement *) self; }
// - (DOMElement *) replaceChild:(DOMNode *) node :(DOMNode *) old;

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
	if([[self class] _nesting] != DOMHTMLNoNesting)
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
// what happens if we set e.g. <head>, <script>, <frame> etc.?

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
	NSString *display=[style objectForKey:DOMHTMLBlockInlineLevel];
	// FIXME: check for display: none here (and avoid all other processing)
	NSTextAttachment *attachment=[self _attachment];	// may be nil
	NSString *string=[self _string];	// may be nil
	NSString *lastDisplay=[str length]>0 ? [str attribute:DOMHTMLBlockInlineLevel atIndex:[str length]-1 effectiveRange:NULL]:nil;
	BOOL lastIsInline=[lastDisplay isEqualToString:@"inline"];
	BOOL isInline=[display isEqualToString:@"inline"];
	if([display isEqualToString:@"none"])
		return;	// display: none style
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
		{ // if not nil
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
				//		[_style setObject:self forKey:WebElementDOMNodeKey];	// establish a reference to ourselves into the DOM tree
				//		[_style setObject:[self webFrame] forKey:WebElementFrameKey];
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

// FIXME: make this a category that collects all code for DOMHTML/DOMCSS -> NSAttributedString translation

- (void) _addCSSToStyle:(DOMCSSStyleDeclaration *) style;
{
	NSDictionary *dict=[style _items];	// get dictionary
	NSString *key;
	NSEnumerator *e=[dict keyEnumerator];
#if 1
	NSLog(@"merge %@ into %@", style, _style);
#endif
	while((key=[e nextObject]))
		{
		DOMCSSValue *val=[dict objectForKey:key];
		if([val cssValueType] == DOM_CSS_INHERIT)
			continue;	// skip (because parent node defines value)
		if([key isEqualToString:@"color"])
			{
			NSColor *color;
			if([val cssValueType] == DOM_CSS_PRIMITIVE_VALUE && [(DOMCSSPrimitiveValue *) val primitiveType] == DOM_CSS_RGBCOLOR)
				{ // special optimization
				unsigned hex=[(DOMCSSPrimitiveValue *) val getFloatValue:DOM_CSS_RGBCOLOR];
				color=[NSColor colorWithCalibratedRed:((hex>>16)&0xff)/255.0 green:((hex>>8)&0xff)/255.0 blue:(hex&0xff)/255.0 alpha:1.0];
				}
			else
				color=[[val _toString] _htmlNamedColor];	// look up by color name
			if(color)
				[_style setObject:color forKey:NSForegroundColorAttributeName];
			}
		// handle other attributes directly
		else
			{ // convert to string value
			val=(DOMCSSValue *) [val _toString];
			if(val)
				[_style setObject:val forKey:key];	// copy value
			else
				; // was not able to convert into string!
			}
		}
	// margin-left: etc.
	// text-align:
	// padding-left: etc.
	// border-left-style: etc.
	// display:
	// color: 
	// font:
	
}

- (void) _addCSSToStyle;
{ // add CSS to style
	if([[[[self webFrame] webView] preferences] authorAndUserStylesEnabled])
		{
		DOMStyleSheetList *list;
		DOMCSSStyleDeclaration *css;
		int i, cnt;
		NSString *style;
		// FIXME: how to handle different media?
		list=[(DOMHTMLDocument *) [self ownerDocument] styleSheets];
		cnt=[list length];
		for(i=0; i<cnt; i++)
			{ // go through all style sheets
			// FIXME: make this a method of DOMCSSRuleList
			// but in a way that multiple rules may match (and have different priorities!)
			// i.e. we should have a method that returns all matching rules
			// then sort by precedence
			// the rules are described here:
			// http://www.w3.org/TR/1998/REC-CSS2-19980512/cascade.html#cascade
			
			DOMCSSRuleList *rules=[(DOMCSSStyleSheet *) [list item:i] cssRules];
			int r, rcnt=[rules length];
			for(r=0; r<rcnt; r++)
				{
				
				DOMCSSRule *rule=(DOMCSSRule *) [rules item:r];
				// FIXME: how to handle pseudoElement here?
#if 0
				NSLog(@"match %@ with %@", self, rule);
#endif
				if([rule _ruleMatchesElement:self pseudoElement:@""])
					{
					// FIXME: handle specificity and !important priority
#if 0
					NSLog(@"MATCH!");
#endif
					[self _addCSSToStyle:[(DOMCSSStyleRule *) rule style]];						
					}
				}
			}
		style=[self getAttribute:@"style"];	// style="" attribute (don't use KVC here since it may return the (NSArray *) _style!)
		if(style)
			{ // parse locally defined CSS
#if 1
				NSLog(@"add style=\"%@\"", style);
#endif
				css=[[DOMCSSStyleDeclaration alloc] initWithString:style];	// parse
				[self _addCSSToStyle:css];	// apply
				[css release];
			}
		}
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
		WebView *webView=[[self webFrame] webView];
		NSFont *f=[_style objectForKey:NSFontAttributeName];	// get current font
		f=[[NSFontManager sharedFontManager] convertFont:f toFamily:[[webView preferences] fixedFontFamily]];
		f=[[NSFontManager sharedFontManager] convertFont:f toSize:[[webView preferences] defaultFixedFontSize]*[webView textSizeMultiplier]];
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
		if(f) [_style setObject:f forKey:NSFontAttributeName];
		[_style setObject:[NSNumber numberWithInt:-1] forKey:NSSuperscriptAttributeName];
		}
	else if([node isEqualToString:@"BIG"])
		{ // make font larger +1
		NSFont *f=[_style objectForKey:NSFontAttributeName];	// get current font
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
	NSMutableString *s=[NSMutableString stringWithString:[self data]];
	[s replaceOccurrencesOfString:@"\r" withString:@" " options:0 range:NSMakeRange(0, [s length])];	// convert to space
	[s replaceOccurrencesOfString:@"\n" withString:@" " options:0 range:NSMakeRange(0, [s length])];	// convert to space
	[s replaceOccurrencesOfString:@"\t" withString:@" " options:0 range:NSMakeRange(0, [s length])];	// convert to space
#if 1	// QUESTIONABLE_OPTIMIZATION
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
//		[style setObject:self forKey:WebElementDOMNodeKey];	// establish a reference to ourselves into the DOM tree
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
			NSLog(@"sheet=%@", sheet);
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

- (void) _spliceTo:(NSMutableAttributedString *) str; { return; }	// ignore if in <body> context

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

- (void) _spliceTo:(NSMutableAttributedString *) str; { return; }	// ignore if in <body> context

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
	return [[[DOMHTMLElement alloc] _initWithName:@"#dummy" namespaceURI:nil] autorelease];	// return dummy
}

- (void) _layout:(NSView *) view;
{ // recursively arrange subviews so that they match children
	NSString *splits;	// "50%,*"
	NSEnumerator *e;	// enumerator
	NSNumber *split;	// current splitting value (float)
	DOMNodeList *children=[self childNodes];
	unsigned count=[children length];
	unsigned childIndex=0;
	unsigned subviewIndex=0;
	float position=0.0;
	float total;
	NSRect frame;
	BOOL vertical;
#if 0
	NSLog(@"_layout: %@", self);
	NSLog(@"attribs: %@", [self _attributes]);
#endif
	splits=[self valueForKey:@"cols"];		// cols has precedence if defined
	if(!(vertical=(splits != nil)))				// if we have any cols...
		splits=[self valueForKey:@"rows"];	// check for rows
	if(!splits)	// neither
		splits=@"100%";	// single entry with full width? or should we evenly split all children?`
	if(![view isKindOfClass:[_WebHTMLDocumentFrameSetView class]])
		{ // add/substitute a new _WebHTMLDocumentFrameSetView (subclass of NSSplitView) view of same dimensions
		_WebHTMLDocumentFrameSetView *setView=[[_WebHTMLDocumentFrameSetView alloc] initWithFrame:[view frame]];
		if([[view superview] isKindOfClass:[NSClipView class]])
			[(NSClipView *) [view superview] setDocumentView:setView];			// make the FrameSetView the document view
		else
			[[view superview] replaceSubview:view with:setView];	// replace
			[setView setDelegate:self];	// become the delegate (to control no-resize)
		view=setView;	// use new
		[setView release];
		}
	[(NSSplitView *) view setVertical:vertical];
	for(childIndex=0, subviewIndex=0; childIndex < count; childIndex++)
			{
				DOMHTMLElement *child=(DOMHTMLElement *) [children item:childIndex];
#if 1
			NSLog(@"child=%@", child);
#endif
				if([child isKindOfClass:[DOMHTMLFrameSetElement class]] || [child isKindOfClass:[DOMHTMLFrameElement class]])
						{ // real content
							subviewIndex++;	// one more
							if(subviewIndex > [[view subviews] count])
									{ // we don't have instantiated enough subviews yet - add one
										_WebHTMLDocumentView *childView=[[_WebHTMLDocumentView alloc] initWithFrame:[view frame]];
										[view addSubview:childView];
										[childView release];
									}
						}
			}
	while([[view subviews] count] > subviewIndex)
			[[[view subviews] lastObject] removeFromSuperviewWithoutNeedingDisplay];	// we have too many subviews - remove last one
#if 0
	NSLog(@"subviews = %@", [view subviews]);
#endif
	e=[splits _htmlFrameSetEnumerator];		// comma separated list e.g. "20%,*" or "1*,3*,7*"
	frame=[view frame];
	total=(vertical?frame.size.width:frame.size.height)-[(NSSplitView *) view dividerThickness]*(subviewIndex-1);	// how much room we can distribute
	for(childIndex=0, subviewIndex=0; childIndex < count; childIndex++)
			{
				DOMHTMLElement *child=(DOMHTMLElement *) [children item:childIndex];
				if([child isKindOfClass:[DOMHTMLFrameSetElement class]] || [child isKindOfClass:[DOMHTMLFrameElement class]])
						{ // real content
							NSView *childView=[[view subviews] objectAtIndex:subviewIndex];
							[child _layout:childView];	// layout subview - this may replace the original subview!
							childView=[[view subviews] objectAtIndex:subviewIndex];	// fetch the (new) subview to resize as needed
#if 0
							NSLog(@" child = %@ - %@", childView, NSStringFromRect([childView frame]));
#endif
							split=[e nextObject];	// get next splitting info
							if(!split)
								break;	// mismatch in count
							frame=[childView frame];
#if 0
							NSLog(@"  was = %@", NSStringFromRect([childView frame]));
#endif
							if(vertical)
									{ // vertical splitter
										frame.origin.x=position;
										position += frame.size.width=[split floatValue]*total;	// how much of total
									}
							else
									{
										frame.origin.y=position;
										position += frame.size.height=[split floatValue]*total;	// how much of total
									}
							position += [(NSSplitView *) view dividerThickness];	// leave room for divider
							[childView setFrame:frame];	// adjust
#if 0
							NSLog(@"  is = %@ -> %@", NSStringFromRect(frame), NSStringFromRect([childView frame]));
#endif
							subviewIndex++;
						}
			}
	[(NSSplitView *) view adjustSubviews];	// adjust them all
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
	return [[[DOMHTMLElement alloc] _initWithName:@"#dummy" namespaceURI:nil] autorelease];	// return dummy
}

- (void) _layout:(NSView *) view;
{
	NSString *name=[self valueForKey:@"name"];
	NSString *src=[self valueForKey:@"src"];
	NSString *border=[self valueForKey:@"frameborder"];
	NSString *width=[self valueForKey:@"marginwidth"];
	NSString *height=[self valueForKey:@"marginheight"];
	NSString *scrolling=[self valueForKey:@"scrolling"];
	BOOL noresize=[self hasAttribute:@"noresize"];
	WebFrame *frame;
	WebFrameView *frameView;
	WebView *webView=[[self webFrame] webView];
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
		frame=[[WebFrame alloc] initWithName:name
								 webFrameView:frameView
									  webView:webView];	// allocate a new WebFrame
		[frameView _setWebFrame:frame];	// create and attach a new WebFrame
			[frame release];
		[frame _setFrameElement:self];	// make a link
		[[self webFrame] _addChildFrame:frame];	// make new frame a child of our frame
		if(src)
			[frame loadRequest:[NSURLRequest requestWithURL:[self URLWithAttributeString:@"src"]]];
		}
	else
		{
		frameView=(WebFrameView *) view;
		frame=[frameView webFrame];		// get the webframe
		}
	[frame _setFrameName:name];
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
	return [[[DOMHTMLElement alloc] _initWithName:@"#dummy" namespaceURI:nil] autorelease];	// return dummy
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
	NSColor *text=[[self valueForKey:@"text"] _htmlColor];
	if(!_style)
		{
		// FIXME: cache data until we are modified
		WebView *webView=[[self webFrame] webView];
		NSFont *font=[NSFont fontWithName:[[webView preferences] standardFontFamily] size:[[webView preferences] defaultFontSize]*[webView textSizeMultiplier]];	// determine default font
		NSMutableParagraphStyle *paragraph=[NSMutableParagraphStyle new];
    if(!font)
		    font = [NSFont userFontOfSize:[[webView preferences] defaultFontSize]*[webView textSizeMultiplier]];	// default if webPrefs define unknown font
		[paragraph setParagraphSpacing:[[webView preferences] defaultFontSize]/2.0];	// default
		_style=[[NSMutableDictionary alloc] initWithObjectsAndKeys:
			paragraph, NSParagraphStyleAttributeName,
			font, NSFontAttributeName,
//			self, WebElementDOMNodeKey,			// establish a reference into the DOM tree
//			[self webFrame], WebElementFrameKey,
			@"inline", DOMHTMLBlockInlineLevel,	// treat as inline (i.e. don't surround by \nl)
									// background color
			text, NSForegroundColorAttributeName,		// default text color - may be nil!
			nil];
#if 0
		NSLog(@"_style for <body> with attribs %@ is %@", [self _attributes], _style);
#endif
			[paragraph release];
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
	DOMHTMLDocument *htmlDocument=(DOMHTMLDocument *) [self ownerDocument];
	WebDataSource *source=[htmlDocument _webDataSource];
	NSString *anchor=[[[source response] URL] fragment];
	NSString *backgroundURL=[self valueForKey:@"background"];		// URL for background image
	NSColor *bg=[[self valueForKey:@"bgcolor"] _htmlColor];
	NSColor *link=[[self valueForKey:@"link"] _htmlColor];
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
	NSString *align=[self valueForKey:@"align"];
	if(align)
		[paragraph setAlignment:[align _htmlAlignment]];
	// and modify others...
	[_style setObject:@"block" forKey:DOMHTMLBlockInlineLevel];
	[_style setObject:paragraph forKey:NSParagraphStyleAttributeName];
	[paragraph release];
}

@end

@implementation DOMHTMLSpanElement

- (void) _addAttributesToStyle;
{ // add attributes to style
	NSMutableParagraphStyle *paragraph=[[_style objectForKey:NSParagraphStyleAttributeName] mutableCopy];
	NSString *align=[self valueForKey:@"align"];
	if(align)
		[paragraph setAlignment:[align _htmlAlignment]];
	// and modify others...
	[_style setObject:paragraph forKey:NSParagraphStyleAttributeName];
	[paragraph release];
}

@end

@implementation DOMHTMLCenterElement

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLLazyNesting; }

- (void) _addAttributesToStyle;
{ // add attributes to style
	NSMutableParagraphStyle *paragraph=[[_style objectForKey:NSParagraphStyleAttributeName] mutableCopy];
	NSString *align=[self valueForKey:@"align"];
	if(align)
		[paragraph setAlignment:[align _htmlAlignment]];
	[_style setObject:@"block" forKey:DOMHTMLBlockInlineLevel];
	// and modify others...
	[_style setObject:paragraph forKey:NSParagraphStyleAttributeName];
	[paragraph release];
}

@end

@implementation DOMHTMLHeadingElement

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLLazyNesting; }

- (void) _addAttributesToStyle;
{ // add attributes to style
	NSMutableParagraphStyle *paragraph=[[_style objectForKey:NSParagraphStyleAttributeName] mutableCopy];
	int level=[[[self nodeName] substringFromIndex:1] intValue];
	WebView *webView=[[self webFrame] webView];
	float size=[[webView preferences] defaultFontSize]*[webView textSizeMultiplier];
	NSFont *f;
	NSString *align=[self valueForKey:@"align"];
	if(align)
		[paragraph setAlignment:[align _htmlAlignment]];
#if MAC_OS_X_VERSION_10_4 <= MAC_OS_X_VERSION_MAX_ALLOWED
	[paragraph setHeaderLevel:level];	// if someone wants to convert the attributed string back to HTML...
#endif
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
	f=[NSFont fontWithName:[[webView preferences] standardFontFamily] size:size];
	f=[[NSFontManager sharedFontManager] convertFont:f toHaveTrait:NSBoldFontMask];	// get Bold variant
	if(f)
		[_style setObject:f forKey:NSFontAttributeName];	// set header font
	[_style setObject:@"block" forKey:DOMHTMLBlockInlineLevel];
	[_style setObject:paragraph forKey:NSParagraphStyleAttributeName];
	[paragraph release];
}

@end

@implementation DOMHTMLPreElement

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLLazyNesting; }

- (void) _addAttributesToStyle;
{ // add attributes to style
	NSMutableParagraphStyle *paragraph=[[_style objectForKey:NSParagraphStyleAttributeName] mutableCopy];
	NSString *align=[self valueForKey:@"align"];
	// set monospaced font
	[paragraph setLineBreakMode:NSLineBreakByClipping];
	[_style setObject:@"block" forKey:DOMHTMLBlockInlineLevel];
	// and modify others...
	[_style setObject:paragraph forKey:NSParagraphStyleAttributeName];
	[paragraph release];
}

@end

@implementation DOMHTMLFontElement

- (void) _addAttributesToStyle;
{ // add attributes to style
	WebView *webView=[[self webFrame] webView];
	NSArray *names=[[self valueForKey:@"face"] componentsSeparatedByString:@","];	// is a comma separated list of potential font names!
	NSString *size=[self valueForKey:@"size"];
	NSColor *color=[[self valueForKey:@"color"] _htmlColor];
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
				break;	// take the first one we have found
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
		else NSLog(@"could not convert %@ to size %lf", [_style objectForKey:NSFontAttributeName], sz);
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

- (void) _elementDidAwakeFromDocumentRepresentation:(_WebHTMLDocumentRepresentation *) rep;
{
	NSString *urlString=[self valueForKey:@"href"];
	if(urlString)
		[[(DOMHTMLDocument *) [self ownerDocument] links] appendChild:self];	// add to Links[] DOM Level 0 list
	else
		[[(DOMHTMLDocument *) [self ownerDocument] anchors] appendChild:self];	// add to Links[] DOM Level 0 list
}

- (void) _addAttributesToStyle;
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
		NSCursor *cursor=[NSCursor pointingHandCursor];
		[_style setObject:urlString forKey:NSLinkAttributeName];	// set the link
		[_style setObject:urlString forKey:NSToolTipAttributeName];	// set the ToolTip 
		[_style setObject:cursor forKey:NSCursorAttributeName];	// set the cursor
		if(target)
			[_style setObject:target forKey:DOMHTMLAnchorElementTargetWindow];		// set the target window
		}
	if(!name)
		name=[self valueForKey:@"id"];	// XHTML alternative
	if(name)
		{ // add an anchor
		[_style setObject:name forKey:DOMHTMLAnchorElementAnchorName];	// set the cursor
		}
	// and modify others...
}

@end

@implementation DOMHTMLImageElement

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLNoNesting; }

- (void) _elementDidAwakeFromDocumentRepresentation:(_WebHTMLDocumentRepresentation *) rep;
{
	[[(DOMHTMLDocument *) [self ownerDocument] images] appendChild:self];	// add to Images[] DOM Level 0 list
	[super _elementDidAwakeFromDocumentRepresentation:rep];
}

- (void) _addAttributesToStyle;
{ // add attributes to style
	NSString *align=[self valueForKey:@"align"];
	NSURL *urlString=[self valueForKey:@"src"];	// relative links will be expanded when clicking on the link
	if(urlString && ![_style objectForKey:NSLinkAttributeName])
		{ // add a hyperlink with the image source (unless we are embedded within a link)
		NSCursor *cursor=[NSCursor pointingHandCursor];
		[_style setObject:urlString forKey:NSLinkAttributeName];	// set the link
		[_style setObject:cursor forKey:NSCursorAttributeName];	// set the cursor
// 		[_style setObject:target forKey:DOMHTMLAnchorElementTargetWindow];		// set the target window
		}
}

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
		return nil;	// can't show
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

- (NSString *) _string;		{ return @"\n"; }

- (void) _addAttributesToStyle
{ // <br> is an inline element
	NSMutableParagraphStyle *paragraph=[[_style objectForKey:NSParagraphStyleAttributeName] mutableCopy];
	[paragraph setParagraphSpacing:0.0];
	// and modify others...
	[_style setObject:paragraph forKey:NSParagraphStyleAttributeName];
	[paragraph release];
}

@end

@implementation DOMHTMLParagraphElement

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLLazyNesting; }

- (NSString *) _string;		{ return @"\n"; }

- (void) _addAttributesToStyle;
{ // add attributes to style
	NSMutableParagraphStyle *paragraph=[[_style objectForKey:NSParagraphStyleAttributeName] mutableCopy];
	NSString *align=[self valueForKey:@"align"];
	[_style setObject:@"block" forKey:DOMHTMLBlockInlineLevel];
	if(align)
		[paragraph setAlignment:[align _htmlAlignment]];
	[paragraph setParagraphSpacing:6.0];
	// and modify others...
	[_style setObject:paragraph forKey:NSParagraphStyleAttributeName];
	[paragraph release];
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
	size = [[self valueForKey:@"size"] intValue];
#if 1  
	NSLog(@"<hr> size: %@", [self valueForKey:@"size"]);
    NSLog(@"<hr> width: %@", [self valueForKey:@"width"]);
#endif
    return att;
}

@end

@implementation NSTextBlock (Attributes)

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

- (void) _addAttributesToStyle;
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
	[_style setObject:@"block" forKey:DOMHTMLBlockInlineLevel];	// a table is a block element, i.e. force a \n before table starts
	[_style setObject:paragraph forKey:NSParagraphStyleAttributeName];
	[paragraph release];
#if 0
	NSLog(@"<table> _style=%@", _style);
#endif
}

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

- (NSString *) _string;		{ return @"\n"; }	// each cell creates a line

- (void) _addAttributesToStyle;
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
	[elements	release];
	[super dealloc];
}

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLStandardNesting; }

- (void) _addAttributesToStyle;
{ // add attributes to style
	[_style setObject:@"block" forKey:DOMHTMLBlockInlineLevel];
}

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
	NSMutableData *postBody=nil;
	NSMutableString *getURL=nil;
	NSEnumerator *e;
	DOMHTMLElement *element;
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
	if(method && [method caseInsensitiveCompare:@"post"] == NSOrderedSame)
		postBody=[NSMutableData new];
	else
		getURL=[NSMutableString stringWithCapacity:100];
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
				if(postBody)
						[postBody appendData:[[NSString stringWithFormat:@"%@=%@\r\n", name, val] dataUsingEncoding:NSUTF8StringEncoding]];
				else
						[getURL appendFormat:@"&%@=%@", name, val];
			}
	if([getURL length] > 0)
			{
#if 1
				NSLog(@"getURL = %@", getURL);
#endif
				action=[action stringByAppendingFormat:@"?%@", [getURL substringFromIndex:1]];	// change first & to ?
#if 1
				NSLog(@"action = %@", action);
#endif
				// FIXME: remove any existing ?query part and replace
			}
	request=(NSMutableURLRequest *)[NSMutableURLRequest requestWithURL:[NSURL URLWithString:action relativeToURL:[[[htmlDocument _webDataSource] response] URL]]];
	if(method)
		[request setHTTPMethod:[method uppercaseString]];	// will default to "GET" if missing
	if(postBody)
			{
#if 1
				NSLog(@"post = %@", postBody);
#endif
				[request setHTTPBody:postBody];
				[postBody release];
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
#if 0
				NSLog(@"attachmentCell=%@", [attachment attachmentCell]);
				NSLog(@"[attachmentCell attachment]=%@", [[attachment attachmentCell] attachment]);
				NSLog(@"[attachmentCell image]=%@", [(NSCell *) [attachment attachmentCell] image]);	// maybe, we can apply sizing...
#endif
			}
#if 1
	NSLog(@"  cell: %@", cell);
	NSLog(@"  cell control view: %@", [cell controlView]);
	NSLog(@"  _style: %@", _style);
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
	switch([code intValue])
		{
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

- (NSString *) _string; { return nil; }	// don't process content

- (NSTextAttachment *) _attachment;
{ // create a text attachment that display the content of the button
	NSMutableAttributedString *value=[[[NSMutableAttributedString alloc] init] autorelease];
	NSTextAttachment *attachment;
	NSString *name=[self valueForKey:@"name"];
	NSString *size=[self valueForKey:@"size"];
	[(DOMHTMLElement *) [self firstChild] _spliceTo:value];	// recursively splice all child element strings into our value string
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

- (NSString *) _string; { return nil; }	// don't process content

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
	if(cell < 0)
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
	[(DOMHTMLElement *) [self firstChild] _spliceTo:value];	// recursively splice all child element strings into our value string
	return [value string];
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

- (NSString *) _string; { return nil; }	// don't process content

- (NSTextAttachment *) _attachment;
{ // <textarea cols=xxx lines=yyy>value</textarea> 
	NSMutableAttributedString *value=[[[NSMutableAttributedString alloc] init] autorelease];
	NSTextAttachment *attachment;
	NSString *name=[self valueForKey:@"name"];
	NSString *cols=[self valueForKey:@"cols"];
	NSString *lines=[self valueForKey:@"lines"];
	[(DOMHTMLElement *) [self firstChild] _spliceTo:value];	// recursively splice all child element strings into our value string
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
	[_style setObject:@"block" forKey:DOMHTMLBlockInlineLevel];
	[_style setObject:paragraph forKey:NSParagraphStyleAttributeName];
	[paragraph release];
}

@end

@implementation DOMHTMLOListElement		// <ol>

- (void) _addAttributesToStyle;
{ 
  NSMutableParagraphStyle *paragraph=[[_style objectForKey:NSParagraphStyleAttributeName] mutableCopy];
  NSString *align=[self valueForKey:@"align"];
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
			[lists release];
    }
#if 0
  NSLog(@"lists=%@", lists);
#endif
  [_style setObject:@"block" forKey:DOMHTMLBlockInlineLevel];
  [_style setObject:paragraph forKey: NSParagraphStyleAttributeName];
	[paragraph release];
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
  [_style setObject:@"block" forKey:DOMHTMLBlockInlineLevel];
  [_style setObject:paragraph forKey:NSParagraphStyleAttributeName];
	[paragraph release];
}

@end

@implementation DOMHTMLCanvasElement		// <canvas>

+ (DOMHTMLNestingStyle) _nesting;		{ return DOMHTMLNoNesting; }

@end
