/* simplewebkit
ECMAScriptEvaluator.m

Copyright (C) 2006-2007 Free Software Foundation, Inc.

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

//  syntax for parser is based on overview http://en.wikipedia.org/wiki/WebScript_syntax
//  and ECMAScript specification http://www.ecma-international.org/publications/standards/Ecma-262.htm

#import <WebKit/WebDOMOperations.h>
#import <WebKit/WebUndefined.h>
#import <WebKit/WebScriptObject.h>
#import "ECMAScriptParser.h"
#import "ECMAScriptEvaluator.h"
#import "ECMAScriptPrototypes.h"

#import "Private.h"

@implementation WebScriptObject (_WebScriptObjectAccess)

// default implementations for all WebScriptObjects

- (WebScriptObject *) _prototype; { return nil; }
- (NSString *) _class; { return NSStringFromClass([self class]); }	// default...
- (BOOL) _canPut:(NSString *) property; { return NO; }
- (BOOL) _hasProperty:(NSString *) property; { return NO; }
- (id) _defaultValue:(Class) hint; { return NIMP; }
- (WebScriptObject *) _construct:(NSArray *) arguments; { return NIMP; }
- (WebScriptObject *) _call:(WebScriptObject *) this arguments:(NSArray *) arguments; {	return NIMP; }
- (BOOL) _hasInstance:(WebScriptObject *) value; { return NO; }
- (id) _scope; { return NIMP; }
- (id /*<MatchResult>*/) _match:(NSString *) pattern index:(unsigned) index; { return NIMP; }

@end

@implementation NSObject (_WebScriptTypeConversion)

// default implementations

- (id) _toPrimitive:(Class) preferredType; {	return self; }	// 9.1 - already a primitive

- (NSNumber *) _toBoolean; { return NO; }	// default
- (NSNumber *) _toNumber;	{ /* typeError */ return NIMP; }	// 9.9

- (NSNumber *) _toInteger;
{
	double d=[[self _toNumber] doubleValue];
	// check for NaN -> 0
	// keep +0 / -1 or +Inf, -Inf unchanged
	if(d < 0)
		return [NSNumber numberWithDouble:-floor(-d)];
	else
		return [NSNumber numberWithDouble:floor(d)];
}

- (NSNumber *) _toInt32;
{ // 9.5
	double d=[[self _toNumber] doubleValue];
	// check for NaN -> 0
	// map +0 / -1 or +Inf, -Inf -> 0
	return [NSNumber numberWithInt:(int) d];	// is that exactly as defined???
}

- (NSNumber *) _toUint32;
{ // 9.6
	double d=[[self _toNumber] doubleValue];
	// check for NaN -> 0
	// map +0 / -1 or +Inf, -Inf -> 0
	return [NSNumber numberWithUnsignedInt:(unsigned int) d];	// is that exactly as defined???
}

- (NSNumber *) _toUint16;
{ // 9.7
	double d=[[self _toNumber] doubleValue];
	// check for NaN -> 0
	// map +0 / -1 or +Inf, -Inf -> 0
	return [NSNumber numberWithUnsignedShort:(unsigned short) d];	// is that exactly as defined???
}

- (NSString *) _toString; {	return [self description]; } // 9.8
- (WebScriptObject *) _toObject;	{ /* typeError */ return NIMP; }	// 9.9

@end

@implementation WebUndefined (_WebScriptTypeConversion)
- (NSNumber *) _toBoolean; { return [NSNumber numberWithBool:NO]; }	// default
- (NSNumber *) _toNumber;	{ return [NSNumber numberWithDouble:0.0]; }	// FIXME: should return +NaN
- (NSString *) _toString; {	return @"undefined"; } // 9.8
@end

@implementation NSNull (_WebScriptTypeConversion)
- (NSNumber *) _toBoolean; { return [NSNumber numberWithBool:NO]; }	// default
- (NSNumber *) _toNumber;	{ return [NSNumber numberWithDouble:0.0]; }
- (NSString *) _toString; {	return @"null"; } // 9.8
@end

@implementation NSNumber (_WebScriptTypeConversion)

static Class __boolClass;	// class cluster subclass for numberWithBool

- (NSNumber *) _toBoolean;
{
	double d;
	if(!__boolClass) __boolClass=[[NSNumber numberWithBool:NO] class];	// get implementating class
	if([self isKindOfClass:__boolClass])
		return self;	// already a boolean
	d=[self doubleValue];
	// if +0, -0 or NaN -> NO
	return [NSNumber numberWithBool:(d != 0.0)];
}

- (NSNumber *) _toNumber;
{
	return [NSNumber numberWithDouble:[self doubleValue]];	// also converts TRUE/FALSE -> 1.0/0.0
}

- (NSString *) _toString;
{
	if(!__boolClass) __boolClass=[[NSNumber numberWithBool:NO] class];
	if([self isKindOfClass:__boolClass])
		return [self boolValue]?@"true":@"false";
	// handle Infinity, NaN
	return [self description];
}
@end

@implementation NSString (_WebScriptTypeConversion)

- (NSNumber *) _toBoolean; { return [NSNumber numberWithBool:[self length] > 0]; }	// default

- (NSNumber *) _toNumber;
{
	NSScanner *sc=[NSScanner scannerWithString:self];
	double d;
	unsigned ui;
	[sc setCaseSensitive:NO];
	// FIXME: set whitespace according to list at 9.3.1
	if([sc scanString:@"Infinity" intoString:NULL])
		; // [NSNumber numberWithDouble:Inf];
	if([sc scanString:@"+Infinity" intoString:NULL])
		; // [NSNumber numberWithDouble:Inf];
	if([sc scanString:@"-Infinity" intoString:NULL])
		; // [NSNumber numberWithDouble:Inf];
	if([sc scanString:@"0x" intoString:NULL] && [sc scanHexInt:&ui])
		return [NSNumber numberWithDouble:(double) ui];
	if([sc scanDouble:&d])
		return [NSNumber numberWithDouble:d];
	return [NSNumber numberWithDouble:0.0];	// should be NaN
}
- (NSString *) _toString; {	return self; } // 9.8
@end

@implementation NSObject (__WebScriptDereference)

- (id) _getValue; { return self; }	// 8.7.1 - rule 1

- (void) _putValue:(id) val;
{ // 8.7.2
	[WebScriptObject throwException:@"ReferenceError"];	// 1. - is not an lvalue
}

@end

@implementation _WebScriptTreeNodeReference (_WebScriptDereference)

- (id) _getValue;
{ // 8.7.1
	if([left isKindOfClass:[NSNull class]])
//		[self setException:@"ReferenceError"];	// 3. - is not an lvalue
		return [WebUndefined undefined];
	return _GET(left, right);
}

- (void) _putValue:(id) val;
{ // 8.7.2
	if([left isKindOfClass:[NSNull class]])
		; //	[globalObject setValue:val forKey:propertyName];
	else
		_PUT(left, right, val);
}

@end

@implementation NSObject (_WebScriptEvaluation)

- (id) _evaluate:(WebScriptContext *) context;
// evaluate a tree node according to evaluation rules
{ return self; }	// primitives evaluate to themselves; statements evaluate to array triples

@end

@implementation _WebScriptTreeNode (_WebScriptEvaluation)

- (id) _evaluate:(WebScriptContext *) context;
// evaluate a tree node according to evaluation rules
{
	// SUBCLASS
	return NIMP;	// nodes can't be evaluated unless they overwrite this method
}

@end

@implementation _WebScriptTreeNodeIdentifier (_WebScriptEvaluation)

- (id) _evaluate:(WebScriptContext *) context;
// evaluate a tree node according to evaluation rules
{ // 10.1.4 - evaluate an identifier
	while(context)
		{ // walk through scope chain
		if([context->this _hasProperty:right])
			return [_WebScriptTreeNodeReference newNode:context->this :right];	// form a real reference
		context=context->nextContext;
		}
	return [[_WebScriptTreeNodeReference newNode:[NSNull null] :right] autorelease];	// undefined reference
}

@end

@implementation _WebScriptTreeNodeArrayLiteralConstructor (_WebScriptEvaluation)

- (id) _evaluate:(WebScriptContext *) context;
// evaluate a tree node according to evaluation rules
{ 
	id l;
	id r;
	unsigned idx=0;
	NSEnumerator *e=[right objectEnumerator];	// list of assignment expressions
	l=[_ConcreteWebScriptArray new];	// create a "new Array"
										// call _create...
	[l autorelease];
	while((r=[e nextObject]))
		{
		if([r isKindOfClass:[WebUndefined class]])
			continue;	// elision
		r=[r _evaluate:context];
		r=[r _getValue];
		_PUT(l, ([NSString stringWithFormat:@"%u", idx++]), r);	// store at next position
		}
	_PUT(l, @"length", [NSNumber numberWithInt:idx]);
	return l;
}

@end

@implementation _WebScriptTreeNodeObjectLiteralConstructor (_WebScriptEvaluation)

- (id) _evaluate:(WebScriptContext *) context;
// evaluate a tree node according to evaluation rules
{
	id l;
	id key, val;
	NSEnumerator *e=[left objectEnumerator];	// list of assignment expressions
	NSEnumerator *f=[right objectEnumerator];	// list of assignment expressions
	l=[_ConcreteWebScriptObject new];	// create a "new Array"
										// call _create...
	[l autorelease];
	while((key=[e nextObject], val=[f nextObject]))
		{
		if([key _isReference] && ![key getBase])
			key=[key getPropertyName];	// plain identifier
		else
			{ // is not evaluated since we assume it to be an identifier, string or numeric constant!
			key=[key _getValue];
			key=[key _toString];
			}
		val=[val _evaluate:context];
		val=[val _getValue];
		_PUT(l, key, val);
		}
	return l;
}

@end

@implementation _WebScriptTreeNodeThis (_WebScriptEvaluation)

- (id) _evaluate:(WebScriptContext *) context;
// evaluate a tree node according to evaluation rules
{ // 11.1.1
	return context->this;
}

@end

@implementation _WebScriptTreeNodeReference (_WebScriptEvaluation)

- (id) _evaluate:(WebScriptContext *) context;
// evaluate a tree node according to evaluation rules
{
	return NIMP;	// should never be called (?)
}

@end

@implementation _WebScriptTreeNodeNew (_WebScriptEvaluation)

- (id) _evaluate:(WebScriptContext *) context;
// evaluate a tree node according to evaluation rules
{ // 11.2.2
	id l;
	NSMutableArray *arglist=[NSMutableArray arrayWithCapacity:[right count]];
	NSEnumerator *e;
	id arg;
	l=[left _evaluate:context];
	l=[l _getValue];
	e=[right objectEnumerator];
	while((arg=[e nextObject]))
		[arglist addObject:[arg _evaluate:context]
];
	if(![l isKindOfClass:[WebScriptObject class]])
		[self setException:@"TypeError"];
	if(![l respondsToSelector:@selector(_construct:)])
		[self setException:@"TypeError"];
	return [l _construct:arglist];
}

@end

@implementation _WebScriptTreeNodeCall (_WebScriptEvaluation)

- (id) _evaluate:(WebScriptContext *) context;
// evaluate a tree node according to evaluation rules
{ // 11.2.3
	NSMutableArray *arglist=[NSMutableArray arrayWithCapacity:[right count]];
	NSEnumerator *e;
	id l, fn, arg, this;
	l=[left _evaluate:context];	// 1.
	e=[right objectEnumerator];
	while((arg=[e nextObject]))
		[arglist addObject:[[arg _evaluate:context] _getValue]];	// 2.	
	fn=[l _getValue];		// 3.
	if(![fn isKindOfClass:[WebScriptObject class]])
		[self setException:@"TypeError"];
	if(![fn respondsToSelector:@selector(_call:arguments:)])
		{ // try to bridge to Cocoa objects
		NSString *fnname=[l getPropertyName];
		SEL sel;
		// FIXME:
		// should we check if we are allowed to call this method? i.e. don't allow a _ prefix, don't allow to call e.g. release
		// is this the place to use the WebScriptObject informal protocol?
		fnname=[fnname stringByPaddingToLength:[fnname length]+[arglist count] withString:@":" startingAtIndex:0];		// add a : for each argument
			this=nil;	// FIXME: where to get this from???
		sel=NSSelectorFromString(fnname);
		if([this respondsToSelector:sel])
			{
			NSMethodSignature *sig=[this methodSignatureForSelector:sel];
			NSInvocation *i=[NSInvocation invocationWithMethodSignature:sig];
			[i setSelector:sel];
			[i setTarget:this];
			// assign arguments
			NS_DURING
				[i invoke];
			NS_HANDLER
				// how to handle exceptions?
				NS_ENDHANDLER
				// get return value
				return nil;
			}
			[self setException:@"TypeError"];
		}
		if([l _isReference])
			{ // 6. & 7.
			id base=[(_WebScriptTreeNodeReference *) l getBase];
			// FIXME
			//				if(![base isKindOfClass:[WebScriptActivationObject class]])
			//					this=base;
			// else
			this=base;
			}
		else
			this=[NSNull null];
		return [fn _call:this arguments:arglist];	// 8. & 9.
}

@end

@implementation _WebScriptTreeNodeIndex (_WebScriptEvaluation)

- (id) _evaluate:(WebScriptContext *) context;
// evaluate a tree node according to evaluation rules
{ // 11.2.1
	id l, r;
	l=[left _evaluate:context];			// 1.
	l=[l _getValue];				// 2.
	r=[right _evaluate:context];		// 3.
	r=[r _getValue];				// 4.
	l=[l _toObject];				// 5.
	r=[r _toString];				// 6.
	return [_WebScriptTreeNodeReference newNode:l :r];	// 7. make it a dynamic reference
}

@end

@implementation _WebScriptTreeNodePostfix (_WebScriptEvaluation)

- (id) _evaluate:(WebScriptContext *) context;
// evaluate a tree node according to evaluation rules
{ // 11.3
	id r;
	r=[[left _getValue] _toNumber];
	switch(op)
		{
		default:
		case PlusPlus:
			// add 1
			break;
		case MinusMinus:
			// subtract 1
			break;
		}
	[left _putValue:r];
	return left; 
}

@end

@implementation _WebScriptTreeNodeUnary (_WebScriptEvaluation)

- (id) _evaluate:(WebScriptContext *) context;
// evaluate a tree node according to evaluation rules
{ // 11.4
	id r, l;
	switch(op)
		{
		default:
		case UPlusPlus:
			r=[right _evaluate:context];			
			l=[[r _getValue] _toNumber];
			// add 1 to l
			[r _putValue:l];
			return l;
		case UMinusMinus:
			r=[right _evaluate:context];			
			l=[[r _getValue] _toNumber];
			// subtract 1 fm l
			[r _putValue:l];
			return l;
		case Plus:
			return [[[right _evaluate:context]
 _getValue] _toNumber];
		case Minus:
			r=[[[right _evaluate:context]
 _getValue] _toNumber];
			// if NaN return l
			return [NSNumber numberWithDouble:-[r doubleValue]];
		case Neg:
			r=[[[right _evaluate:context]
 _getValue] _toInt32];
			return [NSNumber numberWithDouble:(double) ~[r intValue]];
		case Not:
			r=[[[right _evaluate:context]
 _getValue] _toBoolean];
			return [NSNumber numberWithBool:![r boolValue]];
		case Delete:
			{ // 11.4.1
				r=[right _evaluate:context];			
				if(![r _isReference])
					return [NSNumber numberWithBool:YES];
				NS_DURING
					[[r getBase] removeWebScriptKey:[r getPropertyName]];
				NS_HANDLER
					return [NSNumber numberWithBool:NO];	// wasn't able to delete
				NS_ENDHANDLER
				return [NSNumber numberWithBool:YES];
			}
		case Void:
			{ // 11.4.2
				[[right _evaluate:context]
 _getValue];		// evaluate
				return [WebUndefined undefined];	// throw away
			}
		case Typeof:
			{ // 11.4.3
				r=[right _evaluate:context];
				if([r _isReference] && ![r getBase])
					return [WebUndefined undefined];
				r=[r _getValue];
				if([r isKindOfClass:[WebUndefined class]])
					return @"undefined";
				if([r isKindOfClass:[NSNull class]])
					return @"object";
				if([r isKindOfClass:[[NSNumber numberWithBool:NO] class]])
					return @"boolean";
				if([r isKindOfClass:[NSNumber class]])
					return @"number";
				if([r isKindOfClass:[NSString class]])
					return @"string";
				if([r isKindOfClass:[WebScriptObject class]])
					{
					if([r respondsToSelector:@selector(_call:arguments:)])
						return @"function";
					return @"object";
					}
				return NSStringFromClass([r class]);	// implementation-dependent
			}
		}
}

@end

@implementation _WebScriptTreeNodeMultiplicative (_WebScriptEvaluation)

- (id) _evaluate:(WebScriptContext *) context;
// evaluate a tree node according to evaluation rules
{ // 11.5
	id r, l;
	switch(op)
		{
		default:
		case Mult:
			{
				l=[left _evaluate:context];
				l=[l _getValue];
				r=[right _evaluate:context];
				r=[r _getValue];
				l=[l _toNumber];
				r=[r _toNumber];
				return [NSNumber numberWithDouble:[l doubleValue]*[r doubleValue]];
			}
		case Div:
			{
				l=[left _evaluate:context];
				l=[l _getValue];
				r=[right _evaluate:context];
				r=[r _getValue];
				l=[l _toNumber];
				r=[r _toNumber];
				return [NSNumber numberWithDouble:[l doubleValue]/[r doubleValue]];
			}
		case Mod:
			{
				l=[left _evaluate:context];
				l=[l _getValue];
				r=[right _evaluate:context];
				r=[r _getValue];
				l=[l _toNumber];
				r=[r _toNumber];
				return [NSNumber numberWithDouble:fmod([l doubleValue], [r doubleValue])];
			}
		}
}

@end

@interface _WebScriptTreeNodeAdditive (_WebScriptEvaluation)
+ (id) _abstractAdd:(id) l and:(id) r;
@end

@implementation _WebScriptTreeNodeAdditive (_WebScriptEvaluation)

+ (id) _abstractAdd:(id) l and:(id) r;
{ // with type conversion
	l=[l _toPrimitive:[NSString class]];	// 5.
	r=[r _toPrimitive:[NSString class]];	// 6.
	if([l isKindOfClass:[NSString class]] || [r isKindOfClass:[NSString class]])
		{ // make a string concatenate
		l=[l _toString];	// 12.
		r=[r _toString];	// 13.
		return [l stringByAppendingString:r];	// 14. & 15.
		}
	else
		{
		l=[l _toNumber];	// 8.
		r=[r _toNumber];	// 9.
		return [NSNumber numberWithDouble:[l doubleValue]+[r doubleValue]];	// 10. & 11.
		}
}

- (id) _evaluate:(WebScriptContext *) context;
// evaluate a tree node according to evaluation rules
{ // 11.6
	id r, l;
	switch(op)
		{
		default:
		case Add:
			{
				l=[left _evaluate:context];
				l=[l _getValue];
				r=[right _evaluate:context];
				r=[r _getValue];
				return [[self class] _abstractAdd:l and:r];
			}
		case Sub:
			{
				l=[left _evaluate:context];
				l=[l _getValue];
				r=[right _evaluate:context];
				r=[r _getValue];
				l=[l _toNumber];
				r=[r _toNumber];
				return [NSNumber numberWithDouble:[l doubleValue]-[r doubleValue]];
			}
		}
}

@end

@implementation _WebScriptTreeNodeShift (_WebScriptEvaluation)

- (id) _evaluate:(WebScriptContext *) context;
// evaluate a tree node according to evaluation rules
{ // 11.7
	id r, l;
	switch(op)
		{
		default:
		case Shl:
			{ // 11.7.1
				l=[left _evaluate:context];
				l=[l _getValue];
				r=[right _evaluate:context];
				r=[r _getValue];
				l=[l _toInt32];
				r=[r _toUint32];
				return [NSNumber numberWithDouble:(double) ([l intValue] << ([r intValue]&0x1f))];
			}
		case Shr:
			{ // 11.7.2
				l=[left _evaluate:context];
				l=[l _getValue];
				r=[right _evaluate:context];
				r=[r _getValue];
				l=[l _toInt32];
				r=[r _toUint32];
				return [NSNumber numberWithDouble:(double) ([l intValue] >> ([r intValue]&0x1f))];
			}
		case UShr:
			{ // 11.7.3
				l=[left _evaluate:context];
				l=[l _getValue];
				r=[right _evaluate:context];
				r=[r _getValue];
				l=[l _toInt32];
				r=[r _toUint32];
				return [NSNumber numberWithDouble:(double) (((unsigned)[l intValue]) >> ([r intValue]&0x1f))];
			}
		}
}

@end

@implementation _WebScriptTreeNodeRelational (_WebScriptEvaluation)

- (id) _evaluate:(WebScriptContext *) context;
// evaluate a tree node according to evaluation rules
{ // 10.8
	id r, l;
	l=[left _evaluate:context];
	l=[l _getValue];
	r=[right _evaluate:context];
	r=[r _getValue];
	switch(op)
		{
		case InstanceOf:
			{
				// if r is not an object -> TypeError	// 5.
				// if r does not have _hasInstance -> TypeError -- add to default implementation of _hasInstance:
				return [NSNumber numberWithBool:[r _hasInstance:l]];	// 7. & 8.
			}
		case In:
			{
				// if r is not an object -> TypeError	// 5.
				l=[l _toString];	// 6.
				return [NSNumber numberWithBool:[r _hasProperty:l]];	// 7. & 8.
			}
		default:
			{
				// implement conversion rules...
				// if undefined -> return [NSNumber numberWithBool:NO];
				switch(op)
					{
					default:	// there is no GreaterThan since we swap the arguments during parsing
					case LessThan:
						{
							return [NSNumber numberWithBool:[l doubleValue] < [r doubleValue]];
						}
					case LessEqual:
						{
							return [NSNumber numberWithBool:[l doubleValue] <= [r doubleValue]];
						}
					}
			}
		}
}

@end

@implementation _WebScriptTreeNodeEquality (_WebScriptEvaluation)

- (id) _evaluate:(WebScriptContext *) context;
// evaluate a tree node according to evaluation rules
{ // 11.9
	id r, l;
	l=[left _evaluate:context];
	l=[l _getValue];
	r=[right _evaluate:context];
	r=[r _getValue];
	if(!strict)
		{ // 11.9.3
		return [NSNumber numberWithBool:YES];
		}
	else
		{
		// FIXME: add rules of 11.9.6
		// if different type -> flag
		// if l is undefined -> !flag
		// if l is null -> !flag
		// check for strings ->
		// compare numbers
		// or strings
		// compare objects (same object or objects joined: 13.1.2)
		return [NSNumber numberWithBool:equal];		
		}
}

@end

@implementation _WebScriptTreeNodeBitwise (_WebScriptEvaluation)

- (id) _evaluate:(WebScriptContext *) context;
// evaluate a tree node according to evaluation rules
{ // 11.10
	id r, l;
	l=[left _evaluate:context];
	l=[l _getValue];
	r=[right _evaluate:context];
	r=[r _getValue];
	l=[l _toUint32];
	r=[r _toUint32];
	switch(op)
		{
		default:
		case And:
			{
				return [NSNumber numberWithDouble:(double) (unsigned) ([l intValue] & [r intValue])];
			}
		case Xor:
			{
				return [NSNumber numberWithDouble:(double) (unsigned) ([l intValue] ^ [r intValue])];
			}
		case Or:
			{
				return [NSNumber numberWithDouble:(double) (unsigned) ([l intValue] | [r intValue])];
			}
		}
}

@end

@implementation _WebScriptTreeNodeLogical (_WebScriptEvaluation)

- (id) _evaluate:(WebScriptContext *) context;
// evaluate a tree node according to evaluation rules
{ // 11.11
	id l;
	l=[left _evaluate:context];
	l=[l _getValue];
	l=[l _toBoolean];
	switch(op)
		{
		default:
		case LAnd:
			{
				if([l boolValue])
					return [right _evaluate:context];
				return l;
			}
		case LOr:
			{
				if(![l boolValue])
					return [right _evaluate:context];
				return l;
			}
		}
}

@end

@implementation _WebScriptTreeNodeConditional (_WebScriptEvaluation)

- (id) _evaluate:(WebScriptContext *) context;
// evaluate a tree node according to evaluation rules
{ // 11.12
	id l;
	l=[left _evaluate:context];
	l=[l _toBoolean];
	if([l boolValue])
		return [right _evaluate:context];
	else
		return [otherwise _evaluate:context];
}

@end

@implementation _WebScriptTreeNodeAssignment (_WebScriptEvaluation)

- (id) _evaluate:(WebScriptContext *) context;
// evaluate a tree node according to evaluation rules
{ // 11.13
	id r, l;
	r=[right _getValue];
	if(op == Assign)
		{ // plain assignment
		[left _putValue:r];	// left must be a reference...
		return left;
		}
	l=[left _getValue];	// get current value
	switch(op)
		{
		case MultAssign:
			r=[r _evaluate:context];
			l=[l _toNumber];
			r=[r _toNumber];
			r=[NSNumber numberWithDouble:[l doubleValue]*[r doubleValue]];
			break;
		// FIXME: case ModAssign:
		case DivAssign:
			r=[r _evaluate:context];
			l=[l _toNumber];
			r=[r _toNumber];
			r=[NSNumber numberWithDouble:[l doubleValue]/[r doubleValue]];
			break;
		case PlusAssign:
			r=[r _evaluate:context];
			r=[_WebScriptTreeNodeAdditive _abstractAdd:l and:r];
			break;
		case MinusAssign:
			r=[r _evaluate:context];
			l=[l _toNumber];
			r=[r _toNumber];
			r=[NSNumber numberWithDouble:[l doubleValue]-[r doubleValue]];
			break;
		/* FIXME: case ShlAssign:
		case UShrAssign:
		case ShrAssign:
		case AndAssign:
		case XorAssign:
		case OrAssign: */
		default:
			[WebScriptObject throwException:@"Assignment type not implemented"];
			break;
		}
	[left _putValue:r];	// left must be a reference...
	return left;	// result
}

@end

@implementation _WebScriptTreeNodeComma (_WebScriptEvaluation)	// comma operator

- (id) _evaluate:(WebScriptContext *) context;
// evaluate a tree node according to evaluation rules
{ // 11.14
  // ignore left - or must we evaluate and call _getValue???
	return [right _evaluate:context];
}

@end

// FIXME: check what we should do exactly with Spec

@implementation _WebScriptTreeNodeStatementList (_WebScriptEvaluation)

- (id) _evaluate:(WebScriptContext *) context;
// evaluate a tree node according to evaluation rules
{ // 11.
	[left _evaluate:context];
	return [right _evaluate:context];
}

@end

@implementation _WebScriptTreeNodeVar (_WebScriptEvaluation)

- (id) _evaluate:(WebScriptContext *) context;
// evaluate a tree node according to evaluation rules
{ // define variable and handle assignment
	// add property to context->this
	// assign inital value
	// return reference to new variable
	return nil;
}

@end

@implementation _WebScriptTreeNodeIf (_WebScriptEvaluation)

- (id) _evaluate:(WebScriptContext *) context;
// evaluate a tree node according to evaluation rules
{
	id l;
	l=[left _evaluate:context];
	l=[l _toBoolean];
	if([l boolValue])
		return [right _evaluate:context];
	else
		return [otherwise _evaluate:context];	// FIXME: returns nil if else part is not present!?!
}

@end

@implementation  _WebScriptTreeNodeIteration (_WebScriptEvaluation)

// {	@public enum { Do, While, ForIn, Continue, Break } op;
//	_WebScriptTreeNode *inc; /* optional inc expression in For loop */ }

// optional for loops: add a timer/counter to regularly call the Runloop/NSApp nextEvent and/or check stack overflow 

@end

@implementation _WebScriptTreeNodeReturn (_WebScriptEvaluation)

// {	@public enum { Return, Throw } op; }

@end

@implementation _WebScriptTreeNodeWith (_WebScriptEvaluation)

- (id) _evaluate:(WebScriptContext *) context;
// evaluate a tree node according to evaluation rules
{
	WebScriptContext newContext=*context;
	id l, r;
	l=[left _evaluate:context];
	l=[[l _getValue] _toObject];	// 2. & 3.
	newContext.nextContext=context;	// chain context
	// FIXME: is this different from scope?
	// i.e. what does with(x) really do? It does NOT replace 'this'
	newContext.this=l;
	NS_DURING
		r=[right _evaluate:&newContext];
	NS_HANDLER
		r=nil;	// (trow, localException, empty)
	NS_ENDHANDLER
	// remove from the front of the scope chain	// 7.
	return r;
}

@end

@implementation _WebScriptTreeNodeSwitch (_WebScriptEvaluation)

// {	@public _WebScriptTreeNode *expr, *otherwise; /* default option */ }

@end

@implementation _WebScriptTreeNodeLabel (_WebScriptEvaluation)
@end

@implementation _WebScriptTreeNodeTry (_WebScriptEvaluation)

// {	@public _WebScriptTreeNode *catch, *finally; }

@end

@implementation _WebScriptTreeNodeFunction (_WebScriptEvaluation)

// {	@public NSArray *params; /* parameter list */ }

// optional for loops: add a timer/counter to regularly call the Runloop/NSApp nextEvent and/or check stack overflow 

@end
