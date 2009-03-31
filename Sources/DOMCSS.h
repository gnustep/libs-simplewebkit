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

@class DOMMediaList;

@interface DOMStyleSheet : DOMElement	// 1.2
{
	NSString *type;
	BOOL disabled;
	DOMNode *ownerNode;
	DOMStyleSheet *parentStyleSheet;
	// DOMText???
	NSString *href;
	NSString *title;
	DOMMediaList *media;
}

@end

@interface DOMStyleSheetList : DOMElement
{
	NSArray *items;	// of type DOMCSSStyleSheet
}

@end

@interface DOMCSSMediaList : DOMElement
{
	NSString *mediatext;
	NSArray *items;	// of type NSString
}

@end


// OLD

@interface DOMCSSStyleDeclaration : DOMElement
{ // this is a style="style" definition
	NSMutableDictionary *_elements;	// key : value value;
}

+ (DOMCSSStyleDeclaration *) _parseWithScanner:(NSScanner *) sc baseURL:(NSURL *) url;

- (id) initWithString:(NSString *) style forDocument:(RENAME(DOMDocument) *) doc;	// for <tag style="css">
- (id) _initWithScanner:(NSScanner *) sc baseURL:(NSURL *) url;
- (NSArray *) allKeys;
- (NSArray *) valueForKey:(NSString *) key;

@end

// FIXME:

typedef enum _CSSRuleType
{
	CSSHasParentRule,			// tag1 tag2 { }
	CSSHasDirectParentRule,		// tag1 > tag2 { }
	CSSNearRule,				// tag1 + tag2 { }
	CSSClassRule,				// tag1.class { }
	CSSIDRule,					// tag1#class { }
	CSSAttributeRule,			// tag1[attribute="value"] - value may be ommitted
	CSSPseudoclass				// tag1 : class
} CSSRuleType;

@interface CSSRule : NSObject
{ // this is a CSS "rule { style }"
	id _left, _right;	// other CSSRule (pattern) or NSString or nil (for *)
	NSString *value;	// for CSSAttributeRule or CSSPseudoclass
	DOMCSSStyleDeclaration *_style;
	CSSRuleType _type;
}

+ (CSSRule *) _parseWithScanner:(NSScanner *) sc baseURL:(NSURL *) url;
- (BOOL) matchesDOMNode:(DOMNode *) node;
- (DOMCSSStyleDeclaration *) style;

@end

@interface CSSDocument : NSObject
{ // this is a CSS set of rules
	NSString *media;				// for which media does this rulebase apply?
	NSMutableDictionary *_rules;	// each rule is an NSArray with CSSRules - keyed by main element
}

+ (CSSDocument *) _parseWithScanner:(NSScanner *) sc baseURL:(NSURL *) url;
- (CSSRule *) ruleForNode:(DOMNode *) node withMedium:(NSString *) medium;	// find matching rule

@end
