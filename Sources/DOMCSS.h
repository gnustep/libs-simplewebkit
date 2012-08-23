/* simplewebkit
   DOMCSS.h

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

#import <WebKit/DOMCore.h>

@class DOMStyleSheet;

@interface DOMStyleSheetList : DOMObject
{
	NSArray *items;	// of type DOMCSSStyleSheet
}

- (void) _addStyleSheet:(DOMStyleSheet *) sheet;
- (unsigned) length;
- (DOMStyleSheet *) item:(unsigned) index;

@end

@class DOMMediaList;

@interface DOMStyleSheet : DOMObject
{
	NSString *type;
	DOMNode *ownerNode;	// should be <style> or <link>
	DOMStyleSheet *parentStyleSheet;	// if nested (@import)
	NSString *href;
	NSString *title;
	DOMMediaList *media;	// for which media to apply
	BOOL disabled;
}

- (BOOL) disabled;
- (NSString *) href;
- (DOMMediaList *) media;
- (DOMNode *) ownerNode;
- (DOMStyleSheet *) parentStyleSheet;
- (NSString *) title;

// which of these are really public setters???
- (void) setHref:(NSString *) href;		// required to locate @import urls
- (void) setTitle:(NSString *) title;
- (void) setOwnerNode:(DOMNode *) node;	// required to load subresources (@import)

@end

@class DOMCSSRule;
@class DOMCSSRuleList;

@interface DOMCSSStyleSheet : DOMStyleSheet
{
	DOMCSSRule *ownerRule;
	DOMCSSRuleList *cssRules;
	BOOL enabled;
}

- (void) _setCssText:(NSString *) str;	// parse all rules...
- (DOMCSSRule *) ownerRule;
- (DOMCSSRuleList *) cssRules;
- (unsigned) insertRule:(NSString *) rule index:(unsigned) index;	// parse rule
- (void) deleteRule:(unsigned) index;

@end

@interface DOMMediaList : DOMObject
{
	NSString *mediatext;
	NSArray *items;	// of type NSString
}

- (NSString *) mediaText;
- (void) setMediaText:(NSString *) text;
- (unsigned) length;
- (NSString *) item:(unsigned) index;
- (void) deleteMedium:(NSString *) oldMedium;
- (void) appendMedium:(NSString *) newMedium;

@end

@class DOMCSSRule;

@interface DOMCSSRuleList : DOMObject
{
	NSArray *items;
}

- (unsigned) length;
- (DOMCSSRule *) item:(unsigned) index;

@end

enum DOMCSSRuleType
{
	DOM_UNKNOWN_RULE = 0,
	DOM_STYLE_RULE = 1,
	DOM_CHARSET_RULE = 2,
	DOM_IMPORT_RULE = 3,
	DOM_MEDIA_RULE = 4,
	DOM_FONT_FACE_RULE = 5,
	DOM_PAGE_RULE = 6
};

@interface DOMCSSRule : DOMObject
{
	DOMCSSStyleSheet *parentStyleSheet;
	DOMCSSRule *parentRule;
}

- (BOOL) _ruleMatchesElement:(DOMElement *) element pseudoElement:(NSString *) pseudoElement;
- (unsigned short) type;
- (NSString *) cssText;
- (DOMCSSStyleSheet *) parentStyleSheet;
- (DOMCSSRule *) parentRule;

@end

@interface DOMCSSCharsetRule : DOMCSSRule
{
	NSString *encoding;
}
- (NSString *) encoding;
@end

@class DOMCSSStyleDeclaration;

@interface DOMCSSFontFaceRule : DOMCSSRule
{
	DOMCSSStyleDeclaration *style;
}
- (DOMCSSStyleDeclaration *) style;
@end

@interface DOMCSSImportRule : DOMCSSRule <WebDocumentRepresentation>
{
	NSString *href;
	DOMMediaList *media;
	DOMCSSStyleSheet *styleSheet;	// the loaded style sheet
}
// FIXME: do we need this or can we use KVC as getters&setters?
- (NSString *) href;
- (DOMMediaList *) media;
- (DOMCSSStyleSheet *) styleSheet;
@end

@class DOMCSSRuleList;

@interface DOMCSSMediaRule : DOMCSSRule
{
	DOMMediaList *media;
	DOMCSSRuleList *cssRules;
}

- (DOMCSSRuleList *) cssRules;
- (unsigned) insertRule:(NSString *) rule index:(unsigned) index;
- (void) deleteRule:(unsigned) index;

@end

@interface DOMCSSPageRule : DOMCSSRule
{ // page style rule
	NSArray *selector;	// all selectors begin with :
	DOMCSSStyleDeclaration *style;
}

- (NSString *) selectorText;
- (void) setSelectorText:(NSString *) rule;
- (DOMCSSStyleDeclaration *) style;
- (void) setStyle:(DOMCSSStyleDeclaration *) s;

@end

@interface DOMCSSStyleRule : DOMCSSRule
{ // standard style rule
	NSArray *selector;	// array of alternatives (, separated) - each one is an array of tags, classes etc.
	DOMCSSStyleDeclaration *style;
}

- (NSString *) selectorText;	// tag class patterns
- (void) setSelectorText:(NSString *) rule;
- (DOMCSSStyleDeclaration *) style;
- (void) setStyle:(DOMCSSStyleDeclaration *) s;

@end

@interface DOMCSSUnknownRule : DOMCSSRule
@end

@class DOMCSSValue;

@interface DOMCSSStyleDeclaration : DOMObject
{
	NSMutableDictionary *items;
	NSMutableDictionary *priorities;
	DOMCSSRule *parentRule;
}

- (id) initWithString:(NSString *) style;
- (NSString *) cssText;
- (void) setCssText:(NSString *) style;
- (DOMCSSRule *) parentRule;
- (NSString *) getPropertyValue:(NSString *) propertyName;
- (DOMCSSValue *) getPropertyCSSValue:(NSString *) propertyName;
- (NSString *) removeProperty:(NSString *) propertyName;
- (NSString *) getPropertyPriority:(NSString *) propertyName;
- (void) setProperty:(NSString *) propertyName value:(NSString *) value priority:(NSString *) priority;
- (unsigned) length;
- (NSString *) item:(unsigned) index;
- (NSString *) getPropertyShorthand:(NSString *) propertyName;
- (BOOL) isPropertyImplicit:(NSString *) propertyName;

- (NSDictionary *) _items;

@end

enum DOMCSSValueType
{
	DOM_CSS_INHERIT = 0,
	DOM_CSS_PRIMITIVE_VALUE = 1,
	DOM_CSS_VALUE_LIST = 2,
	DOM_CSS_CUSTOM = 3
};

@interface DOMCSSValue : DOMObject
{
	NSString *cssText;
	unsigned short cssValueType;
}

- (NSString *) cssText;
- (unsigned short) cssValueType;

@end

@interface DOMCSSValueList : DOMCSSValue
{
	NSMutableArray *values;
}
- (unsigned) length;
- (DOMCSSValue *) item:(unsigned) index;
@end

enum DOMCSSPrimitiveValueType
{
	DOM_CSS_UNKNOWN = 0,
	DOM_CSS_NUMBER = 1,
	DOM_CSS_PERCENTAGE = 2,
	DOM_CSS_EMS = 3,
	DOM_CSS_EXS = 4,
	DOM_CSS_PX = 5,
	DOM_CSS_CM = 6,
	DOM_CSS_MM = 7,
	DOM_CSS_IN = 8,
	DOM_CSS_PT = 9,
	DOM_CSS_PC = 10,
	DOM_CSS_DEG = 11,
	DOM_CSS_RAD = 12,
	DOM_CSS_GRAD = 13,
	DOM_CSS_MS = 14,
	DOM_CSS_S = 15,
	DOM_CSS_HZ = 16,
	DOM_CSS_KHZ = 17,
	DOM_CSS_DIMENSION = 18,
	DOM_CSS_STRING = 19,
	DOM_CSS_URI = 20,	// url(string)
	DOM_CSS_IDENT = 21,
	DOM_CSS_ATTR = 22,	// attr(name)
	DOM_CSS_COUNTER = 23,
	DOM_CSS_RECT = 24,
	DOM_CSS_RGBCOLOR = 25	// rgb(red, green, blue)
};

@interface DOMCSSPrimitiveValue : DOMCSSValue
{
	unsigned short primitiveType;
	id value;	// NSNumber, NSString, NSValue, NSURL, NSColor, ...
}

- (unsigned short) primitiveType;
- (void) setFloatValue:(unsigned short) unitType floatValue:(float) floatValue;
- (float) getFloatValue:(unsigned short) unitType;
- (void) setStringValue:(unsigned short) stringType stringValue:(NSString *) stringValue;
- (NSString *) getStringValue;
//- (DOMCounter *) getCounterValue;
//- (DOMRect *) getRectValue;
//- (DOMRGBColor *) getRGBColorValue;

@end

@interface DOMCSSPrimitiveValue (Private)

// evaluate relative (and absoulte) values to unitType:
- (float) getFloatValue:(unsigned short) unitType relativeTo100Percent:(float) base andFont:(NSFont *) font;

@end
