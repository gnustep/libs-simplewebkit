//
//  WebScriptObject.m
//  SimpleWebKit
//
//  Created by Dr. H. Nikolaus Schaller on Tue May 16 2006.
//  Added Java/ECMAScript by H. Nikolaus Schaller on 15.03.07.
//  Copyright (c) 2006 DSITRI. All rights reserved.
//

#import <WebKit/WebDOMOperations.h>
#import <WebKit/WebScriptObject.h>
#import <WebKit/WebUndefined.h>
#import "ECMAScriptParser.h"
#import "ECMAScriptEvaluator.h"

#import "Private.h"

NSString *WebScriptException=@"WebScriptException";

/* implementation of public methods */

@implementation WebScriptObject

// CHECKME: are we the "global" object or its runtime extension?

+ (void) initialize;
{
	/* predefine global variables so that they return a prototype object
		Array, Boolean, Date, Function, Math, Number, Object, RegExp, String
	with predefined WebScriptBuiltinFunction for methods like length, size etc.
	
		Browser predefines variables through the context like
	navigator
	document
	event
	window
	
	*/
}

+ (BOOL) throwException:(NSString *) message;
{
	[[NSException exceptionWithName:WebScriptException reason:message userInfo:nil] raise];
	return NO;
}

- (id) callWebScriptMethod:(NSString *) name withArguments:(NSArray *) args;
{
	return [[_GET(self, name) _getValue] _call:self arguments:args];
}

- (id) evaluateWebScript:(NSString *) script;
{ // evaluate for given node - is this the eval("") method?
	id r=nil;
		NS_DURING
			{
				NSScanner *sc=[NSScanner scannerWithString:script];
				r=[_WebScriptTreeNode _programWithScanner:sc];
				// how do we pass all the environment context (windows, event, etc.)?
				// well, if we are a DOMElement we should know our DOMDocument and that should know everything
				// but sample code from the WWW shows that this method runs with "self" as the "this" object, i.e.
				// they use [[webView windowScriptObject] evaluateWebScript:@"xxx"]
				// and [[[webView windowScriptObject] valueForKeyPath:@"document.documentElement.offsetWidth"] floatValue]
				r=[r _evaluate];	// evaluate
				r=[r _getValue];	// dereference if needed
				r=[r _toString];	// always convert to NSString
			}
		NS_HANDLER
			r=[NSString stringWithFormat:@"<WebScript Internal Exception: %@>", [localException reason]];
		NS_ENDHANDLER
		return r;
}

- (void) removeWebScriptKey:(NSString *) key;
{
	NIMP;	// not for generic object
}

- (void) setException:(NSString *) message;
{
	[[NSException exceptionWithName:WebScriptException reason:message userInfo:[NSDictionary dictionaryWithObject:self forKey:@"this"]] raise];
}

- (void) setWebScriptValueAtIndex:(unsigned int) index value:(id) val;
{
	NIMP;	// not for generic object
	_PUT(self, @"key from index", val);
}

- (NSString *) stringRepresentation;
{
	// should we format an array or object in JavaScript language?
	return [self description];
}

- (id) webScriptValueAtIndex:(unsigned int) index;
{
	return NIMP;	// not for generic object
	return _GET(self, @"key from index");
}

@end

@implementation NSObject (WebScripting)

// NIMP - we don't do that until we need it and understand the security implications (if a webscript can access any Cocoa class and method)
// it appears that it is Full-WebKits way of bridging Cocoa objects to the JavaScript execution space

+ (BOOL) isKeyExcludedFromWebScript:(const char *) name; { return YES; }
+ (BOOL) isSelectorExcludedFromWebScript:(SEL) sel; { return YES; }
+ (NSString *) webScriptNameForKey:(const char *) name; { return @"?"; }
+ (NSString *) webScriptNameForSelector:(SEL) sel; { return @"?"; }
- (void) finalizeForWebScript; { return; }
- (id) invokeDefaultMethodWithArguments:(NSArray *) args; { return NIMP; }
- (id) invokeUndefinedMethodFromWebScript:(NSString *) name
														withArguments:(NSArray *) args; { return NIMP; }

@end

@implementation WebUndefined

+ (id) _alloc; { return [super alloc]; }
+ (id) alloc; { return NIMP; }	// don't call explicitly...

+ (WebUndefined *) undefined
{ // constant like NSNull but used by WebScript
	static WebUndefined *undef=nil;
	if(!undef)
		undef=[[self _alloc] init];
	return undef;
}

- (NSString *) description;
{
	return @"undefined";
}

@end