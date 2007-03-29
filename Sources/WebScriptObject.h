/* simplewebkit
   WebScriptObject.h

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

#import <Cocoa/Cocoa.h>

typedef enum _WebScriptPropertyAttribute
{ // 8.6.1
	WebScriptPropertyAttributeReadOnly = 0x0001,
	WebScriptPropertyAttributeDontEnum = 0x0002,
	WebScriptPropertyAttributeDontDelete = 0x0004,
	WebScriptPropertyAttributeReadInternal = 0x8000			// not really used
} WebScriptPropertyAttribute;


@interface WebScriptObject : NSObject
{ // a generic script object
}

+ (BOOL) throwException:(NSString *) message;

- (id) evaluateWebScript:(NSString *) script;

- (id) callWebScriptMethod:(NSString *) name withArguments:(NSArray *) args;
- (void) removeWebScriptKey:(NSString *) key;
- (void) setWebScriptValueAtIndex:(unsigned int) index value:(id) value;
- (id) webScriptValueAtIndex:(unsigned int) index;

- (void) setException:(NSString *) message;
- (NSString *) stringRepresentation;

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

