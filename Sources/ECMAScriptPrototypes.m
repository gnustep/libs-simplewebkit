//
//  ECMAScriptPrototype.m
//  SimpleWebKit
//
//  Created by Dr. H. Nikolaus Schaller on Tue May 16 2006.
//  Added Java/ECMAScript by H. Nikolaus Schaller on 15.03.07.
//  Copyright (c) 2006 DSITRI. All rights reserved.
//
//  syntax for parser is based on overview http://en.wikipedia.org/wiki/WebScript_syntax
//	and ECMAScript specification http://www.ecma-international.org/publications/standards/Ecma-262.htm
//

#import <WebKit/WebDOMOperations.h>
#import <WebKit/WebUndefined.h>
#import <WebKit/WebScriptObject.h>
#import "ECMAScriptParser.h"
#import "ECMAScriptEvaluator.h"
#import "ECMAScriptPrototypes.h"

#import "Private.h"

// a real (internal) WebScriptObjec

@implementation _ConcreteWebScriptObject

// CHECKME: we should replace all calls to _get: etc. by methods defined by our superclass WebScriptObject

- (id) init;
{
	if((self=[super init]))
		{
		properties=[[NSMutableDictionary alloc] initWithCapacity:20];
		}
	return self;
}

- (void) dealloc;
{
	[properties release];
	[super dealloc];
}

- (NSString *) description;
{
	// should format the properties in WebScript format
	// i.e. something like { key:value, key:value etc. }
	// add proper indentation to all lines of sub-properties
	return [properties description];
}

- (WebScriptObject *) _prototype; { return prototype; }
- (NSString *) _class; { return NSStringFromClass(isa); }	// default...

- (id) valueForKey:(NSString *) property;
{ // 8.6.2.1
	id val;
	if((val=[properties objectForKey:property]))	// 1. & 2.
		return val;	// 3. got it
	if(!prototype)
		return [WebUndefined undefined];	// 4.
	return _GET(prototype, property);	// 5. & 6.ask prototype
}

// override in Array object  15.4.5.1

- (void) setValue:(id) val forKey:(NSString *) property;
{ // 8.6.2.2
	if(![self _canPut:property])
		return;
	if(![attributes objectForKey:property])
		[attributes setObject:[NSNumber numberWithInt:0] forKey:property];
	[properties setObject:val forKey:property];
}

- (BOOL) _canPut:(NSString *) property;
{ // 8.6.2.3
	NSNumber *att=[attributes objectForKey:property];
	if(!att)	// does not exist yet
		return [prototype _canPut:property];	// ask prototype - if present
	return ([att intValue]&WebScriptPropertyAttributeReadOnly) == 0;	// does not have readonly
}

- (BOOL) _hasProperty:(NSString *) property;
{ // 8.6.2.4
	return [properties objectForKey:property] || [prototype _hasProperty:property];
}

- (void) removeWebScriptKey:(NSString *) property;
{ // 8.6.2.5
	if(![properties objectForKey:property])
		return;	// did not exist
	NSAssert(!([[attributes objectForKey:property] intValue]&WebScriptPropertyAttributeDontDelete), @"can't delete property");	// raises exceprion
	[properties removeObjectForKey:property];
	[attributes removeObjectForKey:property];
}

- (id) _defaultValue:(Class) hint;
{ // 8.6.2.6
	id val;
	if([hint isKindOfClass:[NSString class]] || [self isKindOfClass:[NSDate class]])	// Fixme...
		{ // rules for String or Date hint
		val=_GET(self, @"toString");
		if([val isKindOfClass:isa])
			{ // is an object (step 3-4)
			val=[val _call:self arguments:nil];
			if(![val isKindOfClass:isa])
				return val;	// appears to be a primitive value
			}
		val=_GET(self, @"valueOf");	// look for valueOf method
		if([val isKindOfClass:isa])
			{ // is an object (step 7-8)
			val=[val _call:self arguments:nil];
			if(![val isKindOfClass:isa])
				return val;	// appears to be a primitive value
			}
		}
	else
		{ // rules for Number or nil hint
		val=_GET(self, @"valueOf");
		if([val isKindOfClass:isa])
			{ // is an object (step 3-4)
			val=[val _call:self arguments:nil];
			if(![val isKindOfClass:isa])
				return val;	// appears to be a primitive value
			}
		val=_GET(self, @"toString");
		if([val isKindOfClass:isa])
			{ // is an object (step 7-8)
			val=[val _call:self arguments:nil];
			if(![val isKindOfClass:isa])
				return val;	// appears to be a primitive value
			}
		}
	[self setException:@"TypeError"];
	return nil;
}

- (WebScriptObject *) _construct:(NSArray *) arguments;
{
	return NIMP;
}

- (WebScriptObject *) _call:(WebScriptObject *) this arguments:(NSArray *) arguments;
{
	return NIMP;
}

- (BOOL) _hasInstance:(WebScriptObject *) value;
{
	NIMP; return NO;
}

- (id) _scope;
{
	return NIMP;
}

- (id /*<MatchResult>*/) _match:(NSString *) pattern index:(unsigned) index;
{
	return NIMP;
}

// override type conversion

- (id) _toPrimitive:(Class) preferredType; { return [self _defaultValue:preferredType]; } // 9.1
- (NSNumber *) _toBoolean;					{ return [NSNumber numberWithBool:YES]; }
- (NSNumber *) _toNumber;						{ return [[self _toPrimitive:[NSNumber class]] _toNumber]; }
- (NSString *) _toString;						{ return [[self _toPrimitive:[NSString class]] _toString]; } // 9.8
- (WebScriptObject *) _toObject;		{ return self; }	// 9.9

@end

@implementation _ConcreteWebScriptArray
// overrides _put method
@end

@implementation _ConcreteWebScriptFunction

@end