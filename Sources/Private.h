/* simplewebkit
   Private.h

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

#import <Foundation/Foundation.h>
// #import <WebKit/WebScriptObject.h>
#import <WebKit/WebDataSource.h>
#import <WebKit/WebDocument.h>
#import <WebKit/WebFrame.h>
#import <WebKit/WebFrameView.h>
#import <WebKit/WebHistoryItem.h>
#import <WebKit/WebView.h>

#ifndef NIMP
#define NIMP NSLog(@"not implemented: %@", NSStringFromSelector(_cmd)), (id) nil
#endif
#ifndef ASSIGN
#define ASSIGN(var, val) ([var release], var=[val retain])
#endif

@interface WebFrameView (Private)
- (void) _setDocumentView:(NSView *) view;
- (void) _setWebFrame:(WebFrame *) wframe;
@end

@interface WebDataSource (Private)
- (NSStringEncoding) _stringEncoding;
- (void) _setUnreachableURL:(NSURL *) url;
- (void) _setWebFrame:(WebFrame *) wframe;
- (void) _loadSubresourceWithURL:(NSURL *) url;
- (void) _setParentDataSource:(WebDataSource *) source;
- (void) _commitSubresource:(WebDataSource *) source;
@end

@interface _NSURLRequestNSData : NSURLRequest
{
	NSData *_data;				// data to return
	NSURLResponse *_response;	// virtual response...
}

- (id) initWithData:(NSData *) data mime:(NSString *) mime textEncodingName:(NSString *) encoding baseURL:(NSURL *) url;
- (NSURLResponse *) response;
- (NSData *) data;

@end

@interface _WebNSDataSource : WebDataSource
- (id) initWithData:(NSData *) data MIMEType:(NSString *) mime textEncodingName:(NSString *) encoding baseURL:(NSURL *) url;
@end

@interface WebFrame (Private)
- (void) _setParentFrame:(WebFrame *) parent;	// weak pointer
- (void) _setFrameName:(NSString *) name;
- (void) _addChildFrame:(WebFrame *) child;
- (void) _setFrameElement:(DOMHTMLElement *) element;
- (void) _finishedLoading;
- (void) _receivedData:(WebDataSource *) dataSource;
@end

@interface WebHistoryItem (Private)
- (void) _touch;
- (void) _setIcon:(NSImage *) icon;
- (void) _setURL:(NSURL *) url;
@end

@interface WebView (Private)
+ (Class) _representationClassForMIMEType:(NSString *) type;
+ (Class) _viewClassForMIMEType:(NSString *) type;
- (BOOL) drawsBackground;
- (void) setDrawsBackground:(BOOL) flag;
- (NSArray *) _fontsForSize;	// 7 entries for the <font size="x"> tag
- (NSArray *) _fontsForHeader;	// 6 entries for the <h#> tags
@end

@interface NSObject (WebScriptDereference)

// dereference 8.7

- (id) _getValue;								// 8.7.1
- (void) _putValue:(id) val;		// 8.7.2

@end

@interface NSObject (WebScriptTypeConversion)

// type conversion 9.

- (id) _toPrimitive:(Class) preferredType;	// 9.1
- (NSNumber *) _toBoolean;			// 9.2
- (NSNumber *) _toNumber;				// 9.3
- (NSNumber *) _toInteger;			// 9.4
- (NSNumber *) _toInt32;				// 9.5
- (NSNumber *) _toUint32;				// 9.6
- (NSNumber *) _toUint16;				// 9.7
- (NSString *) _toString;				// 9.8
- (WebScriptObject *) _toObject;				// 9.9

@end

@interface WebScriptObject (WebScriptObjectAccess)

// internal properties 8.6.2

- (WebScriptObject *) _prototype; 
- (NSString *) _class;
- (id) _get:(NSString *) property;
- (void) _put:(NSString *) property value:(id) value;
- (BOOL) _canPut:(NSString *) property;
- (BOOL) _hasProperty:(NSString *) property;
- (BOOL) _delete:(NSString *) property;
- (id) _defaultValue:(Class) hint;
- (WebScriptObject *) _construct:(NSArray *) arguments;
- (WebScriptObject *) _call:(WebScriptObject *) this arguments:(NSArray *) arguments;
- (BOOL) _hasInstance:(WebScriptObject *) value;
- (id) _scope;
- (id /*<MatchResult>*/) _match:(NSString *) pattern index:(unsigned) index;

@end

// an internal object container

@interface _ConcreteWebScriptObject : WebScriptObject
{
	WebScriptObject *prototype;
	//	id value;	// do we need that?
	NSMutableDictionary *properties;
	NSMutableDictionary *attributes;	// an NSNumber object for each property containing WebScriptPropertyAttribute
}

@end

@interface _ConcreteWebScriptArray : _ConcreteWebScriptObject
// overrides _put method
@end

@interface _ConcreteWebScriptFunction : _ConcreteWebScriptObject

@end

// internal objects to support the parser

@interface NSObject (_WebScriptParsingAndEvaluation)

- (BOOL) _isReference;
- (BOOL) _isKeyword;
- (BOOL) _isKeyword:(NSString *) str;
- (id) _evaluate;	// evaluate a tree node according to evaluation rules

@end

@interface _WebScriptTreeNode : NSObject
{ // a generic tree node to build the parse tree
	@public
	id left;
	id right;
}

+ (id) node:(id) left :(id) right;	// create a new node

+ (void) _skipComments:(NSScanner *) sc;
+ (id) _primaryExpressionWithScanner:(NSScanner *) sc;	// 11.1
+ (id) _lhsExpressionWithScanner:(NSScanner *) sc forNew:(BOOL) flag;	// 11.2
+ (id) _postfixExpressionWithScanner:(NSScanner *) sc;	// 11.3
+ (id) _unaryExpressionWithScanner:(NSScanner *) sc;	// 11.4
+ (id) _multiplicativeExpressionWithScanner:(NSScanner *) sc;	// 11.5
+ (id) _additiveExpressionWithScanner:(NSScanner *) sc;	// 11.6
+ (id) _shiftExpressionWithScanner:(NSScanner *) sc;	// 11.7
+ (id) _relationalExpressionWithScanner:(NSScanner *) sc noIn:(BOOL) flag;	// 11.8
+ (id) _equalityExpressionWithScanner:(NSScanner *) sc noIn:(BOOL) flag;	// 11.9
+ (id) _bitwiseAndExpressionWithScanner:(NSScanner *) sc noIn:(BOOL) flag;	// 11.10
+ (id) _bitwiseXorExpressionWithScanner:(NSScanner *) sc noIn:(BOOL) flag;	// 11.10
+ (id) _bitwiseOrExpressionWithScanner:(NSScanner *) sc noIn:(BOOL) flag;	// 11.10
+ (id) _logicalAndExpressionWithScanner:(NSScanner *) sc noIn:(BOOL) flag;	// 11.11
+ (id) _logicalOrExpressionWithScanner:(NSScanner *) sc noIn:(BOOL) flag;	// 11.11
+ (id) _conditionalExpressionWithScanner:(NSScanner *) sc noIn:(BOOL) flag;	// 11.12
+ (id) _assignmentExpressionWithScanner:(NSScanner *) sc noIn:(BOOL) flag;	// 11.13
+ (id) _expressionWithScanner:(NSScanner *) sc noIn:(BOOL) flag;	// 11.14

+ (id) _statementWithScanner:(NSScanner *) sc;	// 12.

+ (id) _functionExpressionWithScanner:(NSScanner *) sc;	// 13.

+ (id) _programWithScanner:(NSScanner *) sc;	// 14.

@end

@interface _WebScriptTreeNodeArrayLiteralConstructor : _WebScriptTreeNode	// [ ... ]
@end

@interface _WebScriptTreeNodeObjectLiteralConstructor : _WebScriptTreeNode	// { ... }
@end

@interface _WebScriptTreeNodeThis : _WebScriptTreeNode	// this
@end

@interface _WebScriptTreeNodeKeyword : _WebScriptTreeNode	// a keyword
@end

@interface _WebScriptTreeNodeReference : _WebScriptTreeNode		// a property reference 8.7
- (WebScriptObject *) getBase;
- (NSString *) getPropertyName;
@end

@interface _WebScriptTreeNodeNew : _WebScriptTreeNode	// new
@end

@interface _WebScriptTreeNodeCall : _WebScriptTreeNode	// a(array b)
@end

@interface _WebScriptTreeNodeIndex : _WebScriptTreeNode	// a[b]
@end

@interface _WebScriptTreeNodePostfix : _WebScriptTreeNode
{	@public enum { PlusPlus, MinusMinus } op; }
@end

@interface _WebScriptTreeNodeUnary : _WebScriptTreeNode
{	@public enum { UPlusPlus, UMinusMinus, Plus, Minus, Neg, Not, Delete, Void, Typeof } op; }
@end

@interface _WebScriptTreeNodeMultiplicative : _WebScriptTreeNode
{	@public enum { Mult, Div, Mod } op;}
@end

@interface _WebScriptTreeNodeAdditive : _WebScriptTreeNode
{	@public enum { Add, Sub } op; }
@end

@interface _WebScriptTreeNodeShift : _WebScriptTreeNode
{	@public enum { Shl, Shr, UShr } op; }
@end

@interface _WebScriptTreeNodeRelational : _WebScriptTreeNode
{	@public enum { LessThan, LessEqual, InstanceOf, In } op; }
@end

@interface _WebScriptTreeNodeEquality : _WebScriptTreeNode
{	@public BOOL equal, strict; }
@end

@interface _WebScriptTreeNodeBitwise : _WebScriptTreeNode
{	@public enum { And, Xor, Or } op; }
@end

@interface _WebScriptTreeNodeLogical : _WebScriptTreeNode
{	@public enum { LAnd, LOr } op; }
@end

@interface _WebScriptTreeNodeConditional : _WebScriptTreeNode
{	@public id third; /* else option */ }
@end

@interface _WebScriptTreeNodeAssignment : _WebScriptTreeNode
{	@public enum { Assign, MultAssign } op; }
@end

@interface _WebScriptTreeNodeComma : _WebScriptTreeNode
@end

@interface _WebScriptTreeNodeIf : _WebScriptTreeNode
{	@public id third; /* else option */ }
@end

@interface _WebScriptTreeNodeWith : _WebScriptTreeNode
@end
