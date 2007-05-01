/* simplewebkit
   ECMAScriptEvaluator.h

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

// FIXME: this appears to be redundant to some of the WebScriptObject methods!!!

// internal properties 8.6.2

- (WebScriptObject *) _prototype; 
- (NSString *) _class;

#define _GET(O, P) [(O) valueForKey:(P)]
#define _PUT(O, P, VAL) [(O) setValue:(VAL) forKey:(P) ]
- (BOOL) _canPut:(NSString *) property;
- (BOOL) _hasProperty:(NSString *) property;
#define _DELETE(O, P) [(O) removeWebScriptKey:(P)]
- (id) _defaultValue:(Class) hint;
- (WebScriptObject *) _construct:(NSArray *) arguments;
- (WebScriptObject *) _call:(WebScriptObject *) this arguments:(NSArray *) arguments;
// --> - (id) callWebScriptMethod:(NSString *) name withArguments:(NSArray *) args;
- (BOOL) _hasInstance:(WebScriptObject *) value;
- (id) _scope;
- (id /*<MatchResult>*/) _match:(NSString *) pattern index:(unsigned) index;

@end
