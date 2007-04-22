//
//  WebScriptObject.h
//  mySTEP
//
//  Created by Dr. H. Nikolaus Schaller on Tue May 16 2006.
//  Copyright (c) 2006 DSITRI. All rights reserved.
//

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

// already defined by KVC
// - (void) setValue:(id) val forKey:(NSString *) path;
// - (id) valueForKey:(NSString *) path;

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