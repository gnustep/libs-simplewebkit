/* simplewebkit
 DOMCSS.m
 
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
 
 We should finally be able to run the demo code on
 
 http://www.howtocreate.co.uk/tutorials/javascript/domstylesheets
 
 */

#import <WebKit/WebView.h>
#import "Private.h"

@interface DOMStyleSheetList (Private)
- (void) _addStyleSheet:(DOMStyleSheet *) sheet;
@end

@interface DOMCSSStyleSheet (Private)
- (BOOL) _refersToHref:(NSString *) ref;
@end

@interface DOMCSSRule (Private)
+ (void) _skip:(NSScanner *) sc;
- (void) _setParentStyleSheet:(DOMCSSStyleSheet *) sheet;
- (void) _setParentRule:(DOMCSSRule *) rule;
- (BOOL) _refersToHref:(NSString *) ref;
@end

@interface DOMCSSCharsetRule (Private)
- (id) initWithEncoding:(NSString *) e;
@end

@interface DOMCSSMediaRule (Private)
- (id) initWithMedia:(NSString *) mediaList;
@end

@interface DOMCSSImportRule (Private)
- (id) initWithHref:(NSString *) uri;
@end

@interface DOMCSSStyleRule (Private)
- (BOOL) _ruleMatchesElement:(DOMElement *) element pseudoElement:(NSString *) pseudoElement;
@end

@interface DOMMediaList (Private)
- (BOOL) _matchMedia:(NSString *) media;
@end

@interface DOMCSSValueList (Private)
- (id) _initWithFirstElement:(DOMCSSValue *) first;
- (void) _addItem:(DOMCSSValue *) item;
- (NSArray *) _toStringArray;
@end

@interface DOMCSSValue (Private)
- (NSString *) _toString;	// value as string (independent of type)
- (NSArray *) _toStringArray;
@end

@implementation DOMStyleSheetList

- (void) dealloc
{
	[items release];
	[super dealloc];
}

- (void) _addStyleSheet:(DOMStyleSheet *) sheet;
{
	if(!items)
		items=[[NSMutableArray alloc] initWithCapacity:3];
#if 1
	NSLog(@"adding styleSheet %@", sheet);
#endif
	[(NSMutableArray *) items addObject:sheet];
}

- (unsigned) length; { return [items count]; }
- (DOMStyleSheet *) item:(unsigned) index; { return [items objectAtIndex:index]; }

@end

@implementation DOMStyleSheet

- (id) init
{
	if((self=[super init]))
		{
		media=[DOMMediaList new];
		}
	return self;
}

- (void) dealloc
{
	[href release];
	[media release];
	[ownerNode release];
	[title release];
	[super dealloc];
}

- (NSString *) href; { return href; }	// we could derive from WebDataSource if we link that
- (DOMMediaList *) media; { return media; }
- (DOMNode *) ownerNode; { return ownerNode; }
- (NSString *) title; { return title; }
- (BOOL) disabled; { return disabled; }
- (DOMStyleSheet *) parentStyleSheet; { return parentStyleSheet; }

// FIXME: which of these setters should really be public??
// probably none!

- (void) setHref:(NSString *) h { ASSIGN(href, h); }
- (void) setTitle:(NSString *) t { ASSIGN(title, t); }
- (void) setOwnerNode:(DOMNode *) n { ASSIGN(ownerNode, n); }

@end

@implementation DOMCSSStyleDeclaration

- (id) initWithString:(NSString *) style;
{ // scan a style declaration
	if((self=[super init]))
		{
		items=[[NSMutableDictionary alloc] initWithCapacity:10];
		priorities=[[NSMutableDictionary alloc] initWithCapacity:10];
		[self setCssText:style];
		}
	return self;
}

- (void) dealloc
{
	[items release];
	[priorities release];
	[super dealloc];
}

- (DOMCSSRule *) parentRule; { return parentRule; }

- (NSString *) cssText;
{	// this should regenerate the cssText from content
	NSMutableString *s=[NSMutableString stringWithCapacity:50];
	NSEnumerator *e=[items keyEnumerator];
	NSString *key;
	while((key=[e nextObject]))
		{
		if([s length] > 0)
			[s appendString:@" "];
		[s appendFormat:@"%@: %@;", key, [[items objectForKey:key] cssText]];
		}
	return s;
}

/* shorthand translation example from WebKit:

 *{padding:0;margin:0;border:0;}

 --->
 
 * { padding-top: 0px; padding-right: 0px; padding-bottom: 0px; padding-left: 0px; 
     margin-top: 0px; margin-right: 0px; margin-bottom: 0px; margin-left: 0px;
     border-top-width: 0px; border-right-width: 0px; border-bottom-width: 0px; border-left-width: 0px;
     border-style: initial; border-color: initial; }
 
 body
 {
 background: #fff;
 color: #282931;
 background: #fff;
 font-family: "Trebuchet MS", Trebuchet, Tahoma, sans-serif;
 font-size: 10pt;
 margin: 0px;
 padding: 0px;
 }

 --->
 
 body { background-image: initial; background-attachment: initial; background-origin: initial;
        background-clip: initial; background-color: rgb(255, 255, 255);
        color: rgb(40, 41, 49);
        background-image: initial; background-attachment: initial; background-origin: initial;
        background-clip: initial; background-color: rgb(255, 255, 255);
        font-family: 'Trebuchet MS', Trebuchet, Tahoma, sans-serif;
        font-size: 10pt;
        margin-top: 0px; margin-right: 0px; margin-bottom: 0px; margin-left: 0px;
        padding-top: 0px; padding-right: 0px; padding-bottom: 0px; padding-left: 0px;
        background-position: initial initial; background-repeat: initial initial;
 }
 
 Conclusions:
 * shorthand properties are translated directly
 * some missing values are set to 'initial' (!)
 * duplicates remain duplicate (!)
 
*/

- (void) _handleProperty:(NSString *) property withScanner:(NSScanner *) sc;
{ // check for and translate shorthand properties; see: http://www.dustindiaz.com/css-shorthand/
	DOMCSSValue *val=[[[DOMCSSValue alloc] initWithString:(NSString *) sc] autorelease];	// at least one
	BOOL inherit=[val cssValueType] == DOM_CSS_INHERIT;
	static DOMCSSValue *initial;
	if(!initial)
		initial=[[DOMCSSValue alloc] initWithString:@"initial"];
	if([property isEqualToString:@"margin"] || [property isEqualToString:@"padding"])
		{ // margin/padding: [ width | percent | auto ] { 1, 4 } | inherit
			DOMCSSValue *top=inherit?val:initial;
			DOMCSSValue *right=inherit?val:initial;
			DOMCSSValue *bottom=inherit?val:initial;
			DOMCSSValue *left=inherit?val:initial;
			if(!inherit)
				{ // collect up to 4 values clockwise from top to left
					if([val cssValueType] == DOM_CSS_PRIMITIVE_VALUE && [(DOMCSSPrimitiveValue *) val primitiveType] != DOM_CSS_UNKNOWN)
						{
						top=val;
						val=[[[DOMCSSValue alloc] initWithString:(NSString *) sc] autorelease];						
						if([val cssValueType] == DOM_CSS_PRIMITIVE_VALUE && [(DOMCSSPrimitiveValue *) val primitiveType] != DOM_CSS_UNKNOWN)
							{
							right=val;
							val=[[[DOMCSSValue alloc] initWithString:(NSString *) sc] autorelease];						
							if([val cssValueType] == DOM_CSS_PRIMITIVE_VALUE && [(DOMCSSPrimitiveValue *) val primitiveType] != DOM_CSS_UNKNOWN)
								{
								bottom=val;
								val=[[[DOMCSSValue alloc] initWithString:(NSString *) sc] autorelease];						
								if([val cssValueType] == DOM_CSS_PRIMITIVE_VALUE && [(DOMCSSPrimitiveValue *) val primitiveType] != DOM_CSS_UNKNOWN)
									left=val;
								}
							}
						}
				}
			[items setObject:top forKey:[property stringByAppendingString:@"-top"]];
			[items setObject:right forKey:[property stringByAppendingString:@"-right"]];
			[items setObject:bottom forKey:[property stringByAppendingString:@"-bottom"]];
			[items setObject:left forKey:[property stringByAppendingString:@"-left"]];
			return;
		}
	if([property isEqualToString:@"border"]
	   || [property isEqualToString:@"outline"]
	   || [property isEqualToString:@"border-top"]
	   || [property isEqualToString:@"border-right"]
	   || [property isEqualToString:@"border-bottom"]
	   || [property isEqualToString:@"border-left"])
		{ // border: [ border-width || border-style || border-color ] | inherit;
			DOMCSSValue *width=inherit?val:initial;
			DOMCSSValue *style=inherit?val:initial;
			DOMCSSValue *color=inherit?val:initial;
			if(!inherit)
				{
				while([val cssValueType] == DOM_CSS_PRIMITIVE_VALUE && [(DOMCSSPrimitiveValue *) val primitiveType] != DOM_CSS_UNKNOWN)
					{ // collect values (they differ by type: numeric -> width; identifier -> style; color -> color)
						switch([(DOMCSSPrimitiveValue *) val primitiveType]) {
							case DOM_CSS_RGBCOLOR:
								color=val;
								break;
							case DOM_CSS_IDENT: {
								NSString *str=[(DOMCSSPrimitiveValue *) val getStringValue];
								if([str isEqualToString:@"thin"] || [str isEqualToString:@"medium"] || [str isEqualToString:@"thick"])
									width=val;
								else if([str isEqualToString:@"none"] || [str isEqualToString:@"hidden"] || [str isEqualToString:@"dotted"]
										|| [str isEqualToString:@"dashed"] || [str isEqualToString:@"solid"] || [str isEqualToString:@"double"]
										|| [str isEqualToString:@"groove"] || [str isEqualToString:@"ridge"] || [str isEqualToString:@"inset"]
										|| [str isEqualToString:@"none"])
									style=val;
								else
									color=val;	// should be a color name
								break;
							}
							default:
								width=val;
								break;
						}
					val=[[[DOMCSSValue alloc] initWithString:(NSString *) sc] autorelease];						
					}
				}
			// FIXME: should border-style etc. set all four variants of border-top-style?
			[items setObject:width forKey:[property stringByAppendingString:@"-width"]];
			[items setObject:style forKey:[property stringByAppendingString:@"-style"]];
			[items setObject:color forKey:[property stringByAppendingString:@"-color"]];
			return;
		}
	if([property isEqualToString:@"list-style"])
		{ // list-style: [ -type || -image || -position ] | inherit
		return;
		}
	if([property isEqualToString:@"background"])
		{ // background: [ -color || -image || -repeat || -attachment || -position ] | inherit
		return;
		}
	if([property isEqualToString:@"font"])
		{ // font: [[ -style || -variant || -weight] -size [ / -height ] -family ] | caption | icon | menu | ... | inherit
			// check for inherit or system font
		return;
		}
	if([property isEqualToString:@"pause"] || [property isEqualToString:@"cue"])
		{ // pause: [[ time | percent ]{1,2} | inherit
			// cue: [ cue-before || cue-after ] | inherit
			DOMCSSValue *before=inherit?val:initial;
			DOMCSSValue *after=inherit?val:initial;
			if(!inherit)
				{ // collect up to 2 values
					if([val cssValueType] == DOM_CSS_PRIMITIVE_VALUE && [(DOMCSSPrimitiveValue *) val primitiveType] != DOM_CSS_UNKNOWN)
						{
						before=val;
						val=[[[DOMCSSValue alloc] initWithString:(NSString *) sc] autorelease];						
						if([val cssValueType] == DOM_CSS_PRIMITIVE_VALUE && [(DOMCSSPrimitiveValue *) val primitiveType] != DOM_CSS_UNKNOWN)
							after=val;
						}
				}
			[items setObject:before forKey:[property stringByAppendingString:@"-before"]];
			[items setObject:after forKey:[property stringByAppendingString:@"-after"]];
			return;
		}
	[items setObject:val forKey:property];	// not a shorthand, i.e. a single-value
}

- (void) setCssText:(NSString *) style
{
	NSScanner *sc;
	static NSCharacterSet *propertychars;
	if(!propertychars)
		propertychars=[[NSCharacterSet characterSetWithCharactersInString:@"-abcdefghijklmnopqrstuvwxyz_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"] retain];
	if([style isKindOfClass:[NSScanner class]])
		sc=(NSScanner *) style;
	else
		sc=[NSScanner scannerWithString:style];
	while(YES)
		{
		NSString *propertyName;
		NSString *priority=@"important";	// default priority
		[DOMCSSRule _skip:sc];
		if(![sc scanCharactersFromSet:propertychars intoString:&propertyName])
			break;
		[DOMCSSRule _skip:sc];				
		if(![sc scanString:@":" intoString:NULL])
			break;	// invalid
		[self _handleProperty:propertyName withScanner:sc];
		[DOMCSSRule _skip:sc];
		// FIXME: there may be a space between ! and "important"
		// see e.g. http://www.yellowjug.com/web-design/the-importance-of-important-in-css/
		// FIXME: how does this work for shorthand properties?
		[sc scanString:@"important" intoString:&priority] || [sc scanString:@"!important" intoString:&priority];
		[priorities setObject:priority forKey:propertyName];
		[DOMCSSRule _skip:sc];
		if(![sc scanString:@";" intoString:NULL])
			{ // invalid - try to recover
			[sc scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@";}"] intoString:NULL];
			[sc scanString:@";" intoString:NULL];
			break;
			}
		}
	// trigger re-layout of ownerDocumentView
}

- (NSString *) getPropertyValue:(NSString *) propertyName; { return [[items objectForKey:propertyName] getStringValue]; }
- (DOMCSSValue *) getPropertyCSSValue:(NSString *) propertyName; { return [items objectForKey:propertyName]; }
- (NSString *) removeProperty:(NSString *) propertyName; { [items removeObjectForKey:propertyName]; return propertyName; }
- (NSString *) getPropertyPriority:(NSString *) propertyName; { return [priorities objectForKey:propertyName]; }

- (void) setProperty:(NSString *) propertyName value:(NSString *) value priority:(NSString *) priority;
{
	[items setObject:[[[DOMCSSValue alloc] initWithString:value] autorelease] forKey:propertyName]; 
	[priorities setObject:priority forKey:propertyName]; 
}

- (unsigned) length; { return [items count]; }
- (NSString *) item:(unsigned) index; { return [[items allValues] objectAtIndex:index]; }

- (NSString *) getPropertyShorthand:(NSString *) propertyName;
{ // convert property-name into camelCase propertyName to allow JS access by dotted notation
	return propertyName;
}

- (BOOL) isPropertyImplicit:(NSString *) propertyName; { return NO; }

- (NSString *) description; { return [self cssText]; }

- (NSDictionary *) _items; { return items; }

@end

@implementation DOMMediaList

- (BOOL) _matchMedia:(NSString *) media;
{
	if([items count] == 0)
		return YES;	// empty list matches all
	if([items containsObject:@"all"])
		return YES;
	return [items containsObject:media];	
}

- (NSString *) mediaText;
{
	if([items count] == 0)
		return @"";
	return [items componentsJoinedByString:@", "];
}

- (void) setMediaText:(NSString *) text;
{ // parse a comma separated list of media names
	NSScanner *sc;
	NSEnumerator *e;
	DOMCSSValue *val;
	NSString *medium;
	if([text isKindOfClass:[NSScanner class]])
		sc=(NSScanner *) text;	// we already got a NSScanner
	else
		sc=[NSScanner scannerWithString:text];
	// [sc setCaseSensitve]
	// characters to be ignored
	val=[[[DOMCSSValue alloc] initWithString:(NSString *) sc] autorelease];
	e=[[val _toStringArray] objectEnumerator];
	while((medium=[e nextObject]))
		[self appendMedium:medium];
}

- (unsigned) length; { return [items count]; }
- (NSString *) item:(unsigned) index; { return [items objectAtIndex:index]; }

- (void) deleteMedium:(NSString *) oldMedium; { [(NSMutableArray *) items removeObject:oldMedium]; }	// throw exception if not in list...

- (void) appendMedium:(NSString *) newMedium;
{
	if(!items)
		items=[[NSMutableArray alloc] initWithCapacity:10];
	if(![items containsObject:newMedium])	// avoid duplicates
		[(NSMutableArray *) items addObject:newMedium];
}

- (void) dealloc
{
	[items release];
	[super dealloc];
}

@end

@implementation DOMCSSRuleList

- (id) init;
{
	if((self=[super init]))
		{
		items=[[NSMutableArray alloc] initWithCapacity:10];
		}
	return self;
}

- (void) dealloc
{
	[items release];
	[super dealloc];
}

- (NSArray *) items; { return items; }
- (unsigned) length; { return [items count]; }
- (DOMCSSRule *) item:(unsigned) index; { return [items objectAtIndex:index]; }

@end

@implementation DOMCSSRule

+ (void) _skip:(NSScanner *) sc
{ // skip comments
	while([sc scanString:@"/*" intoString:NULL])
		{ // skip C-Style comment
			[sc scanUpToString:@"*/" intoString:NULL];
			[sc scanString:@"*/" intoString:NULL];
		}
}

- (BOOL) _ruleMatchesElement:(DOMElement *) element pseudoElement:(NSString *) pseudoElement {
	return NO;
}

// FIXME: move this to setCssText: ?

- (id) initWithString:(NSString *) rule
{ // parse single rule
	NSScanner *sc;
	[self release];	// we will return substitute object (if at all)
	if([rule isKindOfClass:[NSScanner class]])
		sc=(NSScanner *) rule;	// we already got a NSScanner
	else
		sc=[NSScanner scannerWithString:rule];
	// [sc setCaseSensitve???
	// characters to be ignored???
	[DOMCSSRule _skip:sc];
	if([sc isAtEnd])
		{ // missing rule (e.g. comment or whitespace after last)
			return nil;
		}
	if([sc scanString:@"@import" intoString:NULL])
		{ // @import url("path/file.css") media;
			DOMCSSValue *val=[[[DOMCSSValue alloc] initWithString:(NSString *) sc] autorelease];
			self=[[DOMCSSImportRule alloc] initWithHref:[val _toString]];
			[[(DOMCSSImportRule *) self media] setMediaText:(NSString *) sc];	// parse media list (if present)
			[DOMCSSRule _skip:sc];
			[sc scanString:@";" intoString:NULL];	// skip if present
			return self;
		}
	if([sc scanString:@"@media" intoString:NULL])
		{ // @media screen, ... { rule { style } rule { style } @media { subblock } ... }
			[DOMCSSRule _skip:sc];
			self=[[DOMCSSMediaRule alloc] initWithMedia:(NSString *) sc];
			if(![sc scanString:@"{" intoString:NULL])
				return nil;
			while(![sc isAtEnd])
				if([(DOMCSSMediaRule *) self insertRule:(NSString *) sc index:[[(DOMCSSMediaRule *) self cssRules] length]] == (unsigned) -1)	// parse and scan rules
					break;
			if(![sc scanString:@"}" intoString:NULL])
				{ // not closed properly - try to recover
					[sc scanUpToString:@"}" intoString:NULL];
					[sc scanString:@"}" intoString:NULL];
				}
			return self;
		}
	if([sc scanString:@"@charset" intoString:NULL])
		{ // @charset "UTF-8";
			DOMCSSValue *val=[[[DOMCSSValue alloc] initWithString:(NSString *) sc] autorelease];
			return [[DOMCSSCharsetRule alloc] initWithEncoding:[val _toString]];
		}
	if([sc scanString:@"font-face" intoString:NULL])
		{ // @font-face
			return [DOMCSSFontFaceRule new];
		}
	if([sc scanString:@"@namespace" intoString:NULL])	// is not standard (?)
		{ // @namespace d url(http://www.apple.com/DTDs/DictionaryService-1.0.rng);
			return [DOMCSSUnknownRule new];
		}
	if([sc scanString:@"@page" intoString:NULL])
		{ // @page optional-name :header|:footer|:left|:right { style; style; ... }
			self=[DOMCSSPageRule new];
			// check for name definition
		}	// although we cast to DOMCSSStyleRule below, the DOMCSSPageRule provides the same methods
	if([sc scanString:@"@" intoString:NULL])
		{ // unknon @
			// FIXME: ignore up to ; or including block - must match { and }
			// see http://www.w3.org/TR/1998/REC-CSS2-19980512/syndata.html#block section 4.2
			return nil;
		}
	else
		self=[DOMCSSStyleRule new];
	[(DOMCSSStyleRule *) self setSelectorText:(NSString *) sc];	// set from scanner
	// how do we handle parse errors here? e.g. if selectorText is empty
	// i.e. unknown @rule
	[DOMCSSRule _skip:sc];
	if(![sc scanString:@"{" intoString:NULL])
		{ // missing style
			[self release];
			return nil;	// invalid
		}
	[(DOMCSSStyleRule *) self setStyle:[[[DOMCSSStyleDeclaration alloc] initWithString:(NSString *) sc] autorelease]];	// set from scanner
	[DOMCSSRule _skip:sc];
	if(![sc scanString:@"}" intoString:NULL])
		[sc scanUpToString:@"}" intoString:NULL];	// try to recover from parse errors
	return self;
}

- (unsigned short) type; { return DOM_UNKNOWN_RULE; }

- (void) _setParentStyleSheet:(DOMCSSStyleSheet *) sheet { parentStyleSheet=sheet; }
- (DOMCSSStyleSheet *) parentStyleSheet; { return parentStyleSheet; }
- (void) _setParentRule:(DOMCSSRule *) rule { parentRule=rule; }
- (DOMCSSRule *) parentRule; { return parentRule; }

- (NSString *) cssText; { return @"rebuild css text in subclass"; }
- (void) setCssText:(NSString *) text; { NIMP; }

- (NSString *) description; { return [self cssText]; }

@end

@implementation DOMCSSCharsetRule

- (unsigned short) type; { return DOM_CHARSET_RULE; }

- (id) initWithEncoding:(NSString *) enc;
{
	if((self=[super init]))
		{
		encoding=[enc retain];
		}
	return self;
}

- (void) dealloc
{
	[encoding release];
	[super dealloc];
}

- (NSString *) encoding; { return encoding; }

- (NSString *) cssText; { return [NSString stringWithFormat:@"@encoding %@", encoding]; }

@end

@implementation DOMCSSFontFaceRule

- (unsigned short) type; { return DOM_FONT_FACE_RULE; }

- (DOMCSSStyleDeclaration *) style;
{
	return nil;
}

- (NSString *) cssText; { return [NSString stringWithFormat:@"@font-face %@", nil]; }

@end

@implementation DOMCSSImportRule

- (unsigned short) type; { return DOM_IMPORT_RULE; }

- (id) initWithHref:(NSString *) uri;
{
	if((self=[super init]))
		{
		href=[uri retain];
		media=[DOMMediaList new];
		}
	return self;
}

- (void) dealloc
{
	[href release];
	[media release];
	[styleSheet release];
	[super dealloc];
}

- (BOOL) _refersToHref:(NSString *) ref;
{
	if([href isEqualToString:ref])
		return YES;
	return parentRule && [parentRule _refersToHref:ref];	// should also be an @import...
}

- (NSString *) cssText; { return [NSString stringWithFormat:@"@import url(\"%@\") %@;", href, [media mediaText]]; }
- (NSString *) href; { return href; }
- (DOMMediaList *) media; { return media; }

- (void) _setParentStyleSheet:(DOMCSSStyleSheet *) sheet
{ // start loading when being added to a style sheet
	[super _setParentStyleSheet:sheet];
	if(!styleSheet)
		{ // not yet loaded
			// FIXME: if there is no href, we could check [sheet ownerNode] to find the base URL
			NSURL *url=[NSURL URLWithString:href relativeToURL:[NSURL URLWithString:[sheet href]]];	// relative to the URL of the sheet we are added to
			NSString *abs=[url absoluteString];
#if 1
			NSLog(@"@import loading %@ (relative to %@) -> %@ / %@", href, [sheet href], url, abs);
#endif
			if([sheet _refersToHref:abs])
				return;	// recursion found
			styleSheet=[DOMCSSStyleSheet new];
			[styleSheet setHref:href];
			[styleSheet setValue:self forKey:@"ownerRule"];
			if(url)
				{ // trigger load
					WebDataSource *source=[(DOMHTMLDocument *) [[sheet ownerNode] ownerDocument] _webDataSource];
					WebResource *res=[source subresourceForURL:url];
					if(res)
						{ // already completely loaded
							NSString *style=[[NSString alloc] initWithData:[res data] encoding:NSUTF8StringEncoding];
#if 0
							NSLog(@"sub: already completely loaded: %@ (%u bytes)", url, [[res data] length]);
#endif
							[styleSheet _setCssText:style];	// parse the style sheet to add
							[style release];
						}
					else
						[source _subresourceWithURL:url delegate:(id <WebDocumentRepresentation>) self];	// triggers loading if not yet and make me receive notification
				}
			else
				NSLog(@"invalid URL %@ -- %@", href, [sheet href]);
		}
}

- (DOMCSSStyleSheet *) styleSheet; { return styleSheet; }

- (BOOL) _ruleMatchesElement:(DOMElement *) element pseudoElement:(NSString *) pseudoElement
{ // search in loaded style sheet
	
	DOMCSSRuleList *rules;
	int r, rcnt;

	// FIXME: we can't simply check if a @import rule matches
	// because we finally want to add the matching styles...
	// so this approach is fundamentally broken.
	// Rather, we should be able to return a collection of all matching rules (and subrules)
	
	return NO;
	
	// check if we match medium
	// FIXME: go through all rules!
	rules=[styleSheet cssRules];
	rcnt=[rules length];
	for(r=0; r<rcnt; r++)
		{		
		DOMCSSRule *rule=(DOMCSSRule *) [rules item:r];
		// FIXME: how to handle pseudoElement here?
#if 0
		NSLog(@"match %@ with %@", self, rule);
#endif
		if([rule _ruleMatchesElement:element pseudoElement:pseudoElement])
			return YES;
		}
	return NO;
}

// WebDocumentRepresentation callbacks

- (void) setDataSource:(WebDataSource *) dataSource; { return; }

- (void) finishedLoadingWithDataSource:(WebDataSource *) source;
{ // did load style sheet
	NSString *style=[[NSString alloc] initWithData:[source data] encoding:NSUTF8StringEncoding];
	[styleSheet setHref:[[[source response] URL] absoluteString]];	// replace
	[styleSheet _setCssText:style];	// parse the style sheet to add
	[style release];
}

- (void) receivedData:(NSData *) data withDataSource:(WebDataSource *) source;
{
	NSLog(@"%@ receivedData: %u", NSStringFromClass(isa), [[source data] length]);
}

- (void) receivedError:(NSError *) error withDataSource:(WebDataSource *) source;
{ // default error handler
	NSLog(@"%@ receivedError: %@", NSStringFromClass(isa), error);
}

- (NSString *) title; { return @"title"; }	// should get from WebDataSource if available

- (BOOL) canProvideDocumentSource; { return NO; }	// well, we could e.g. return [styleSheet cssText]
- (NSString *) documentSource; { return nil; }

@end

@implementation DOMCSSMediaRule

- (unsigned short) type; { return DOM_MEDIA_RULE; }

- (BOOL) _ruleMatchesElement:(DOMElement *) element pseudoElement:(NSString *) pseudoElement
{ // search in loaded style sheet
	// check if we match any medium
	// check subrules
	/* FIXME --- this does not work!!!
	NSEnumerator *e=[selector objectEnumerator];	// sequence of elements, i.e. >element.class1.class2#id1:pseudo
	NSArray *sequence;
	while((sequence=[e nextObject]))
		{
		NSEnumerator *f=[sequence objectEnumerator];
		DOMCSSStyleRuleSelector *sel;
		while((sel=[f nextObject]))
			{
			if(![sel _ruleMatchesElement:element pseudoElement:pseudoElement])
				break;	// no match
			}
		if(!sel)
			return YES;	// all selectors did match
		}
	 */
	return NO;	// no alternative did match
}

- (id) initWithMedia:(NSString *) m;
{
	if((self=[super init]))
		{
		/* should check for:
		 all
		 aural
		 braille
		 embossed
		 handheld
		 print
		 projection
		 screen
		 tty
		 tv			
		 */ 
		media=[DOMMediaList new];
		[media setMediaText:m];	// scan media list
		cssRules=[DOMCSSRuleList new];
		}
	return self;
}

- (void) dealloc
{
	[media release];
	[cssRules release];
	[super dealloc];
}

- (DOMCSSRuleList *) cssRules; { return cssRules; }

- (unsigned) insertRule:(NSString *) string index:(unsigned) index;
{ // parse rule and insert in cssRules
	DOMCSSRule *rule=[[DOMCSSRule alloc] initWithString:string];
	if(!rule)
		return -1;	// raise exception?
	[(NSMutableArray *) [cssRules items] insertObject:rule atIndex:index];
	[rule _setParentRule:self];
	[rule release];
	return index;
}

- (void) deleteRule:(unsigned) index;
{
	[[(NSMutableArray *) [cssRules items] objectAtIndex:index] _setParentRule:nil];
	[(NSMutableArray *) [cssRules items] removeObjectAtIndex:index];
}

- (NSString *) cssText;
{
	NSMutableString *s=[NSMutableString stringWithCapacity:50];
	NSEnumerator *e=[[cssRules items] objectEnumerator];
	DOMCSSRule *rule;
	[s appendFormat:@"@media %@ {\n", [media mediaText]];
	while((rule=[e nextObject]))
		[s appendFormat:@"  %@\n", rule];
	[s appendString:@"}\n"];
	return s; 
}

@end

@implementation DOMCSSPageRule

- (unsigned short) type; { return DOM_PAGE_RULE; }

- (NSString *) selectorText;
{ // tag class patterns
	NSMutableString *s=[NSMutableString stringWithCapacity:50];
	NSEnumerator *e=[selector objectEnumerator];
	NSString *sel;
	while((sel=[e nextObject]))
		{
		if([s length] > 0)
			[s appendFormat:@" :%@", sel];
		else
			[s appendFormat:@":%@", sel];	// first
		}
	return s;
}

- (void) setSelectorText:(NSString *) rule;
{ // parse selector into array
	NSScanner *sc;
	static NSCharacterSet *tagchars;
	if(!tagchars)
		tagchars=[[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"] retain];
	if([rule isKindOfClass:[NSScanner class]])
		sc=(NSScanner *) rule;	// we already got a NSScanner
	else
		sc=[NSScanner scannerWithString:rule];
	[(NSMutableArray *) selector removeAllObjects];
	while([DOMCSSRule _skip:sc], [sc scanString:@":" intoString:NULL])
		{
		NSString *entry;
		if(![sc scanCharactersFromSet:tagchars intoString:&entry])
			break;	// no match
		[(NSMutableArray *) selector addObject:entry];	// add selector
		}
}

- (DOMCSSStyleDeclaration *) style; { return style; }
- (void) setStyle:(DOMCSSStyleDeclaration *) s; { ASSIGN(style, s); }

- (NSString *) cssText; { return [NSString stringWithFormat:@"@page%@%@ { %@ }", [selector count] > 0?@" ":@"", [self selectorText], style]; }

@end

@interface DOMCSSStyleRuleSelector : NSObject
{ // see http://www.w3.org/TR/css3-selectors/
@public
	enum
	{
	// leaf elements (simple selector)
	UNIVERSAL_SELECTOR,		// *
	TAG_SELECTOR,			// specific tag
	CLASS_SELECTOR,			// .class
	ID_SELECTOR,			// #id
	ATTRIBUTE_SELECTOR,		// [attr=value]	--- NOTE: there are several variants of this, e.g. [attr] checks for existence
	PSEUDO_SELECTOR,		// :component
	// tree elements (combinators) - the right side may itself be a full rule as in tag > *[attr] (i.e. we must build a tree)
	DESCENDANT_SELECTOR,	// element1 element2
	CHILD_SELECTOR,			// element1>element2
	PRECEDING_SELECTOR,		// element1+element2
	SIBLING_SELECTOR,		// element1~element2
	} type;
	NSString *selector;		// tag, class, id, attr, component
	id value;				// attr value, element1
	int specificity;
}
- (int) specificity;
@end

@implementation DOMCSSStyleRuleSelector

- (void) dealloc
{
	[selector release];
	[value release];
	[super dealloc];
}

- (BOOL) _ruleMatchesElement:(DOMElement *) element pseudoElement:(NSString *) pseudoElement
{
	switch(type)
	{
		case UNIVERSAL_SELECTOR:
			return YES;	// any
		case TAG_SELECTOR:
			// can/should we check for HTML vs. XHTML? XHTML may require case sensitive compare
			return [selector caseInsensitiveCompare:[element tagName]] == NSOrderedSame;	// match tags case-insensitive
		case ID_SELECTOR:
			{
			NSString *val=[element getAttribute:@"id"];
			return val && [selector isEqualToString:val];	// id must be defined and match
			}
		case CLASS_SELECTOR:
			{
			NSString *val=[element getAttribute:@"class"];
			// FIXME: class can be a space separated list of classes
			// order of class names must match the order in the list, i.e. a.class1.class2 matches only if there is <a class="class1 class2">
			// FIXME: what about nesting of clases? Is it sufficient that any parent element defines the class???
			return val && [selector isEqualToString:val];
			}
		case ATTRIBUTE_SELECTOR:
			{
			if(value)
				{ // check value
				NSString *val=[element getAttribute:selector];
				return val && [val isEqualToString:value];
				}
			else
				return [element hasAttribute:selector];
			}
		case PSEUDO_SELECTOR:
			return [selector isEqualToString:pseudoElement];
		case DESCENDANT_SELECTOR:
			// any parent of the Element must match the whole value style rule (which is again an Array)
		case CHILD_SELECTOR:
			// direct parent of the Element must match the whole value style rule (which is again an Array)
		default:
			return NO;	// NOT IMPLEMENTED
	}
}

- (NSString *) cssText;
{
	switch(type)
	{
		case UNIVERSAL_SELECTOR:	return @"*";
		case TAG_SELECTOR:			return selector;
		case CLASS_SELECTOR:		return [NSString stringWithFormat:@".%@", selector];
		case ID_SELECTOR:			return [NSString stringWithFormat:@"#%@", selector];
		case ATTRIBUTE_SELECTOR:	return [NSString stringWithFormat:@"[%@=%@]", selector, value];
		case PSEUDO_SELECTOR:		return [NSString stringWithFormat:@":%@", selector, value];	// may have a paramter!
		case DESCENDANT_SELECTOR:	return [NSString stringWithFormat:@"%@ %@", [(DOMCSSStyleRuleSelector *) value cssText], selector];
		case CHILD_SELECTOR:		return [NSString stringWithFormat:@"%@ > %@", [(DOMCSSStyleRuleSelector *) value cssText], selector];
		case PRECEDING_SELECTOR:	return [NSString stringWithFormat:@"%@ + %@", [(DOMCSSStyleRuleSelector *) value cssText], selector];
		case SIBLING_SELECTOR:		return [NSString stringWithFormat:@"%@ ~ %@", [(DOMCSSStyleRuleSelector *) value cssText], selector];
	}
	return @"?";
}

@end

@implementation DOMCSSStyleRule

- (BOOL) _ruleMatchesElement:(DOMElement *) element pseudoElement:(NSString *) pseudoElement
{ // check if rule matches given element
	NSEnumerator *e=[selector objectEnumerator];	// sequence of elements, i.e. >element.class1.class2#id1:pseudo
	NSArray *sequence;
	while((sequence=[e nextObject]))
		{
		NSEnumerator *f=[sequence objectEnumerator];
		DOMCSSStyleRuleSelector *sel;
		while((sel=[f nextObject]))
			{
			if(![sel _ruleMatchesElement:element pseudoElement:pseudoElement])
				break;	// no match
			}
		if(!sel)
			return YES;	// all selectors did match
		}
	return NO;	// no alternative did match
}

- (unsigned short) type; { return DOM_STYLE_RULE; }

- (id) init;
{
	if((self=[super init]))
		{
		selector=[NSMutableArray new];
		}
	return self;
}

- (void) dealloc
{
	[selector release];
	[style release];
	[super dealloc];
}

- (NSString *) selectorText;
{ // tag class patterns
	NSMutableString *s=[NSMutableString stringWithCapacity:50];
	NSEnumerator *e=[selector objectEnumerator];
	NSArray *alternative;
	while((alternative=[e nextObject]))
		{
		NSEnumerator *f=[alternative objectEnumerator];
		DOMCSSStyleRuleSelector *sel;
		if([s length] > 0)
			[s appendString:@", "];
		while((sel=[f nextObject]))
			{
			if([s length] > 0)
				[s appendFormat:@" %@", [sel cssText]];
			else
				[s appendString:[sel cssText]];
			}
		}
	return s;
}

- (void) setSelectorText:(NSString *) rule;
{ // parse selector into array
	NSScanner *sc;
	static NSCharacterSet *tagchars;
	NSMutableArray *sel;	// selector sequence
	if(!tagchars)
		// FIXME: CSS identifiers follow slightly more complex rules, therefore we should define - (NString *) [DOMCSSRule _identifier:sc]
		tagchars=[[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-"] retain];
	if([rule isKindOfClass:[NSScanner class]])
		sc=(NSScanner *) rule;	// we already got a NSScanner
	else
		sc=[NSScanner scannerWithString:rule];
	sel=[NSMutableArray arrayWithCapacity:5];
	[(NSMutableArray *) selector removeAllObjects];
	[DOMCSSRule _skip:sc];	// skip initial spaces only - other spaces may create a DESCENDANT_SELECTOR
	while(YES)
		{
		DOMCSSStyleRuleSelector *selObj;
		int type=TAG_SELECTOR;	// default
		if([sc scanString:@" " intoString:NULL])
			{ // potentially a DESCENDANT_SELECTOR - or may be space around other combinator
				NSString *str;
				[DOMCSSRule _skip:sc];
				if([sc scanCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"+>~{,;"] intoString:&str])
					{ // not a descendant selector; back up and parse again
						[sc setScanLocation:[sc scanLocation]-[str length]];	// back up
						continue;
					}
				type=DESCENDANT_SELECTOR;
			}
		else if([sc scanString:@">" intoString:NULL])
			type=CHILD_SELECTOR;
		else if([sc scanString:@"+" intoString:NULL])
			type=PRECEDING_SELECTOR;
		else if([sc scanString:@"~" intoString:NULL])
			type=SIBLING_SELECTOR;
		if(type != TAG_SELECTOR)
			{ // is a real combinator
				selObj=[DOMCSSStyleRuleSelector new];
				selObj->type=type;
				selObj->value=[sel retain];	// save element1
				sel=[NSMutableArray arrayWithCapacity:5];	// start to collect element2
				continue;
			}
		else
			{ // primitive selector
				NSString *entry=nil;
				if([sc scanString:@"." intoString:NULL])
					type=CLASS_SELECTOR;
				else if([sc scanString:@"#" intoString:NULL])
					type=ID_SELECTOR;
				else if([sc scanString:@"[" intoString:NULL])
					type=ATTRIBUTE_SELECTOR;
				else if([sc scanString:@"::" intoString:NULL])
					type=PSEUDO_SELECTOR;
				else if([sc scanString:@":" intoString:NULL])
					type=PSEUDO_SELECTOR;
				else if([sc scanString:@"*" intoString:NULL])
					type=UNIVERSAL_SELECTOR;
				else if([sc scanString:@"|" intoString:NULL])
					;	// namespace
				if(type != UNIVERSAL_SELECTOR && ![sc scanCharactersFromSet:tagchars intoString:&entry])
					{
					if(type != TAG_SELECTOR)
						{ // invalid -> drop the complete rule
						[sel removeAllObjects];
						[(NSMutableArray *) selector removeAllObjects];
							// FIXME: we should ship everything until a { appears
						}
					break;	// no element name follows where required
					}
				selObj=[DOMCSSStyleRuleSelector new];
				selObj->type=type;
				selObj->selector=[entry retain];
				if(type == ATTRIBUTE_SELECTOR)
					{ // handle tag[attrib=value]
						// attrib^=value
						// attrib$=value
						// attrib*=value
						// get condition and value
						// value must be CSS identifier or string
						// selObj->value=
					}
				else if(type == PSEUDO_SELECTOR)
					{ // handle :pseudo(n)
					}
			}
		[sel addObject:selObj];
		[selObj release];
		if([sc scanString:@"," intoString:NULL])
			{ // alternative rule set
				[(NSMutableArray *) selector addObject:sel];
				sel=[NSMutableArray arrayWithCapacity:5];
			}
		}
	if([sel count] > 0)
		[(NSMutableArray *) selector addObject:sel];
}

- (DOMCSSStyleDeclaration *) style; { return style; }

// FIXME: should we parse the style here??

- (void) setStyle:(DOMCSSStyleDeclaration *) s; { ASSIGN(style, s); }

- (NSString *) cssText; { return [NSString stringWithFormat:@"%@ { %@ }", [self selectorText], style]; }

- (NSString *) description; { return [self cssText]; }

// setCssText: selector + style?

@end

@implementation DOMCSSUnknownRule

- (NSString *) cssText; { return @"@unknown"; }

@end

@implementation DOMCSSStyleSheet

- (id) init
{
	if((self=[super init]))
		{
		cssRules=[DOMCSSRuleList new];
		}
	return self;
}

- (void) dealloc
{
	[cssRules release];
	[super dealloc];
}

- (void) _setCssText:(NSString *) sheet
{
	NSScanner *scanner=[NSScanner scannerWithString:sheet];
#if 1
	NSLog(@"_setCssText <style>%@</style>", sheet);
#endif
	while(![scanner isAtEnd])
		if([self insertRule:(NSString *) scanner index:[cssRules length]] == (unsigned) -1)	// parse and scan rules
			break;
}

- (BOOL) _refersToHref:(NSString *) ref;
{
	if([href isEqualToString:ref])
		return YES;
	return ownerRule && [ownerRule _refersToHref:ref];	// should be an @import...
}

- (DOMCSSRule *) ownerRule; { return ownerRule; }	// if loaded through @import
- (DOMCSSRuleList *) cssRules; { return cssRules; }

- (unsigned) insertRule:(NSString *) string index:(unsigned) index;
{ // parse rule and insert in cssRules
	DOMCSSRule *rule=[[DOMCSSRule alloc] initWithString:string];
	if(!rule)
		return -1;	// raise exception?
#if 1
	NSLog(@"insert rule: %@", rule);
#endif
	[(NSMutableArray *) [cssRules items] insertObject:rule atIndex:index];
	[rule _setParentStyleSheet:self];
	[rule release];
	return index;
}

- (void) deleteRule:(unsigned) index;
{
	[[(NSMutableArray *) [cssRules items] objectAtIndex:index] _setParentRule:nil];
	[(NSMutableArray *) [cssRules items] removeObjectAtIndex:index];
}

- (NSString *) description;
{
	NSMutableString *s=[NSMutableString stringWithCapacity:50];
	NSEnumerator *e=[[cssRules items] objectEnumerator];
	DOMCSSRule *rule;
	while((rule=[e nextObject]))
		[s appendFormat:@"%@\n", rule];
	return s; 
}

@end

@implementation DOMCSSValue : DOMObject

- (unsigned short) cssValueType; { return cssValueType; }

- (NSString *) cssText;
{
	switch(cssValueType)
	{
		case DOM_CSS_INHERIT: return @"inherit";
		case DOM_CSS_PRIMITIVE_VALUE: return @"subclass";
		case DOM_CSS_VALUE_LIST: return @"value list";
		case DOM_CSS_CUSTOM:
		return @"todo";
	}
	return @"?";
}

- (void) setCssText:(NSString *) str 
{
	NIMP; 
}

- (id) initWithString:(NSString *) str;
{
	NSScanner *sc;
	if([str isKindOfClass:[NSScanner class]])
		sc=(NSScanner *) str;	// we already got a NSScanner
	else
		sc=[NSScanner scannerWithString:str];
	[DOMCSSRule _skip:sc];
	if([sc scanString:@"inherit" intoString:NULL])
		{
		cssValueType=DOM_CSS_INHERIT;
		return self;
		}
	[self release];
	self=[DOMCSSPrimitiveValue new];
	[self setCssText:(NSString *) sc];
	if([sc scanString:@"," intoString:NULL])
		{ // value list
		self=[[DOMCSSValueList alloc] _initWithFirstElement:[self autorelease]];
		do {
			DOMCSSPrimitiveValue *val=[DOMCSSPrimitiveValue new];
			[val setCssText:(NSString *) sc];	// parse next value
			[(DOMCSSValueList *) self _addItem:val];
			[val release];
			} while([sc scanString:@"," intoString:NULL]);
		}
	return self;
}

- (NSString *) description; { return [self cssText]; }

- (NSString *) _toString;
{ // value as string (independent of type)
	switch(cssValueType)
	{
		case DOM_CSS_INHERIT: return @"inherit";
		case DOM_CSS_PRIMITIVE_VALUE: return @"subclass";
		case DOM_CSS_VALUE_LIST: return @"value list";
		case DOM_CSS_CUSTOM:
			return @"todo";
	}
	return @"?";
}

@end

@implementation DOMCSSValueList

- (unsigned short) primitiveType; 
{
	return 0;
}

- (id) _initWithFirstElement:(DOMCSSValue *) first
{
	if(self=[super init])
		{
		values=[[NSMutableArray alloc] initWithObjects:first, nil];
		cssValueType=DOM_CSS_VALUE_LIST;
		}
	return self;
}

- (void) dealloc
{
	[values dealloc];
	[super dealloc];
}

- (NSString *) cssText;
{
	NSEnumerator *e=[values objectEnumerator];
	DOMCSSValue *val;
	NSString *css=@"";
	while((val=[e nextObject]))
		{
		if([css length] > 0)
			css=[css stringByAppendingFormat:@", %@", [val cssText]];
		else
			css=[val cssText];
		}
	return css;
}

- (NSArray *) _toStringArray;
{
	NSEnumerator *e=[values objectEnumerator];
	DOMCSSValue *val;
	NSMutableArray *a=[NSMutableArray arrayWithCapacity:[values count]];
	while((val=[e nextObject]))
		[a addObject:[val _toString]];
	return a;	
}

- (unsigned) length; { return [values count]; }
- (DOMCSSValue *) item:(unsigned) index; { return [values objectAtIndex:index]; }
- (void) _addItem:(DOMCSSValue *) item { [values addObject:item]; }

@end

@implementation DOMCSSPrimitiveValue

- (id) initWithString:(NSString *) str; {
	return NIMP;
}

- (unsigned short) cssValueType { return DOM_CSS_PRIMITIVE_VALUE; }

- (unsigned short) primitiveType; { return primitiveType; }

- (void) dealloc
{
	[stringValue release];
	[super dealloc];
}

- (NSString *) cssText;
{
	NSString *suffix;
	switch(primitiveType)
	{
		default:
		case DOM_CSS_UNKNOWN:	return @"unknown";
		case DOM_CSS_NUMBER: suffix=@""; break;
		case DOM_CSS_PERCENTAGE: suffix=@"%"; break;
		case DOM_CSS_EMS: suffix=@"em"; break;
		case DOM_CSS_EXS: suffix=@"ex"; break;
		case DOM_CSS_PX: suffix=@"px"; break;
		case DOM_CSS_CM: suffix=@"cm"; break;
		case DOM_CSS_MM: suffix=@"mm"; break;
		case DOM_CSS_IN: suffix=@"in"; break;
		case DOM_CSS_PT: suffix=@"pt"; break;
		case DOM_CSS_PC: suffix=@"pc"; break;
		case DOM_CSS_DEG: suffix=@"deg"; break;
		case DOM_CSS_RAD: suffix=@"rad"; break;
		case DOM_CSS_GRAD: suffix=@"grad"; break;
		case DOM_CSS_MS: suffix=@"ms"; break;
		case DOM_CSS_S: suffix=@"s"; break;
		case DOM_CSS_HZ: suffix=@"hz"; break;
		case DOM_CSS_KHZ: suffix=@"khz"; break;
		case DOM_CSS_STRING:
			{
			NSMutableString *s=[[[self getStringValue] mutableCopy] autorelease];
			[s replaceOccurrencesOfString:@"\\" withString:@"\\\\" options:0 range:NSMakeRange(0, [s length])];
			[s replaceOccurrencesOfString:@"\n" withString:@"\\n" options:0 range:NSMakeRange(0, [s length])];
			[s replaceOccurrencesOfString:@"'" withString:@"\\'" options:0 range:NSMakeRange(0, [s length])];
			return [NSString stringWithFormat:@"'%@'", s];
			}
		case DOM_CSS_URI:	return [NSString stringWithFormat:@"url(%@)", [self getStringValue]];
		case DOM_CSS_IDENT: return [self getStringValue];
		case DOM_CSS_ATTR: return [NSString stringWithFormat:@"attr(%@)", [self getStringValue]];
		case DOM_CSS_RGBCOLOR:	return [NSString stringWithFormat:@"rgb(%d, %d, %d)", (int) floatValue/65536, ((int) floatValue/256)%256, ((int) floatValue)%256];
		case DOM_CSS_DIMENSION:
		case DOM_CSS_COUNTER:
		case DOM_CSS_RECT:
		return @"TODO";
	}
	return [NSString stringWithFormat:@"%f%@", [self getFloatValue:primitiveType], suffix];
}

- (NSString *) _toString;
{
	NSString *suffix;
	switch(primitiveType)
	{
		default:
		case DOM_CSS_UNKNOWN:	return @"unknown";
		case DOM_CSS_NUMBER: suffix=@""; break;
		case DOM_CSS_PERCENTAGE: suffix=@"%"; break;
		case DOM_CSS_EMS: suffix=@"em"; break;
		case DOM_CSS_EXS: suffix=@"ex"; break;
		case DOM_CSS_PX: suffix=@"px"; break;
		case DOM_CSS_CM: suffix=@"cm"; break;
		case DOM_CSS_MM: suffix=@"mm"; break;
		case DOM_CSS_IN: suffix=@"in"; break;
		case DOM_CSS_PT: suffix=@"pt"; break;
		case DOM_CSS_PC: suffix=@"pc"; break;
		case DOM_CSS_DEG: suffix=@"deg"; break;
		case DOM_CSS_RAD: suffix=@"rad"; break;
		case DOM_CSS_GRAD: suffix=@"grad"; break;
		case DOM_CSS_MS: suffix=@"ms"; break;
		case DOM_CSS_S: suffix=@"s"; break;
		case DOM_CSS_HZ: suffix=@"hz"; break;
		case DOM_CSS_KHZ: suffix=@"khz"; break;
		case DOM_CSS_STRING: return stringValue;
		case DOM_CSS_URI:	return stringValue;
		case DOM_CSS_IDENT: return stringValue;
		case DOM_CSS_ATTR: return stringValue;
		case DOM_CSS_RGBCOLOR:	return [NSString stringWithFormat:@"#%02x%02x%02x", (int) floatValue/65536, ((int) floatValue/256)%256, ((int) floatValue)%256];
		case DOM_CSS_DIMENSION:
		case DOM_CSS_COUNTER:
		case DOM_CSS_RECT:
			return @"TODO";
	}
	return [NSString stringWithFormat:@"%f%@", [self getFloatValue:primitiveType], suffix];
}

- (NSArray *) _toStringArray; {	return [NSArray arrayWithObject:[self _toString]]; }

- (void) setCssText:(NSString *) str
{ // set from CSS string
	NSScanner *sc;
	static NSCharacterSet *identChars;
	if(!identChars)
		identChars=[[NSCharacterSet characterSetWithCharactersInString:@"-abcdefghijklmnopqrstuvwxyz_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"] retain];
	if([str isKindOfClass:[NSScanner class]])
		sc=(NSScanner *) str;	// we already got a NSScanner
	else
		sc=[NSScanner scannerWithString:str];
	[DOMCSSRule _skip:sc];
	if([sc scanString:@"\"" intoString:NULL])
		{ // double-quoted
			// FIXME: handle escape sequences
			if([sc scanUpToString:@"\"" intoString:&stringValue])
				[stringValue retain];
			else
				stringValue=@"";
			[sc scanString:@"\"" intoString:NULL];
			primitiveType=DOM_CSS_STRING;
			return;
		}
	if([sc scanString:@"\'" intoString:NULL])
		{ // single-quoted
			// FIXME: handle escape sequences
			if([sc scanUpToString:@"\'" intoString:&stringValue])
				[stringValue retain];
			else
				stringValue=@"";
			[sc scanString:@"\'" intoString:NULL];
			primitiveType=DOM_CSS_STRING;
			return;
		}
	if([sc scanString:@"#" intoString:NULL])
		{ // hex value
			unsigned intValue=0;
			unsigned int sl=[sc scanLocation];	// to determine length
			[sc scanHexInt:&intValue];
			if([sc scanLocation] - sl <= 4)
				{ // short hex - convert into full value
					unsigned fullValue=0;
					int i;
#if 0
					NSLog(@"translate %x", intValue);
#endif
					for(i=0; i<4; i++)
						{
						fullValue=(fullValue<<8)+0x11*((intValue>>12)&0xf);
						intValue <<= 4;
						}
#if 0
					NSLog(@"   --> %x", fullValue);
#endif
					floatValue=fullValue;
				}
			else
				floatValue=intValue;
			primitiveType=DOM_CSS_RGBCOLOR;
			return;
		}
	if([sc scanFloat:&floatValue])
		{ // double value
//			[DOMCSSRule _skip:sc];
			if([sc scanString:@"%" intoString:NULL]) primitiveType=DOM_CSS_PERCENTAGE;
			else if([sc scanString:@"em" intoString:NULL]) primitiveType=DOM_CSS_EMS;
			else if([sc scanString:@"ex" intoString:NULL]) primitiveType=DOM_CSS_EXS;
			else if([sc scanString:@"px" intoString:NULL]) primitiveType=DOM_CSS_PX;
			else if([sc scanString:@"cm" intoString:NULL]) primitiveType=DOM_CSS_CM, floatValue*=0.01;	// convert to meters
			else if([sc scanString:@"mm" intoString:NULL]) primitiveType=DOM_CSS_MM, floatValue*=0.001;
			else if([sc scanString:@"in" intoString:NULL]) primitiveType=DOM_CSS_IN, floatValue*=0.0254;
			else if([sc scanString:@"pt" intoString:NULL]) primitiveType=DOM_CSS_PT, floatValue*=0.0254/72;
			else if([sc scanString:@"pc" intoString:NULL]) primitiveType=DOM_CSS_PC;
			else if([sc scanString:@"deg" intoString:NULL]) primitiveType=DOM_CSS_DEG;	// convert to ?
			else if([sc scanString:@"rad" intoString:NULL]) primitiveType=DOM_CSS_RAD;
			else if([sc scanString:@"grad" intoString:NULL]) primitiveType=DOM_CSS_GRAD;
			else if([sc scanString:@"ms" intoString:NULL]) primitiveType=DOM_CSS_MS, floatValue*=0.001;	// convert to seconds
			else if([sc scanString:@"s" intoString:NULL]) primitiveType=DOM_CSS_S;
			else if([sc scanString:@"hz" intoString:NULL]) primitiveType=DOM_CSS_HZ;
			else if([sc scanString:@"khz" intoString:NULL]) primitiveType=DOM_CSS_KHZ, floatValue*=1000.0;	// convert to hz
			else primitiveType=DOM_CSS_NUMBER;	// number without units
			return;
		}
	if([sc scanCharactersFromSet:identChars intoString:&stringValue])
		{ // appears to be a valid token
			primitiveType=DOM_CSS_IDENT;
			[DOMCSSRule _skip:sc];
			/*
			 DOM_CSS_DIMENSION = 18,
			 DOM_CSS_RECT = 24,
			 */				
			if([sc scanString:@"(" intoString:NULL])
				{ // "functional" token
					if([stringValue isEqualToString:@"rgb"])
						{ // rgb(r, g, b)
							DOMCSSValue *val=[[DOMCSSValue alloc] initWithString:(NSString *) sc];	// parse argument(s)
							NSArray *args=[val _toStringArray];
							unsigned rgb=0;
							int i;
							for(i=0; i<=2 && i < [args count]; i++)
								{
								NSString *component=[args objectAtIndex:i];
								float c=[component floatValue];
								if([component hasSuffix:@"%"])
									c=(255.0*c)/100.0;
								rgb=(rgb << 8) + (((unsigned) c) % 256);
								}
							floatValue=rgb;
							[val release];
							primitiveType=DOM_CSS_RGBCOLOR;
						}
					else if([stringValue isEqualToString:@"url"])
						{ // url(location) or url("location")
							DOMCSSValue *val=[[DOMCSSValue alloc] initWithString:(NSString *) sc];
							stringValue=[val _toString];	// get unquoted or quoted value
							[val release];
							primitiveType=DOM_CSS_URI;
						}
					else if([stringValue isEqualToString:@"attr"])
						{ // attr(name)
							DOMCSSValue *val=[[DOMCSSValue alloc] initWithString:(NSString *) sc];	// parse argument(s)
							// handle value
							[val release];
							primitiveType=DOM_CSS_ATTR;
						}
					else if([stringValue isEqualToString:@"counter"])
						{ // counter(ident) or counter(ident, list-style-type)
							DOMCSSValue *val=[[DOMCSSValue alloc] initWithString:(NSString *) sc];	// parse argument(s)
							// handle value
							[val release];
							primitiveType=DOM_CSS_COUNTER;
						}
					else 	primitiveType=DOM_CSS_UNKNOWN;
					[sc scanString:@")" intoString:NULL];					
				}
			[stringValue retain];
			return;
		}
	primitiveType=DOM_CSS_UNKNOWN;
}

- (void) setFloatValue:(unsigned short) unitType floatValue:(float) floatValue;
{
	// check if unitType is valid for floats
}

- (float) getFloatValue:(unsigned short) unitType;
{ // convert to unitType if requested
	if(unitType != primitiveType)
		;
	switch(primitiveType)
	{
		case DOM_CSS_NUMBER: return floatValue;
		case DOM_CSS_PERCENTAGE: return 100.0*floatValue;
		case DOM_CSS_EMS: return floatValue;
		case DOM_CSS_EXS: return floatValue;
		case DOM_CSS_PX: return floatValue;
		case DOM_CSS_CM: return 100.0*floatValue;
		case DOM_CSS_MM: return 1000.0*floatValue;
		case DOM_CSS_IN: return floatValue;
		case DOM_CSS_PT: return floatValue;
		case DOM_CSS_PC: return floatValue;
		case DOM_CSS_DEG: return floatValue;
		case DOM_CSS_RAD: return floatValue;
		case DOM_CSS_GRAD: return floatValue;
		case DOM_CSS_MS: return floatValue;
		case DOM_CSS_S: return floatValue;
		case DOM_CSS_HZ: return floatValue;
		case DOM_CSS_KHZ: return floatValue;
	}
	return 0.0;
}

- (void) setStringValue:(unsigned short) stringType stringValue:(NSString *) stringValue;
{
	// only for ident, attr, string?
	// or should we run the parser here?
}

- (NSString *) getStringValue;
{
	return stringValue;
}

//- (DOMCounter *) getCounterValue;
//- (DOMRect *) getRectValue;
//- (DOMRGBColor *) getRGBColorValue;
//- (NSColor *) getRGBAColorValue;

@end
