//
//  ECMAScriptEvaluator.h
//  mySTEP
//
//  Created by Dr. H. Nikolaus Schaller on March 2007.
//  Copyright (c) 2005 DSITRI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebScriptObject.h>

@interface NSObject (_WebScriptEvaluation)

- (id) _evaluate;	// evaluate a tree node according to evaluation rules

// should we use?

- (id) _evaluate:(WebScriptObject *) scopeChain global:(WebScriptObject *) vars this:(WebScriptObject *) this;

@end

@interface NSObject (_WebScriptDereference)

// dereference 8.7

- (id) _getValue;								// 8.7.1
- (void) _putValue:(id) val;		// 8.7.2

@end

@interface NSObject (_WebScriptTypeConversion)

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

@interface WebScriptObject (_WebScriptObjectAccess)

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