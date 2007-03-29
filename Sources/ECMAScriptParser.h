//
//  ECMAScriptParser.h
//  mySTEP
//
//  Created by Dr. H. Nikolaus Schaller on March 2007.
//  Copyright (c) 2005 DSITRI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebScriptObject.h>

// internal objects to support the parser

@interface NSObject (_WebScriptParsing)

- (BOOL) _isReference;

@end

@interface _WebScriptTreeNode : WebScriptObject
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

+ (id) _functionExpressionWithScanner:(NSScanner *) sc optIdentifier:(BOOL) flag;	// 13.

+ (id) _programWithScanner:(NSScanner *) sc;	// 14.

@end

@interface _WebScriptTreeNodeArrayLiteralConstructor : _WebScriptTreeNode	// [ ... ]
@end

@interface _WebScriptTreeNodeObjectLiteralConstructor : _WebScriptTreeNode	// { ... }
@end

@interface _WebScriptTreeNodeThis : _WebScriptTreeNode	// this
@end

@interface _WebScriptTreeNodeIdentifier : _WebScriptTreeNode	// identifier
- (NSString *) getIdentifier;
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
{	@public _WebScriptTreeNode *otherwise; /* else option */ }
@end

@interface _WebScriptTreeNodeAssignment : _WebScriptTreeNode
{	@public enum { Assign, MultAssign, DivAssign, ModAssign, PlusAssign, MinusAssign, ShlAssign, UShrAssign, ShrAssign, AndAssign, XorAssign, OrAssign } op; }
@end

@interface _WebScriptTreeNodeComma : _WebScriptTreeNode
@end

@interface _WebScriptTreeNodeStatementList : _WebScriptTreeNode
@end

@interface _WebScriptTreeNodeVar : _WebScriptTreeNode
@end

// @interface _WebScriptTreeNodeExpression : _WebScriptTreeNode
/// @end

@interface _WebScriptTreeNodeIf : _WebScriptTreeNode
{	@public _WebScriptTreeNode *otherwise; /* else option */ }
@end

@interface _WebScriptTreeNodeIteration : _WebScriptTreeNode
{	@public enum { Do, While, ForIn, Continue, Break } op;
	_WebScriptTreeNode *inc; /* optional inc expression in For loop */ }
@end

@interface _WebScriptTreeNodeReturn : _WebScriptTreeNode
{	@public enum { Return, Throw } op; }
@end

@interface _WebScriptTreeNodeWith : _WebScriptTreeNode
@end

@interface _WebScriptTreeNodeSwitch : _WebScriptTreeNode
{	@public _WebScriptTreeNode *expr, *otherwise; /* default option */ }
@end

@interface _WebScriptTreeNodeLabel : _WebScriptTreeNode
@end

@interface _WebScriptTreeNodeTry : _WebScriptTreeNode
{	@public _WebScriptTreeNode *catch, *finally; }
@end

@interface _WebScriptTreeNodeFunction : _WebScriptTreeNode
{	@public NSArray *params; /* parameter list */ }
@end

