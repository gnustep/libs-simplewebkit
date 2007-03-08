/* simplewebkit
   WebScriptObject.h

   Copyright (C) 2007 Free Software Foundation, Inc.

   Author: Dr. H. Nikolaus Schaller

   This file is part of the GNUstep Database Library.

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

#import <Cocoa/Cocoa.h>

@interface WebScriptObject : NSObject
{
}

+ (BOOL) throwException:(NSString *) message;

- (id) callWebScriptMethod:(NSString *) name withArguments:(NSArray *) args;
- (id) evaluateWebScript:(NSString *) script;
- (void) removeWebScriptKey:(NSString *) key;
- (void) setException:(NSString *) message;
- (void) setWebScriptValueAtIndex:(unsigned int) index value:(id) value;
- (NSString *) stringRepresentation;
- (id) webScriptValueAtIndex:(unsigned int) index;

	// KVC

- (void) setValue:(id) val forKey:(NSString *) path;
- (id) valueForKey:(NSString *) path;

@end

@interface NSObject (WebScripting)
+ (BOOL) isKeyExcludedFromWebScript:(const char *) name;
+ (BOOL) isSelectorExcludedFromWebScript:(SEL) sel;
+ (NSString *) webScriptNameForKey:(const char *) name;
+ (NSString *) webScriptNameForSelector:(SEL) sel;
- (void) finalizeForWebScript;
- (id) invokeDefaultMethodWithArguments:(NSArray *) args;
- (id) invokeUndefinedMethodFromWebScript:(NSString *) name
							withArguments:(NSArray *) args;
@end
