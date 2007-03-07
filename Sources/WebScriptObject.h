//
//  WebScriptObject.h
//  mySTEP
//
//  Created by Dr. H. Nikolaus Schaller on Tue May 16 2006.
//  Copyright (c) 2006 DSITRI. All rights reserved.
//

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