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
#import <WebKit/WebResource.h>
#import <WebKit/DOMHTML.h>
#import "Private.h"

@interface DOMStyleSheetList (Private)
- (void) _addStyleSheet:(DOMStyleSheet *) sheet;
@end

@interface DOMCSSStyleSheet (Private)
- (BOOL) _refersToHref:(NSString *) ref;
@end

@interface DOMCSSRule (Private)
+ (NSScanner *) _scannerForString:(NSString *) string;	// string may already be a scanner!
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
@end

@interface DOMCSSValue (Private)
- (id) initWithString:(NSString *) str;
- (NSString *) _toString;	// value as string (independent of type)
- (NSArray *) _toStringArray;
- (float) getFloatValue:(unsigned short) unitType relativeTo100Percent:(float) base andFont:(NSFont *) font;
- (NSColor *) _getNSColorValue;
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

- (id) init;
{
	if((self=[super init]))
		{
		items=[[NSMutableDictionary alloc] initWithCapacity:10];
		priorities=[[NSMutableDictionary alloc] initWithCapacity:10];
		}
	return self;
}

- (id) initWithString:(NSString *) style;
{ // scan a style declaration
	if((self=[self init]))
		[self setCssText:style];
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
 * some missing values are set to 'initial' while others are 'inherit'
 * duplicates remain duplicate (!), i.e. the priority/cascading rules have to choose between duplicates
 
*/

- (BOOL) _handleProperty:(NSString *) property withScanner:(NSScanner *) sc;
{ // check for and translate shorthand properties; see: http://www.dustindiaz.com/css-shorthand/
	DOMCSSValue *val=[[[DOMCSSValue alloc] initWithString:(NSString *) sc] autorelease];	// at least one
	BOOL inherit=[val cssValueType] == DOM_CSS_INHERIT;
#if 0
	NSLog(@"_handleProperty: %@", property);
#endif	
	if([property isEqualToString:@"margin"] || [property isEqualToString:@"padding"])
		{ // margin/padding: [ width | percent | auto ] { 1, 4 } | inherit - not inherited by default
			DOMCSSValue *top=inherit?val:nil;
			DOMCSSValue *right=inherit?val:nil;
			DOMCSSValue *bottom=inherit?val:nil;
			DOMCSSValue *left=inherit?val:nil;
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
			if(top) [items setObject:top forKey:[property stringByAppendingString:@"-top"]];
			if(right) [items setObject:right forKey:[property stringByAppendingString:@"-right"]];
			if(bottom) [items setObject:bottom forKey:[property stringByAppendingString:@"-bottom"]];
			if(left) [items setObject:left forKey:[property stringByAppendingString:@"-left"]];
			return YES;
		}
	if([property isEqualToString:@"border"]
	   || [property isEqualToString:@"outline"]
	   || [property isEqualToString:@"border-top"]
	   || [property isEqualToString:@"border-right"]
	   || [property isEqualToString:@"border-bottom"]
	   || [property isEqualToString:@"border-left"])
		{ // border: [ border-width || border-style || border-color ] | inherit; - not inherited by default
			DOMCSSValue *width=inherit?val:nil;
			DOMCSSValue *style=inherit?val:nil;
			DOMCSSValue *color=inherit?val:nil;
			if(!inherit)
				{
				while([val cssValueType] == DOM_CSS_PRIMITIVE_VALUE && [(DOMCSSPrimitiveValue *) val primitiveType] != DOM_CSS_UNKNOWN)
					{ // collect values (they differ by type: numeric -> width; identifier -> style; color -> color)
						switch([(DOMCSSPrimitiveValue *) val primitiveType]) {
							case DOM_CSS_RGBCOLOR:
							case DOM_CSS_RGBACOLOR:
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
			if(width) [items setObject:width forKey:[property stringByAppendingString:@"-width"]];
			if(style) [items setObject:style forKey:[property stringByAppendingString:@"-style"]];
			if(color) [items setObject:color forKey:[property stringByAppendingString:@"-color"]];
			return YES;
		}
	if([property isEqualToString:@"list-style"])
		{ // list-style: [ -type || -image || -position ] | inherit -- default is inherit
			DOMCSSValue *type=inherit?val:nil;
			DOMCSSValue *image=inherit?val:nil;
			DOMCSSValue *position=inherit?val:nil;
			if(!inherit)
				{
				NSLog(@"please implement '%@' shorthand urgently!", property);
				// FIXME
				}
			if(type) [items setObject:type forKey:[property stringByAppendingString:@"-type"]];
			if(image) [items setObject:image forKey:[property stringByAppendingString:@"-image"]];
			if(position) [items setObject:position forKey:[property stringByAppendingString:@"-position"]];
			return YES;
		}
	if([property isEqualToString:@"background"])
		{ // background: [ -color || -image || -repeat || -attachment || -position ] | inherit -- not inherited by default
			DOMCSSValue *color=inherit?val:nil;
			DOMCSSValue *image=inherit?val:nil;
			DOMCSSValue *repeat=inherit?val:nil;
			DOMCSSValue *attachment=inherit?val:nil;
			DOMCSSValue *position=inherit?val:nil;
			if(!inherit)
				{
				NSLog(@"please implement '%@' shorthand urgently!", property);
				// FIXME
				// we must loop over arguments and check if they are color, image, repeat, position etc.
				// and distribute/overwrite the DOMCSSValue
				}
			if(color) [items setObject:color forKey:[property stringByAppendingString:@"-color"]];
			if(image) [items setObject:image forKey:[property stringByAppendingString:@"-image"]];
			if(repeat) [items setObject:repeat forKey:[property stringByAppendingString:@"-repeat"]];
			if(attachment) [items setObject:attachment forKey:[property stringByAppendingString:@"-attachment"]];
			if(position) [items setObject:position forKey:[property stringByAppendingString:@"-position"]];
			return YES;
		}
	if([property isEqualToString:@"font"])
		{ // font: [[ -style || -variant || -weight] -size [ / -height ] -family ] | caption | icon | menu | ... | inherit - default is inherit
			DOMCSSValue *style=val;
			DOMCSSValue *variant=val;
			DOMCSSValue *weight=val;
			DOMCSSValue *size=val;
			DOMCSSValue *height=val;
			DOMCSSValue *family=val;
			if(!inherit)
				{
				NSString *str=[val _toString];
				if([str isEqualToString:@"caption"])
					;
				else if([str isEqualToString:@"icon"])
					;
				else if([str isEqualToString:@"menu"])
					;
				else if([str isEqualToString:@"messge-box"])
					;
				else if([str isEqualToString:@"status-bar"])
					;
				else
					{
					while(val && ([val cssValueType] != DOM_CSS_PRIMITIVE_VALUE || [(DOMCSSPrimitiveValue *) val primitiveType] != DOM_CSS_UNKNOWN))
						{ // collect values
#if 1
							NSLog(@"val: %@", val);
#endif
							if([(DOMCSSPrimitiveValue *) val cssValueType] == DOM_CSS_VALUE_LIST)
								family=val;
							else if([val cssValueType] == DOM_CSS_PRIMITIVE_VALUE)
								{
								switch([(DOMCSSPrimitiveValue *) val primitiveType]) {
									case DOM_CSS_RGBCOLOR:
									case DOM_CSS_RGBACOLOR:
										break;
									case DOM_CSS_IDENT: {
										NSString *str=[(DOMCSSPrimitiveValue *) val getStringValue];
										if([str isEqualToString:@"normal"] || [str isEqualToString:@"bold"] || [str isEqualToString:@"bolder"] || [str isEqualToString:@"lighter"])
											weight=val;
										else if([str isEqualToString:@"small-caps"])
											variant=val;
										else if([str isEqualToString:@"italic"] || [str isEqualToString:@"oblique"])
											style=val;
										else if([str isEqualToString:@"xx-small"] || [str isEqualToString:@"x-small"] || [str isEqualToString:@"small"] ||
												[str isEqualToString:@"medium"] || [str isEqualToString:@"large"] || [str isEqualToString:@"x-large"] ||
												[str isEqualToString:@"xx-large"] || [str isEqualToString:@"smaller"] || [str isEqualToString:@"larger"])
											size=val;
										else
											family=val;	// take as a font-family name
										}
									case DOM_CSS_NUMBER:
										weight=val;	// some absolute value is treated as font-weight and not as font-size
									default:
										size=val;
										break;
									}
								}
							[DOMCSSRule _skip:sc];
							if([sc scanString:@"/" intoString:NULL])
								height=[[[DOMCSSValue alloc] initWithString:(NSString *) sc] autorelease];						
							val=[[[DOMCSSValue alloc] initWithString:(NSString *) sc] autorelease];
						}
					}
				}
			if(style) [items setObject:style forKey:[property stringByAppendingString:@"-style"]];
			if(variant) [items setObject:variant forKey:[property stringByAppendingString:@"-variant"]];
			if(weight) [items setObject:weight forKey:[property stringByAppendingString:@"-weight"]];
			if(size) [items setObject:size forKey:[property stringByAppendingString:@"-size"]];
			if(height) [items setObject:height forKey:@"line-height"];
			if(family) [items setObject:family forKey:[property stringByAppendingString:@"-family"]];
			return YES;
		}
	if([property isEqualToString:@"pause"] || [property isEqualToString:@"cue"])
		{ // pause: [[ time | percent ]{1,2} | inherit - not inherited by default
			// cue: [ cue-before || cue-after ] | inherit
			DOMCSSValue *before=inherit?val:nil;
			DOMCSSValue *after=inherit?val:nil;
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
			if(before) [items setObject:before forKey:[property stringByAppendingString:@"-before"]];
			if(after) [items setObject:after forKey:[property stringByAppendingString:@"-after"]];
			return YES;
		}
	[items setObject:val forKey:property];	// not a shorthand, i.e. a single-value
	return NO;
}

- (void) setCssText:(NSString *) style
{
	NSScanner *sc;
	static NSCharacterSet *propertychars;
#if 0
	NSLog(@"setCssText: %@", style);
#endif
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
//		BOOL sh;
		[DOMCSSRule _skip:sc];
		if(![sc scanCharactersFromSet:propertychars intoString:&propertyName])
			break;
		[DOMCSSRule _skip:sc];				
		if(![sc scanString:@":" intoString:NULL])
			break;	// invalid
		/* sh= */[self _handleProperty:propertyName withScanner:sc];
#if 0
		NSLog(@"items: %@", items);
#endif			
		[DOMCSSRule _skip:sc];
		// FIXME: there may be a space between ! and "important"
		// see e.g. http://www.yellowjug.com/web-design/the-importance-of-important-in-css/
		// FIXME: how does this work for shorthand properties?
		if(![sc scanString:@"important" intoString:&priority])
			[sc scanString:@"!important" intoString:&priority];
		[priorities setObject:priority forKey:propertyName];
		[DOMCSSRule _skip:sc];
		// FIXME: shorthand properties are allowed without ;
		// maybe we should simply detect if the next character is a } and accept a missing ;
		if(![sc scanString:@";" intoString:NULL])
			{ // missing ; - try to recover
				static NSCharacterSet *recover;	// cache once
				NSString *skipped=@"";
				if(!recover)
					recover=[[NSCharacterSet characterSetWithCharactersInString:@";}"] retain];
				[sc scanUpToCharactersFromSet:recover intoString:&skipped];
#if 1
				if([skipped length] > 0)
					NSLog(@"CSS text skipped: %@", skipped);
#endif
				[sc scanString:@";" intoString:NULL];
				break;
			}
		}
	// trigger re-layout of ownerDocumentView
}

- (NSString *) getPropertyValue:(NSString *) propertyName; { return [[items objectForKey:propertyName] cssText]; }
- (DOMCSSValue *) getPropertyCSSValue:(NSString *) propertyName; { return [items objectForKey:propertyName]; }
- (NSString *) removeProperty:(NSString *) propertyName; { [items removeObjectForKey:propertyName]; return propertyName; }
- (NSString *) getPropertyPriority:(NSString *) propertyName; { return [priorities objectForKey:propertyName]; }

// FXIME: didn't the analysis show that we can store duplicates?

- (void) setProperty:(NSString *) propertyName value:(NSString *) value priority:(NSString *) priority;
{
	if(!priority) priority=@"";
	[items setObject:[[[DOMCSSValue alloc] initWithString:value] autorelease] forKey:propertyName]; 
	[priorities setObject:priority forKey:propertyName]; 
}

- (void) setProperty:(NSString *) propertyName CSSvalue:(DOMCSSValue *) value priority:(NSString *) priority;
{
	if(!priority) priority=@"";
	[items setObject:value forKey:propertyName]; 
	[priorities setObject:priority forKey:propertyName]; 
}

- (void) _append:(DOMCSSStyleDeclaration *) other
{ // append property values
	NSEnumerator *e=[[[other _items] allKeys] objectEnumerator];
	NSString *property;
	while((property=[e nextObject]))
		[self setProperty:property CSSvalue:[other getPropertyCSSValue:property] priority:[other getPropertyPriority:property]];
}

- (unsigned) length; { return [items count]; }
- (NSString *) item:(unsigned) index; { return [[items allKeys] objectAtIndex:index]; }

- (NSString *) getPropertyShorthand:(NSString *) propertyName;
{ // convert property-name into camelCase propertyName to allow JS access by dotted notation
	// FIXME:
	// componentsSeparatedByString:@"-"
	// 2..n: first character to Uppercase
	// componentsJoinedByString:@""
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

+ (NSScanner *) _scannerForString:(NSString *) string
{
	if([string isKindOfClass:[NSScanner class]])
		return (NSScanner *) string;	// we already got a NSScanner
	return [NSScanner scannerWithString:string];
}

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
				{
				[self release];
				return nil;
				}
			while([DOMCSSRule _skip:sc], ![sc isAtEnd])
				{
				if([(DOMCSSMediaRule *) self insertRule:(NSString *) sc index:[[(DOMCSSMediaRule *) self cssRules] length]] == (unsigned) -1)	// parse and scan rules
					break;
				}
			if(![sc scanString:@"}" intoString:NULL])
				{ // not closed properly - try to recover
					NSString *skipped=@"";
					[sc scanUpToString:@"}" intoString:&skipped];
#if 1
					if([skipped length] > 0)
						NSLog(@"CSS text skipped: %@", skipped);
#endif
					[sc scanString:@"}" intoString:NULL];
				}
			return self;
		}
	if([sc scanString:@"@charset" intoString:NULL])
		{ // @charset "UTF-8";
			DOMCSSValue *val=[[[DOMCSSValue alloc] initWithString:(NSString *) sc] autorelease];
			return [[DOMCSSCharsetRule alloc] initWithEncoding:[val _toString]];
		}
	if([sc scanString:@"@font-face" intoString:NULL])
		{ // @font-face { font-family: name src: url(path) ... more properties } http://www.w3schools.com/cssref/css3_pr_font-face_rule.asp
			// for an example we should be compatible with see http://www.fontspring.com/blog/further-hardening-of-the-bulletproof-syntax
			return [DOMCSSFontFaceRule new];
		}
	if([sc scanString:@"@namespace" intoString:NULL])	// is not standard (?)
		{ // @namespace d url(http://www.apple.com/DTDs/DictionaryService-1.0.rng);
			return [DOMCSSUnknownRule new];
		}
	if([sc scanString:@"@page" intoString:NULL])
		{ // @page optional-name :header|:footer|:left|:right { style; style; ... }
			self=[DOMCSSPageRule new];
			// FIXME:
			// check for name definition
		}	// although we cast to DOMCSSStyleRule below, the DOMCSSPageRule provides the same methods
	else if([sc scanString:@"@" intoString:NULL])
		{ // unknown @ operator
			NSLog(@"DOMCSSRule: unknown @ operator");
			// FIXME: ignore up to ; or including block - must match { and }
			// see http://www.w3.org/TR/1998/REC-CSS2-19980512/syndata.html#block section 4.2
			return nil;
		}
	else	/* no operator */
		self=[[DOMCSSStyleRule alloc] init];
	[(DOMCSSStyleRule *) self setSelectorText:(NSString *) sc];	// set from scanner
	// how do we handle parse errors here? e.g. if selector is empty
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
		{
			NSString *skipped=@"";
			[sc scanUpToString:@"}" intoString:&skipped];	// try to recover from parse errors
#if 1
		if([skipped length] > 0)
			NSLog(@"CSS text skipped: %@", skipped);
#endif
			[sc scanString:@"}" intoString:NULL];		// and skip!
		}
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

- (id) init;
{
	if((self=[super init]))
		{
		media=[DOMMediaList new];
		}
	return self;
}

- (id) initWithHref:(NSString *) uri;
{
	if((self=[self init]))
		{
		href=[uri retain];
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
	if(styleSheet)
		return;	// already loaded
	if(href)
		{
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
	else
		{
		NSLog(@"@import: nil href!");
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
	NSLog(@"%@ receivedData: %u", NSStringFromClass([self class]), [[source data] length]);
}

- (void) receivedError:(NSError *) error withDataSource:(WebDataSource *) source;
{ // default error handler
	NSLog(@"%@ receivedError: %@", NSStringFromClass([self class]), error);
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

- (id) init;
{
	if((self=[super init]))
		{
		media=[DOMMediaList new];
		cssRules=[DOMCSSRuleList new];
		}
	return self;
}

- (id) initWithMedia:(NSString *) m;
{
	if((self=[self init]))
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
		[media setMediaText:m];	// scan media list
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
	enum
	{
	// leaf elements (simple selector)
	UNIVERSAL_SELECTOR,		// *
	TAG_SELECTOR,			// specific tag
	CLASS_SELECTOR,			// .class
	ID_SELECTOR,			// #id
	ATTRIBUTE_SELECTOR,		// [attr]
	ATTRIBUTE_LIST_SELECTOR,	// [attr~=val]
	ATTRIBUTE_DASHED_SELECTOR,	// [attr|=val]
	ATTRIBUTE_PREFIX_SELECTOR,	// [attr^=val]
	ATTRIBUTE_SUFFIX_SELECTOR,	// [attr$=val]
	ATTRIBUTE_CONTAINS_SELECTOR,	// [attr*=val]
	ATTRIBUTE_MATCH_SELECTOR,		// [attr=val]
	PSEUDO_SELECTOR,		// :component
	// tree elements (combinators) - the right side may itself be a full rule as in tag > *[attr] (i.e. we must build a tree)
	CONDITIONAL_SELECTOR,	// element1element2
	DESCENDANT_SELECTOR,	// element1 element2
	ALTERNATIVE_SELECTOR,	// element1, element2
	CHILD_SELECTOR,			// element1>element2
	PRECEDING_SELECTOR,		// element1+element2
	SIBLING_SELECTOR,		// element1~element2
	} type;
	id selector;			// tag, class, id, attr, component, left combinator
	id value;				// attr value, right combinator
	int specificity;
}
- (NSString *) cssText;
- (void) setCSSText:(NSString *) rule;
- (int) type;
- (id) selector;
- (id) value;
- (int) specificity;
@end

@implementation DOMCSSStyleRuleSelector

- (DOMCSSStyleRuleSelector *) copyWithZone:(NSZone *) zone
{
	DOMCSSStyleRuleSelector *s=[DOMCSSStyleRuleSelector new];
	s->selector=[selector retain];
	s->value=[value retain];
	s->type=type;
	s->specificity=specificity;
	return s;
}

- (int) type
{
	return type;
}

- (id) selector
{
	return selector;
}

- (id) value
{
	return value;
}

- (int) specificity;
{
	NIMP;
	return 0;
}

- (void) dealloc
{
	[selector release];
	[value release];
	[super dealloc];
}

- (BOOL) _ruleMatchesElement:(DOMElement *) element pseudoElement:(NSString *) pseudoElement
{
	switch(type) {
		case UNIVERSAL_SELECTOR:
			return YES;	// any
		case TAG_SELECTOR:
			// can/should we check for HTML vs. XHTML? XHTML may require case sensitive compare
			return [selector caseInsensitiveCompare:[element tagName]] == NSOrderedSame;	// match tags case-insensitive
		case ID_SELECTOR: {
			NSString *val=[element getAttribute:@"id"];
			return val && [selector isEqualToString:val];	// id must be defined and match
			}
		case CLASS_SELECTOR: {
			NSArray *val=[[element getAttribute:@"class"] componentsSeparatedByString:@" "]; // class can be a space separated list of classes
			return val && [val containsObject:selector];	// the class in the selector matches any class specified
			}
		case ATTRIBUTE_SELECTOR: { // existence of attribute
				return [element hasAttribute:selector];
			}
		case ATTRIBUTE_MATCH_SELECTOR: { // check value of attribute
				NSString *val=[element getAttribute:selector];
				return val && [val isEqualToString:[value _toString]];
			}
		case ATTRIBUTE_PREFIX_SELECTOR: {
			NSString *val=[element getAttribute:selector];
			return val && [val hasPrefix:[value _toString]];
		}
		case ATTRIBUTE_SUFFIX_SELECTOR: {
			NSString *val=[element getAttribute:selector];
			return val && [val hasSuffix:[value _toString]];
		}
		case ATTRIBUTE_CONTAINS_SELECTOR: { // attributes contains substring
			NSString *val=[element getAttribute:selector];
			return val && [val rangeOfString:[value _toString]].location != NSNotFound;
		}
		case ATTRIBUTE_LIST_SELECTOR: {	// attribute is a list and contains value
			NSString *val=[element getAttribute:selector];
			if(!val) return NO;
			return [[val componentsSeparatedByString:@" "] containsObject:[value _toString]];	// contains string
		}
		case ATTRIBUTE_DASHED_SELECTOR: { // exactly the same or begins with "value-"
			NSString *val=[element getAttribute:selector];
			return val && ([val isEqualToString:[value _toString]] || [val hasPrefix:[[value _toString] stringByAppendingString:@"-"]]);
		}
		case PSEUDO_SELECTOR:
			return [selector isEqualToString:pseudoElement];
		case ALTERNATIVE_SELECTOR:
			return [selector _ruleMatchesElement:element pseudoElement:pseudoElement] || [value _ruleMatchesElement:element pseudoElement:pseudoElement];
		case CONDITIONAL_SELECTOR:
			return [selector _ruleMatchesElement:element pseudoElement:pseudoElement] && [value _ruleMatchesElement:element pseudoElement:pseudoElement];
		case DESCENDANT_SELECTOR: {
			// any parent of the Element must match the whole value style rule
			// e.g. "*.class1 td.class2 means that any parent on any level above the td can match class1
			DOMElement *parent=element;
			if(![value _ruleMatchesElement:element pseudoElement:pseudoElement])
				return NO;	// right side does not match
			while((parent=(DOMElement *)[parent parentNode]) && [parent isKindOfClass:[DOMElement class]])
				{
				if([value _ruleMatchesElement:parent pseudoElement:pseudoElement])
					return YES;	// left side rule does match this parent level
				}
			return NO;	// no parent matches left side
			}
		case CHILD_SELECTOR: {
			// direct parent of the Element must match the whole value style rule
			DOMElement *parent;
			if(![value _ruleMatchesElement:element pseudoElement:pseudoElement])
				return NO;	// right side does not match
			parent=(DOMElement *)[element parentNode];
			return [parent isKindOfClass:[DOMElement class]] && [value _ruleMatchesElement:parent pseudoElement:pseudoElement];
			}
		case PRECEDING_SELECTOR: {
			// previous sibling of the Element must match the whole value style rule
			DOMElement *sibling;
			if(![value _ruleMatchesElement:element pseudoElement:pseudoElement])
				return NO;	// right side does not match
			sibling=(DOMElement *)[element previousSibling];
			return [sibling isKindOfClass:[DOMElement class]] && [value _ruleMatchesElement:sibling pseudoElement:pseudoElement];
		}
		case SIBLING_SELECTOR: {
			// any sibling of the Element must match the whole value style rule
#ifdef FIXME
			DOMElement *sibling;
			if(![value _ruleMatchesElement:element pseudoElement:pseudoElement])
				return NO;	// right side does not match
			sibling=[element previousSibling];
			return sibling && [value _ruleMatchesElement:sibling pseudoElement:pseudoElement];
#endif
		}
	}
	return NO;	// NOT IMPLEMENTED
}

- (NSString *) cssText;
{
	switch(type) {
		case UNIVERSAL_SELECTOR:	return @"*";
		case TAG_SELECTOR:			return selector;
		case CLASS_SELECTOR:		return [NSString stringWithFormat:@".%@", selector];
		case ID_SELECTOR:			return [NSString stringWithFormat:@"#%@", selector];
		case ATTRIBUTE_SELECTOR:	return [NSString stringWithFormat:@"[%@]", selector];
		case ATTRIBUTE_MATCH_SELECTOR:	return [NSString stringWithFormat:@"[%@=%@]", selector, [(DOMCSSValue *) value cssText]];
		case ATTRIBUTE_PREFIX_SELECTOR:	return [NSString stringWithFormat:@"[%@^=%@]", selector, [(DOMCSSValue *) value cssText]];
		case ATTRIBUTE_SUFFIX_SELECTOR:	return [NSString stringWithFormat:@"[%@$=%@]", selector, [(DOMCSSValue *) value cssText]];
		case ATTRIBUTE_CONTAINS_SELECTOR:	return [NSString stringWithFormat:@"[%@*=%@]", selector, [(DOMCSSValue *) value cssText]];
		case ATTRIBUTE_LIST_SELECTOR:	return [NSString stringWithFormat:@"[%@~=%@]", selector, [(DOMCSSValue *) value cssText]];
		case ATTRIBUTE_DASHED_SELECTOR:	return [NSString stringWithFormat:@"[%@|=%@]", selector, [(DOMCSSValue *) value cssText]];
		case PSEUDO_SELECTOR:
			if(value)
				return [NSString stringWithFormat:@":%@(%@)", selector, [(DOMCSSValue *) value cssText]];	// may have a paramter!
			return [NSString stringWithFormat:@":%@", selector];
		case CONDITIONAL_SELECTOR:	return [NSString stringWithFormat:@"%@%@", [(DOMCSSStyleRuleSelector *) selector cssText], [(DOMCSSStyleRuleSelector *) value cssText]];
		case DESCENDANT_SELECTOR:	return [NSString stringWithFormat:@"%@ %@", [(DOMCSSStyleRuleSelector *) selector cssText], [(DOMCSSStyleRuleSelector *) value cssText]];
		case ALTERNATIVE_SELECTOR:	return [NSString stringWithFormat:@"%@, %@", [(DOMCSSStyleRuleSelector *) selector cssText], [(DOMCSSStyleRuleSelector *) value cssText]];
		case CHILD_SELECTOR:		return [NSString stringWithFormat:@"%@ > %@", [(DOMCSSStyleRuleSelector *) selector cssText], [(DOMCSSStyleRuleSelector *) value cssText]];
		case PRECEDING_SELECTOR:	return [NSString stringWithFormat:@"%@ + %@", [(DOMCSSStyleRuleSelector *) selector cssText], [(DOMCSSStyleRuleSelector *) value cssText]];
		case SIBLING_SELECTOR:		return [NSString stringWithFormat:@"%@ ~ %@", [(DOMCSSStyleRuleSelector *) selector cssText], [(DOMCSSStyleRuleSelector *) value cssText]];
	}
	return @"?";
}

- (void) _scanPrimitiveSelector:(NSScanner *) sc;
{ // a single primitive, e.g. * or tag or #id
	static NSCharacterSet *tagchars;
	if(!tagchars)
		// FIXME: CSS identifiers follow slightly more complex rules, therefore we should define - (NString *) [DOMCSSRule _identifier:sc]
		tagchars=[[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-"] retain];
	type=TAG_SELECTOR;	// default
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
	if(type != UNIVERSAL_SELECTOR && ![sc scanCharactersFromSet:tagchars intoString:&selector])
		return;	// no match with a tag
	[selector retain];	// take ownership from scanCharactersFromSet:intoString:
	// handle additional parameters
	if(type == ATTRIBUTE_SELECTOR)
		{ // handle tag[attrib=value]
#if 0
			NSLog(@"attribute selector");
#endif
			if([sc scanString:@"~=" intoString:NULL])
				type=ATTRIBUTE_LIST_SELECTOR;
			else if([sc scanString:@"|=" intoString:NULL])
				type=ATTRIBUTE_DASHED_SELECTOR;
			else if([sc scanString:@"^=" intoString:NULL])
				type=ATTRIBUTE_PREFIX_SELECTOR;
			else if([sc scanString:@"$=" intoString:NULL])
				type=ATTRIBUTE_SUFFIX_SELECTOR;
			else if([sc scanString:@"*=" intoString:NULL])
				type=ATTRIBUTE_CONTAINS_SELECTOR;
			else if([sc scanString:@"=" intoString:NULL])
				type=ATTRIBUTE_MATCH_SELECTOR;
			if(![sc scanString:@"]" intoString:NULL])
				{
				value=[[DOMCSSValue alloc] initWithString:(NSString *) sc];
				[sc scanString:@"]" intoString:NULL];							
				}
		}
	else if(type == PSEUDO_SELECTOR)
		{ // handle :pseudo(n)
			if([sc scanString:@"(" intoString:NULL])
				{
				value=[[DOMCSSValue alloc] initWithString:(NSString *) sc];
				[sc scanString:@")" intoString:NULL];							
				}
		}
}

- (void) _scanConditionalSelector:(NSScanner *) sc;
{
	DOMCSSStyleRuleSelector *left, *right;
	NSCharacterSet *set;
	[self _scanPrimitiveSelector:sc];
	if(!selector)
		return;
	set=[sc charactersToBeSkipped];
	[sc setCharactersToBeSkipped:nil];	// we can't scan whitespace if it is being skipped
	if([sc scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:NULL])
		{
		[sc setCharactersToBeSkipped:set];
		return;		// sequence of conditional selectors explicitly ends and forms a descendant selector
		}
	[sc setCharactersToBeSkipped:set];
	right=[DOMCSSStyleRuleSelector new];	// try to parse following selector element
	[right _scanConditionalSelector:sc];	// recursively try to get right argument
	if(![right selector])
		{ // end of sequence reached
			[right release];
			return;
		}
	// FIXME: how do we treat a[attr]b? is this a descendant a[attr] b?
	left=[self copy];	// make a copy so that we can use the existing selector as a child node
//	NSLog(@"%@", self);
	[selector release];	// has been copied
	selector=left;	// mutate us into a combinator
	value=right;
	type=CONDITIONAL_SELECTOR;
//	NSLog(@"%@", self);
}

- (void) _scanCombinatorSelector:(NSScanner *) sc;
{
	int combinator;
	DOMCSSStyleRuleSelector *left, *right;
	[DOMCSSRule _skip:sc];	// skip initial spaces only - other spaces may create a DESCENDANT_SELECTOR
	[self _scanConditionalSelector:sc];
	if(!selector)
		return;
	if([sc scanString:@">" intoString:NULL])
		combinator=CHILD_SELECTOR;
	else if([sc scanString:@"+" intoString:NULL])
		combinator=PRECEDING_SELECTOR;
	else if([sc scanString:@"~" intoString:NULL])
		combinator=SIBLING_SELECTOR;
	else
		combinator=DESCENDANT_SELECTOR;	// assume plain space character
	right=[DOMCSSStyleRuleSelector new];	// try to parse following selector element
	[right _scanCombinatorSelector:sc];	// recursively try to get right argument
	if(![right selector])
		{ // missing right selector
			[right release];
			if(combinator != DESCENDANT_SELECTOR)
				;	// real syntax error
		return;	// wasn't able to parse more
		}
	left=[self copy];	// make a copy so that we can use the existing selector as a child node
//	NSLog(@"%@", self);
	[selector release];	// has been copied
	selector=left;	// mutate us into a combinator
	value=right;
	type=combinator;
//	NSLog(@"%@", self);
}

- (void) _scanAlternativeSelector:(NSScanner *) sc;
{
	DOMCSSStyleRuleSelector *left, *right;
	[self _scanCombinatorSelector:sc];
	if(!selector)
		return;
	[DOMCSSRule _skip:sc];	// skip initial spaces only - other spaces may create a DESCENDANT_SELECTOR
	if(![sc scanString:@"," intoString:NULL])
		return;	// done
	right=[DOMCSSStyleRuleSelector new];	// try to parse following selector element
	[right _scanAlternativeSelector:sc];	// recursively try to get right argument
	if(![right selector])
		{ // real syntax error, i.e. missing right selector
			[right release];
			return;	// wasn't able to parse
		}
	left=[self copy];	// make a copy so that we can use the existing selector as a child node
//	NSLog(@"%@", self);
	[selector release];	// has been copied
	selector=left;	// mutate us into a combinator
	value=right;
	type=ALTERNATIVE_SELECTOR;
//	NSLog(@"%@", self);
}

- (void) setCSSText:(NSString *) rule;
{ // parse selector into array of DOMCSSStyleRuleSelectors
	NSScanner *sc=[DOMCSSRule _scannerForString:rule];
	[value release];
	value=nil;
	[selector release];
	selector=nil;
	[self _scanAlternativeSelector:sc];	// top level
}

- (NSString *) description; { return [self cssText]; }

@end

@implementation DOMCSSStyleRule

- (BOOL) _ruleMatchesElement:(DOMElement *) element pseudoElement:(NSString *) pseudoElement
{ // check if rule matches given element
	return [selector _ruleMatchesElement:element pseudoElement:pseudoElement];
}

- (unsigned short) type; { return DOM_STYLE_RULE; }

- (void) dealloc
{
	[selector release];
	[style release];
	[super dealloc];
}

- (NSString *) selectorText;
{ // tag class patterns
	return [selector cssText];
}

- (void) setSelectorText:(NSString *) rule;
{ // parse selector into array of DOMCSSStyleRuleSelectors
	[selector release];
	selector=[DOMCSSStyleRuleSelector new];
	[selector setCSSText:rule];
}

- (DOMCSSStyleDeclaration *) style; { return style; }

// FIXME: should we be able to parse the style here? i.e. set from a string

- (void) setStyle:(DOMCSSStyleDeclaration *) s; { ASSIGN(style, s); }

- (NSString *) cssText; { return [NSString stringWithFormat:@"%@ { %@ }", [self selectorText], style]; }

- (void) setCSSText:(NSString *) rule;
{
	NIMP;
#if NOT_YET_IMPLEMENTED
	[self setSelectorText:rule];
	[DOMCSSRule _skip:sc];
	if(![sc scanString:@"{" intoString:NULL])
		{ // missing style
			[self release];
			return nil;	// invalid
		}
	[(DOMCSSStyleRule *) self setStyle:[[[DOMCSSStyleDeclaration alloc] initWithString:(NSString *) sc] autorelease]];	// set from scanner
	[DOMCSSRule _skip:sc];
	if(![sc scanString:@"}" intoString:NULL])
		{
		NSString *skipped=@"";
		[sc scanUpToString:@"}" intoString:&skipped];	// try to recover from parse errors
#if 1
		if([skipped length] > 0)
			NSLog(@"CSS text skipped: %@", skipped);
#endif
		[sc scanString:@"}" intoString:NULL];		// and skip!
		}
#endif
}

- (NSString *) description; { return [self cssText]; }

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
	NSLog(@"_setCssText:\n%@", sheet);
#endif
	// FIXME: delete existing rules!
	while([DOMCSSRule _skip:scanner], ![scanner isAtEnd])
		{
		if([self insertRule:(NSString *) scanner index:[cssRules length]] == (unsigned) -1)	// parse and scan rules
			{
			NSLog(@"CSS parse aborted");
				{
				int idx=[scanner scanLocation]-20;
				NSString *before, *after;
				if(idx < 0) idx=0;
				before=[[scanner string] substringWithRange:NSMakeRange(idx, [scanner scanLocation]-idx)];
				idx=idx+40;
				if(idx > [[scanner string] length]) idx=[[scanner string] length];
				after=[[scanner string] substringWithRange:NSMakeRange([scanner scanLocation], idx-[scanner scanLocation])];
				NSLog(@"%@ <---> %@", before, after);
				}
			break;	// parse error
			}
		}
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
#if 1
	NSLog(@"insert rule: %@", rule);
#endif
	if(!rule)
		return -1;	// raise exception?
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

- (void) _applyRulesMatchingElement:(DOMElement *) element pseudoElement:(NSString *) pseudoElement toStyle:(DOMCSSStyleDeclaration *) style;
{ // apply rules of this sheet
	DOMCSSRuleList *rules=[self cssRules];
	int r, rcnt=[rules length];
	for(r=0; r<rcnt; r++)
		{
		DOMCSSRule *rule=(DOMCSSRule *) [rules item:r];
#if 0
		NSLog(@"match %@ with %@", element, rule);
#endif
		if([rule _ruleMatchesElement:element pseudoElement:pseudoElement])
			{
			// FIXME: handle specificity and !important priority
#if 0
			NSLog(@"MATCH!");
#endif
			// FIXME: should we expand attr() and uri() here?
			[style _append:[(DOMCSSStyleRule *) rule style]];	// append/overwrite
			}
		}
}

@end

@implementation DOMCSSValue : DOMObject

- (unsigned short) cssValueType; { return cssValueType; }

- (NSString *) cssText;
{
	switch(cssValueType)
	{
		case DOM_CSS_INHERIT: return @"inherit";
		case DOM_CSS_PRIMITIVE_VALUE: return @"$$primitive value$$";	// should be handled by subclass
		case DOM_CSS_VALUE_LIST: return @"$$value list$$";		// should be handled by subclass
		case DOM_CSS_CUSTOM:
		return @"todo";
	}
	return @"?";
}

- (void) setCssText:(NSString *) str 
{
	// how can we set the value without replacing us with our own subclass for primitive values?
	NIMP; 
}

#if 0	// NIMP
- (id) init
{
	self=[super init];
	return self;
}
#endif

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
	// FIXME: how dow we handle concatenation? "string" attr(src) "string"
	if([sc scanString:@"," intoString:NULL])
		{ // value list
		self=[[DOMCSSValueList alloc] _initWithFirstElement:[self autorelease]];
		do {
			DOMCSSPrimitiveValue *val=[DOMCSSPrimitiveValue new];
			[val setCssText:(NSString *) sc];	// parse next value
			[(DOMCSSValueList *) self _addItem:val];
			[val release];
			} while([DOMCSSRule _skip:sc], [sc scanString:@"," intoString:NULL]);
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

// FXIME: if we pass the parent style we can also evaluate inheritance here

- (DOMCSSValue *) _evaluateForElement:(DOMElement *) element;
{
	return self;
}

@end

@implementation DOMCSSValueList

- (unsigned short) primitiveType; 
{
	return 0;
}

- (id) _initWithFirstElement:(DOMCSSValue *) first
{
	if((self=[super init]))
		{
		values=[[NSMutableArray alloc] initWithObjects:first, nil];
		cssValueType=DOM_CSS_VALUE_LIST;
		}
	return self;
}

- (void) dealloc
{
	[values release];
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

- (DOMCSSValue *) _evaluateForElement:(DOMElement *) element;
{
	// FIXME: evaluate all components of the list
	return self;
}

@end

@implementation DOMCSSPrimitiveValue

#if 0
+ (void) initialize
{ // check how scanner treats the e (empty exponent or net character)
	NSScanner *sc=[NSScanner scannerWithString:@"1.0em"];
	float flt=0.0;
	NSString *em=@"";
	[sc scanFloat:&flt];
	[sc scanString:@"em" intoString:&em];
	NSLog(@"flt=%g", flt);
	NSLog(@"em=%@", em);
	NSLog(@"scanLocation=%u", [sc scanLocation]);
	NSAssert(flt==1.0, @"flt=1.0");
	NSAssert([em isEqualToString:@"em"], @"em");
	NSAssert([sc scanLocation] == 5, @"all scanned");
}
#endif

+ (NSString *) _suffix:(int) primitiveType;
{
	switch(primitiveType) {
		case DOM_CSS_NUMBER: return @"";
		case DOM_CSS_PERCENTAGE: return @"%";
		case DOM_CSS_EMS: return @"em";
		case DOM_CSS_EXS: return @"ex";
		case DOM_CSS_PX: return @"px";
		case DOM_CSS_CM: return @"cm";
		case DOM_CSS_MM: return @"mm";
		case DOM_CSS_IN: return @"in";
		case DOM_CSS_PT: return @"pt";
		case DOM_CSS_PC: return @"pc";
		case DOM_CSS_DEG: return @"deg";
		case DOM_CSS_RAD: return @"rad";
		case DOM_CSS_GRAD: return @"grad";
		case DOM_CSS_MS: return @"ms";
		case DOM_CSS_S: return @"s";
		case DOM_CSS_HZ: return @"hz";
		case DOM_CSS_KHZ: return @"khz";
		case DOM_CSS_TURNS: return @"turns";
	}
	return @"?";
}

+ (int) _scanSuffix:(NSScanner *) sc;
{
	if([sc scanString:@"%" intoString:NULL]) return DOM_CSS_PERCENTAGE;
	if([sc scanString:@"em" intoString:NULL]) return DOM_CSS_EMS;
	if([sc scanString:@"ex" intoString:NULL]) return DOM_CSS_EXS;
	if([sc scanString:@"px" intoString:NULL]) return DOM_CSS_PX;
	if([sc scanString:@"cm" intoString:NULL]) return DOM_CSS_CM;
	if([sc scanString:@"mm" intoString:NULL]) return DOM_CSS_MM;
	if([sc scanString:@"in" intoString:NULL]) return DOM_CSS_IN;
	if([sc scanString:@"pt" intoString:NULL]) return DOM_CSS_PT;
	if([sc scanString:@"pc" intoString:NULL]) return DOM_CSS_PC;
	if([sc scanString:@"deg" intoString:NULL]) return DOM_CSS_DEG;
	if([sc scanString:@"rad" intoString:NULL]) return DOM_CSS_RAD;
	if([sc scanString:@"grad" intoString:NULL]) return DOM_CSS_GRAD;
	if([sc scanString:@"ms" intoString:NULL]) return DOM_CSS_MS;
	if([sc scanString:@"s" intoString:NULL]) return DOM_CSS_S;
	if([sc scanString:@"hz" intoString:NULL]) return DOM_CSS_HZ;
	if([sc scanString:@"khz" intoString:NULL]) return DOM_CSS_KHZ;
	if([sc scanString:@"turns" intoString:NULL]) return DOM_CSS_TURNS;
	return DOM_CSS_UNKNOWN;
}

// FIXME: it appears as if we have type dependent defaults for attr()

+ (DOMCSSPrimitiveValue *) _valueWithString:(NSString *) val andType:(NSString *) type;
{ // create from string value and type
	DOMCSSPrimitiveValue *newval=[[[self alloc] init] autorelease];
	if(newval)
		{
		if([type isEqualToString:@"string"])
			{
			if(!val) val=@"";
			[newval setStringValue:DOM_CSS_STRING stringValue:val];
			}
		else if([type isEqualToString:@"color"])
			{
			if(!val) val=@"currentColor";
			if([val hasPrefix:@"#"])
				return [[[DOMCSSValue alloc] initWithString:val] autorelease];	// parse hex color constant
			[newval setStringValue:DOM_CSS_IDENT stringValue:val];
			}
		else if([type isEqualToString:@"url"])
			{
			if(!val) val=@"unknown.html";
			[newval setStringValue:DOM_CSS_URI stringValue:val];
			}
		else if([type isEqualToString:@"integer"])
			{
			if(!val) val=@"0";
			[newval setFloatValue:DOM_CSS_NUMBER floatValue:[val floatValue]];
			}
		else if([type isEqualToString:@"number"])
			{
			if(!val) val=@"0";
			[newval setFloatValue:DOM_CSS_NUMBER floatValue:[val floatValue]];
			}
		// length, angle, time, frequency
		else
			{
			NSScanner *sc=[NSScanner scannerWithString:type];
			int type=[self _scanSuffix:sc];
			if(!val) val=@"0";
			else if([val hasSuffix:@"%"])
				type=DOM_CSS_PERCENTAGE;	// overwrite any defined units
			[newval setFloatValue:type floatValue:[val floatValue]];
			}
		}
	return newval;
}

- (id) initWithString:(NSString *) str;
{
	if((self=[super init]))
		{
		[self setCssText:str];
		}
	return self;
}

- (unsigned short) cssValueType { return DOM_CSS_PRIMITIVE_VALUE; }

- (unsigned short) primitiveType; { return primitiveType; }

- (void) dealloc
{
	[value release];
	[super dealloc];
}

- (NSString *) cssText;
{
	float val;
	NSString *suffix;
	switch(primitiveType)
	{
		case DOM_CSS_UNKNOWN:	return @"unknown";
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
		case DOM_CSS_ATTR: return [NSString stringWithFormat:@"attr(%@)", [value cssText]];
		case DOM_CSS_RGBCOLOR: {
			int val=[value intValue];
			return [NSString stringWithFormat:@"#%02x%02x%02x", (val>>24)&0xff, (val>>16)&0xff, (val>>8)&0xff];
			}
		case DOM_CSS_RGBACOLOR: {
			int val=[value intValue];
			return [NSString stringWithFormat:@"rgb(%d,%d,%d,%d) ", (val>>24)&0xff, (val>>16)&0xff, (val>>8)&0xff, (val>>0)&0xff];
		}
		case DOM_CSS_DIMENSION:
		case DOM_CSS_COUNTER:
		case DOM_CSS_RECT:
		return @"TODO";
	}
	val=[self getFloatValue:primitiveType];
	if(val == 0.0)
		suffix=@"";	// ignore suffix
	else
		suffix=[DOMCSSPrimitiveValue _suffix:primitiveType];
	return [NSString stringWithFormat:@"%g%@", val, suffix];
}

- (NSString *) _toString;
{
	switch(primitiveType)
	{
		case DOM_CSS_UNKNOWN:	return @"unknown";
		case DOM_CSS_STRING:	return value;
		case DOM_CSS_URI:		return [value _toString];
		case DOM_CSS_IDENT:		return value;
		case DOM_CSS_ATTR:		return [value _toString];
		case DOM_CSS_RGBCOLOR:
		case DOM_CSS_RGBACOLOR:	return [value _toString];
		case DOM_CSS_DIMENSION:
		case DOM_CSS_COUNTER:
		case DOM_CSS_RECT:
			return @"TODO";
	}
	return [NSString stringWithFormat:@"%f%@", [self getFloatValue:primitiveType], [DOMCSSPrimitiveValue _suffix:primitiveType]];
}

- (NSArray *) _toStringArray; {	return [NSArray arrayWithObject:[self _toString]]; }

- (void) setCssText:(NSString *) str
{ // set from CSS string
	NSScanner *sc;
	static NSCharacterSet *identChars;
	float floatValue;
	if(!identChars)
		identChars=[[NSCharacterSet characterSetWithCharactersInString:@"-abcdefghijklmnopqrstuvwxyz_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"] retain];
	if([str isKindOfClass:[NSScanner class]])
		sc=(NSScanner *) str;	// we already got a NSScanner
	else
		sc=[NSScanner scannerWithString:str];
	[value release];
	value=nil;
	[DOMCSSRule _skip:sc];
	if([sc scanString:@"\"" intoString:NULL])
		{ // double-quoted
			// FIXME: handle escapes
			if([sc scanUpToString:@"\"" intoString:&value])
				{
				value=[value mutableCopy];
				[value replaceOccurrencesOfString:@"\\n" withString:@"\n" options:0 range:NSMakeRange(0, [value length])];
				[value replaceOccurrencesOfString:@"\\r" withString:@"\r" options:0 range:NSMakeRange(0, [value length])];
				[value replaceOccurrencesOfString:@"\\\\" withString:@"\\" options:0 range:NSMakeRange(0, [value length])];				
				}
			else
				value=@"";
			[sc scanString:@"\"" intoString:NULL];
			primitiveType=DOM_CSS_STRING;
			return;
		}
	if([sc scanString:@"\'" intoString:NULL])
		{ // single-quoted
			// FIXME: handle escapes
			if([sc scanUpToString:@"\'" intoString:&value])
				{
				value=[value mutableCopy];
				[value replaceOccurrencesOfString:@"\\n" withString:@"\n" options:0 range:NSMakeRange(0, [value length])];
				[value replaceOccurrencesOfString:@"\\r" withString:@"\r" options:0 range:NSMakeRange(0, [value length])];
				[value replaceOccurrencesOfString:@"\\\\" withString:@"\\" options:0 range:NSMakeRange(0, [value length])];				
				}
			else
				value=@"";
			[sc scanString:@"\'" intoString:NULL];
			primitiveType=DOM_CSS_STRING;
			return;
		}
	if([sc scanString:@"#" intoString:NULL])
		{ // hex value as RGB color constant
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
					intValue=fullValue;
				}
			value=[[NSNumber alloc] initWithInt:(intValue<<8)+255];	// stored as RGB(A) and A=100%
			primitiveType=DOM_CSS_RGBCOLOR;
			return;
		}
	if([sc scanFloat:&floatValue])
		{ // float value
//			[DOMCSSRule _skip:sc];
			int type=[DOMCSSPrimitiveValue _scanSuffix:sc];
			if(type == DOM_CSS_UNKNOWN) type=DOM_CSS_NUMBER;
			[self setFloatValue:type floatValue:floatValue];
			return;
		}
	if([sc scanCharactersFromSet:identChars intoString:&value])
		{ // appears to be a valid token
			primitiveType=DOM_CSS_IDENT;
			[DOMCSSRule _skip:sc];
			if([sc scanString:@"(" intoString:NULL])
				{ // "functional" token
					BOOL noAlpha;
					if((noAlpha=[value isEqualToString:@"rgb"]) || [value isEqualToString:@"rgba"])
						{ // rgb(r, g, b) or rgba(r, g, b, a)
							DOMCSSValue *val=[[DOMCSSValue alloc] initWithString:(NSString *) sc];	// parse argument(s)
							NSArray *args=[val _toStringArray];
							unsigned int rgb=noAlpha?255:0;
							int i;
							for(i=0; i<=noAlpha?2:3 && i < [args count]; i++)
								{
								NSString *component=[args objectAtIndex:i];
								float c=[component floatValue];
								if([component hasSuffix:@"%"])	c=(255.0/100.0)*c;	// convert %
								if(c > 255.0)		c=255.0;	// clamp to range
								else if(c < 0.0)	c=0.0;
								rgb |= (((unsigned) c) % 256) << (8*(3-i));	// fill from left
								}
							value=[[NSNumber alloc] initWithInt:rgb];
							[val release];
							primitiveType=noAlpha?DOM_CSS_RGBCOLOR:DOM_CSS_RGBACOLOR;
						}
					// FIXME: WebKit understands hsv(), hsva()
					else if([value isEqualToString:@"url"])
						{ // url(location) or url("location")
							// FIXME: accepts paths incl. / without quotes!
							// FIXME: relative URLS are relative to enclosing CSS
							value=[[DOMCSSValue alloc] initWithString:(NSString *) sc];
							primitiveType=DOM_CSS_URI;
						}
					else if([value isEqualToString:@"attr"])
						{ // attr(name)
							value=[[DOMCSSValue alloc] initWithString:(NSString *) sc];	// parse argument(s)
							primitiveType=DOM_CSS_ATTR;
						}
					else if([value isEqualToString:@"counter"])
						{ // counter(ident) or counter(ident, list-style-type)
							value=[[DOMCSSValue alloc] initWithString:(NSString *) sc];	// parse argument(s)
							primitiveType=DOM_CSS_COUNTER;
						}
					else if([value isEqualToString:@"dimension"])
						{
						// FIXME
						value=[[DOMCSSValue alloc] initWithString:(NSString *) sc];	// parse argument(s)
						primitiveType=DOM_CSS_DIMENSION;
						}
					else if([value isEqualToString:@"rect"])
						{						
						// FIXME
						value=[[DOMCSSValue alloc] initWithString:(NSString *) sc];	// parse argument(s)
						primitiveType=DOM_CSS_RECT;
						}
					else if([value isEqualToString:@"calc"])
						{
						// FIXME
						value=[[DOMCSSValue alloc] initWithString:(NSString *) sc];	// parse argument(s)
						primitiveType=DOM_CSS_CALC;
						}
					else
						{ // e.g. alpha(opacity=40)
						primitiveType=DOM_CSS_UNKNOWN;
						// we may need to parse arbitrary functions...
						[sc scanUpToString:@")" intoString:NULL];					
						value=nil;	// trow away pointer or we get into troubles on dealloc
						}
					[sc scanString:@")" intoString:NULL];					
				}
			else
				[value retain];	// identifier
			return;
		}
	value=nil;	// just be safe
	primitiveType=DOM_CSS_UNKNOWN;
}

- (void) setFloatValue:(unsigned short) unitType floatValue:(float) floatValue;
{
	switch(unitType)
	{ // convert to internal inits (meters, seconds, rad, Hz)
		case DOM_CSS_CM: floatValue *= 0.01; break;		// store in meters
		case DOM_CSS_MM: floatValue *= 0.001; break;	// store in meters
		case DOM_CSS_IN: floatValue *= 0.0254; break;	// store in meters
		case DOM_CSS_PT: floatValue *= 0.0254/72; break;	// store in meters
		case DOM_CSS_PX: floatValue *= 0.0254/72; break;	// store in meters and assume 1px = 1pt
		case DOM_CSS_PC: floatValue *= 0.0254/6; break;	// store in meters
		case DOM_CSS_DEG: floatValue *= M_PI/180.0;	// 360 deg for full circle
		case DOM_CSS_GRAD: floatValue *= M_PI/200.0;	// 400 grad for full circle
		case DOM_CSS_TURNS: floatValue *= M_PI/0.5;	// 1 turn for full circle
		case DOM_CSS_MS: floatValue *= 0.001; break;	// store in seconds
		case DOM_CSS_KHZ: floatValue *= 1000.0; break;	// store in Hz
	}
	[value autorelease];
	value=[[NSNumber alloc] initWithFloat:floatValue];
	primitiveType=unitType;
}

- (float) getFloatValue:(unsigned short) unitType;
{ // convert to unitType if requested
	if(unitType != primitiveType)
		// check if compatible
		/* classify both types as:
		 * LENGTH: mm, cm, in, pt, px, pc
		 * SCALE percent, em, ex
		 * TIME
		 * FREQ
		 * ANGLE deg, rad, grad, turns
		 * ...
		 */
		;
	switch(unitType)
	{ // since we store absolute lengths in meters, time in seconds and frequencies in Hz, conversion to compatible type does not depend on stored type
		case DOM_CSS_CM: return 100.0*[value floatValue];
		case DOM_CSS_MM: return 1000.0*[value floatValue];
		case DOM_CSS_IN: return [value floatValue] / 0.0254;
		case DOM_CSS_PT: return [value floatValue] / (0.0254/72);
			// FIXME: we could ask the WebView's NSScreen for a scaling factor
		case DOM_CSS_PX: return [value floatValue] / (0.0254/72);	// assume 1px = 1pt
		case DOM_CSS_PC: return [value floatValue] / (0.0254/6);
		case DOM_CSS_DEG: return [value floatValue] / (M_PI/180.0);
		case DOM_CSS_GRAD: return [value floatValue] / (M_PI/200.0);
		case DOM_CSS_TURNS: return [value floatValue] / (M_PI/0.5);
		case DOM_CSS_MS: return 1000.0*[value floatValue];
		case DOM_CSS_KHZ: return 0.001*[value floatValue];
		default: return [value floatValue];
	}
	// raise exception?
	return 0.0;
}

- (float) getFloatValue:(unsigned short) unitType relativeTo100Percent:(float) base andFont:(NSFont *) font;
{ // convert to given unitType
	switch(primitiveType) {
		case DOM_CSS_PERCENTAGE: return 0.01*[value floatValue]*base;
		case DOM_CSS_EMS: return font?[value floatValue]*([font ascender]-[font descender]):0.0;
		case DOM_CSS_EXS: return font?[value floatValue]*[font xHeight]:0.0;
	}
	return [self getFloatValue:unitType];	// absolute
}

- (void) setStringValue:(unsigned short) stringType stringValue:(NSString *) stringValue;
{
	// only for ident, attr, string?
	// or should we run the parser here?
	[value autorelease];
	value=[stringValue retain];
	primitiveType=stringType;
}

- (NSString *) getStringValue;
{
	return [value _toString];
}

//- (DOMCounter *) getCounterValue;
//- (DOMRect *) getRectValue;
//- (DOMRGBColor *) getRGBColorValue;

- (NSColor *) _lookupColorTable:(NSString *) str;
{
	static NSMutableDictionary *list;
	NSColor *color;
	NSScanner *sc;
	if(!list)
		{ // load color list (based on table 4.3 in http://www.w3.org/TR/css3-color/) from resource file
			NSDictionary *dict=[NSDictionary dictionaryWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"DOMHTMLColors" ofType:@"plist"]];
			NSEnumerator *e=[dict keyEnumerator];
			NSString *name;
			NSAssert(dict, @"needs color lookup table");
			list=[[NSMutableDictionary alloc] initWithCapacity:[dict count]];
			while((name=[e nextObject]))
				{
				NSString *val=[dict objectForKey:name];
				color=[self _lookupColorTable:val];	 // try to translate (may become a recursive definition!)
				if(color)
					[list setObject:color forKey:name];
				else
					NSLog(@"color table error %@/%@ -> nil", name, val);
				}
		}
	color=[list objectForKey:[str lowercaseString]];
	if(!color)
		{ // should be used only while reading the color table
			unsigned int hex;
			sc=[NSScanner scannerWithString:str];
			if([sc scanString:@"#" intoString:NULL] && [sc scanHexInt:&hex])
				{ // hex string
					if([str length] <= 4)	// short hex - convert into full value
						return [NSColor colorWithCalibratedRed:((hex>>8)&0xf)/15.0 green:((hex>>4)&0xf)/15.0 blue:(hex&0xf)/15.0 alpha:1.0];
					return [NSColor colorWithCalibratedRed:((hex>>16)&0xff)/255.0 green:((hex>>8)&0xff)/255.0 blue:(hex&0xff)/255.0 alpha:1.0];
				}
		}
	return color;
}

- (NSColor *) _getNSColorValue;
{
	if([self primitiveType] == DOM_CSS_RGBCOLOR || [self primitiveType] == DOM_CSS_RGBACOLOR)
		{
		unsigned int hex=[value intValue];
		return [NSColor colorWithCalibratedRed:((hex>>24)&0xff)/255.0 green:((hex>>16)&0xff)/255.0 blue:((hex>>8)&0xff)/255.0 alpha:((hex>>0)&0xff)/255.0];		
		}
	// handle HSV etc.
	return [self _lookupColorTable:[self _toString]];
}

//- (DOMCounter *) getCounterValue;
//- (DOMRect *) getRectValue;			// define DOMRect to 'have a' NSRect
//- (DOMRGBColor *) getRGBColorValue;	// define DOMRGBColor to 'have a' NSColor

- (DOMCSSValue *) _evaluateForElement:(DOMElement *) element
{
	switch(primitiveType) {
		case DOM_CSS_ATTR:
			{ // expand attr(name, ...)
				NSArray *args=[value _toStringArray];
				if([args count] > 0)
					{
					NSString *name=[args objectAtIndex:0];
					NSString *type=[args count] >= 2?[args objectAtIndex:1]:@"string";	// default type
					NSString *attr=[element getAttribute:name];	// read attribute value as string
					if(!attr && [args count] >= 3)
						// NOTE: this would go beyond CSS3 spec where it is explicitly stated that it may not be another attr()
						// return [[args objectAtIndex:2] _evaluateForElement:element];	// recursively replace default value
						return [[[DOMCSSValue alloc] initWithString:[args objectAtIndex:2]] autorelease];	// can specify different units
					else if([type isEqualToString:@"url"])
						{ // resolve urls - attr(name url) is different from url(string) which is relative to the CSS path
						NSURL *document=[[[[element webFrame] dataSource] response] URL];
						NSURL *url=[NSURL URLWithString:attr relativeToURL:document];
						// FIXME: make relative URLs absolute (relative to the loading document)
						return [DOMCSSPrimitiveValue _valueWithString:[url absoluteString] andType:type];
						}
					else
						return [DOMCSSPrimitiveValue _valueWithString:attr andType:type];
					}
				return self;	// could not evaluate
			}
			// expand calc(formula)
	}
	return self;	// could not evaluate
}

@end

@implementation WebView (CSS)

// a missing entry always means "initial" value
// to check for inheritance (implicit or explicit), compare with the same property of the parent

- (DOMCSSStyleDeclaration *) _styleForElement:(DOMElement *) element pseudoElement:(NSString *) pseudoElement parentStyle:(DOMCSSStyleDeclaration *) parent;
{ // get attributes to apply to this node, process appropriate CSS definition by tag, tag level, id, class, etc.
	NSAutoreleasePool *arp=[NSAutoreleasePool new];
	int i, cnt;
	DOMCSSStyleDeclaration *style;
	static DOMCSSStyleSheet *defaultSheet;
	static NSArray *inheritable;
	static NSDictionary *initializable;
	NSEnumerator *e;
	NSString *property;
	/* predefine static objects */
	if(!inheritable)	// these properties are inherited (unless overwritten)
		inheritable=[[NSArray alloc] initWithObjects:
					 /* see http://www.w3schools.com/cssref/pr_text_white-space.asp for "Inherited: yes" */
					 /* visuals */
					 @"color",
					 @"cursor",
					 @"direction",
					 @"font-family",
					 @"font-size",
					 @"font-style",
					 @"font-variant",
					 @"font-weight",
					 @"letter-spacing",
					 @"line-height",
					 @"list-style",
					 @"list-style-image",
					 @"list-style-position",
					 @"list-style-type",
					 @"quotes",
					 @"text-align",
					 @"text-indent",
					 @"text-transform",
					 @"visibility",
					 @"white-space",	// see e.g. 
					 @"word-spacing",
					 /* table */
					 @"border-collapse",
					 @"border-spacing",
					 @"empty-cells",
					 @"table-layout",
					 /* page layout */
					 @"orphans",
					 @"page-break-inside",
					 @"widows",
					 /* private extensions */
					 @"x-link",
					 @"x-tooltip",
					 @"x-target-window",
					 @"x-anchor",
					 nil];	
	if(!initializable)	// these properties are initialized (unless overwritten)
		initializable=[[NSDictionary alloc] initWithObjectsAndKeys:
					   /* see http://www.w3schools.com/cssref/pr_text_white-space.asp for "Default value:"
					   // OPTIMIZE: we could parse the values into DOMCSSValues right here */
					   /* visuals */
					   @"scroll", @"background-attachment",
					   @"transparent", @"background-color",
					   @"none", @"background-image",
					   @"0%0%", @"background-position",
					   @"repeat", @"background-repeat",
					   
					   @"attr(color)", @"border-bottom-color",
					   @"none", @"border-bottom-style",
					   @"medium", @"border-bottom-width",
					   @"attr(color)", @"border-left-color",
					   @"none", @"border-left-style",
					   @"medium", @"border-left-width",
					   @"attr(color)", @"border-right-color",
					   @"none", @"border-right-style",
					   @"medium", @"border-right-width",
					   @"attr(color)", @"border-top-color",
					   @"none", @"border-top-style",
					   @"medium", @"border-top-width",
					   @"auto", @"bottom",
					   @"none", @"clear",
					   @"auto", @"clip",
					   /*   @"initial", @"color", must be done by code */
					   @"normal", @"content",
					   /*   @"1", @"counter-increment", must be done by code */
					   /*   @"1", @"counter-reset", must be done by code */
					   @"auto", @"cursor",
					   @"ltr", @"direction",
					   @"inline", @"display",
					   @"auto", @"height",
					   @"none", @"float",
					   /*   @"initial", @"font-family", must be done by code */
					   /*   @"initial", @"font-family", must be done by code */
					   @"medium", @"font-size",
					   @"normal", @"font-style",
					   @"normal", @"font-variant",
					   @"normal", @"font-weight",
					   @"normal", @"height",
					   @"auto", @"left",
					   @"normal", @"letter-spacing",
					   @"normal", @"line-height",
					   @"none", @"list-style-image",
					   @"outside", @"list-style-position",
					   @"disc", @"list-style-type",
					   // checkme - what does margin: do? should be set to nil by default
					   @"0", @"margin-bottom",
					   @"0", @"margin-left",
					   @"0", @"margin-right",
					   @"0", @"margin-top",
					   @"none", @"max-height",
					   @"none", @"max-width",
					   @"0", @"min-height",
					   @"0", @"min-width",
					   @"invert", @"outline-color",
					   @"none", @"outline-style",
					   @"medium", @"outline-width",
					   @"visible", @"overflow",
					   @"0", @"padding-bottom",
					   @"0", @"padding-left",
					   @"0", @"padding-right",
					   @"0", @"padding-top",
					   @"static", @"position",
					   // CHECKME: can we parse this correctly?
					   /* @"'\201C' '\201D' '\2018' '\2019' ", @"quotes", */
					   @"auto", @"right",
					   @"left", @"text-align",	/* may be defined differently */
					   @"none", @"text-decoration",
					   @"0", @"text-indent",
					   @"none", @"text-transform",
					   @"auto", @"top",
					   @"normal", @"unicode-bidi",
					   @"baseline", @"vertical-align",
					   @"visible", @"visibility",
					   @"normal", @"white-space",
					   @"auto", @"width",
					   @"normal", @"word-spacing",
					   @"auto", @"z-index",
					   /* table */
					   @"separate", @"border-collapse",
					   @"0", @"border-spacing",
					   @"top", @"caption-side",
					   @"show", @"empty-cells",
					   @"auto", @"table-layout",
					   /* page layout */
					   @"2", @"orphans",
					   @"auto", @"page-break-after",
					   @"auto", @"page-break-before",
					   @"auto", @"page-break-inside",
					   @"2", @"widows",
					   nil];
	
	style=[[DOMCSSStyleDeclaration new] autorelease];
	if([element isKindOfClass:[DOMElement class]])
		{ // find CSS definition matching node
			if(!defaultSheet)
				{ // read default.css from bundle
					NSString *path=[[NSBundle bundleForClass:[self class]] pathForResource:@"default" ofType:@"css"];
					NSString *sheet=[NSString stringWithContentsOfFile:path];
					NSAssert(sheet, @"needs default.css");
					if(sheet)
						{
						defaultSheet=[DOMCSSStyleSheet new];
						[defaultSheet _setCssText:sheet];	// parse the style sheet to add
						}
#if 1
					NSLog(@"parsed default.css: %@", defaultSheet);
#endif
				}
			[defaultSheet _applyRulesMatchingElement:element pseudoElement:pseudoElement toStyle:style];
			
			if([[self preferences] authorAndUserStylesEnabled])
				{ // user has not requested to ignore this style
					NSString *styleString;
					DOMStyleSheetList *list;
					DOMCSSStyleDeclaration *css;
					// FIXME: how to handle different media?
					list=[(DOMHTMLDocument *) [element ownerDocument] styleSheets];
					cnt=[list length];
					for(i=0; i<cnt; i++)
						{ // go through all style sheets
							// FIXME:
							// multiple rules may match (and have different priorities!)
							// i.e. we should have a method that returns all matching rules
							// then sort by precedence/priority/specificity/importance
							// the rules are described here:
							// http://www.w3.org/TR/1998/REC-CSS2-19980512/cascade.html#cascade
							
							[(DOMCSSStyleSheet *) [list item:i] _applyRulesMatchingElement:element pseudoElement:pseudoElement toStyle:style];
						}
					// what comes first? browser or author defined and how is the style={} attribute taken?
					styleString=[element getAttribute:@"style"];	// style="" attribute (don't use KVC here since it may return the (NSArray *) style!)
					if(styleString)
						{ // parse style attribute
#if 0
							NSLog(@"add style=\"%@\"", styleString);
#endif
							// we should somehow cache this in the element or we will parse this again and again...
							css=[[DOMCSSStyleDeclaration alloc] initWithString:styleString];	// parse
							[style _append:css];	// append/overwrite
							[css release];
						}
				}
			else {
				NSLog(@"authorAndUserStyles are disabled");
			}

		}
	cnt=[style length];
	for(i=0; i<cnt; i++)
		{ // expand functions and inheritance
			property=[style item:i];
			DOMCSSValue *val=[style getPropertyCSSValue:property];
			if([val cssValueType] == DOM_CSS_INHERIT)
				{ // try to inherit from parent (nil in the parent means "initial")
				DOMCSSValue *newval;
				newval=[parent getPropertyCSSValue:property];
				if(newval)
					[style setProperty:property CSSvalue:newval priority:[parent getPropertyPriority:property]];
				else
					[style removeProperty:property], cnt--; // we have no explicit default value yet, so remove this "inherit"
				}
			else
				{
				DOMCSSValue *eval=[val _evaluateForElement:element];
				if(eval != val)
					[style setProperty:property CSSvalue:eval priority:nil];
				}
		}
	e=[inheritable objectEnumerator];
	while((property=[e nextObject]))
		{ // check that we inherit all default inheritances
			DOMCSSValue *val=[style getPropertyCSSValue:property];
			if(!val)
				{ // not yet defined
					DOMCSSValue *newval;
					newval=[parent getPropertyCSSValue:property];
					if(newval)	// inherit from parent - leave nil if still undefined
						[style setProperty:property CSSvalue:newval priority:[parent getPropertyPriority:property]];
				}
		}
	if(![element isKindOfClass:[DOMElement class]])
		{ // a #text element must auto-inherit some more properties
			// height?
			// z-index
		}
	e=[initializable keyEnumerator];
	while((property=[e nextObject]))
		{ // or we make a third loop with auto-init for still undefined values (and check for "inherit" string here)
			DOMCSSValue *val=[style getPropertyCSSValue:property];
			if(val)
				{ // check if CSS explicitly specifies "initial" -> then overwrite any inheritance
					if([val isKindOfClass:[DOMCSSPrimitiveValue class]])
						continue;
					if([(DOMCSSPrimitiveValue *) val primitiveType] != DOM_CSS_STRING)
						continue;	// not a string
					if(![[(DOMCSSPrimitiveValue *) val getStringValue] isEqualToString:@"initial"])
						continue;
				}
			// FIXME: if we allow to initialize with attr(color) we have to evaluate it here - but we may not even know the color yet!
			[style setProperty:property CSSvalue:[[[DOMCSSValue alloc] initWithString:[initializable objectForKey:property]] autorelease] priority:@""];
		}
	[style retain];
	[arp release];
	return [style autorelease];
}

- (DOMCSSStyleDeclaration *) computedStyleForElement:(DOMElement *) element
									   pseudoElement:(NSString *) pseudoElement;
{ // this provides a complete list of attributes where inheritance and default values are expanded
	/* this is now calculated always - not only if we really inherit something! */
	// efficiency without caching is very questionable!!! */
	DOMCSSStyleDeclaration *parent=[element parentNode]?[self computedStyleForElement:(DOMElement *) [element parentNode] pseudoElement:pseudoElement]:nil;
	DOMCSSStyleDeclaration *style=[self _styleForElement:element pseudoElement:pseudoElement parentStyle:parent];
	return style;
}

- (DOMCSSStyleDeclaration *) computedPageStyleForPseudoElement:(NSString *) pseudoElement;
{
	// here we should compute something...
	return nil;
}

@end
