/* simplewebkit
   WebScriptObject.m

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
{ // evaluate for given node - is this also the eval("") method?
	// couldn't we use [self callWebScriptMethod:@"eval" withArguments:[NSArray arrayWithObject:script]];
	id r=nil;
	// if(disabled by WebPrefs) return nil;
	NS_DURING
		{
			NSScanner *sc=[NSScanner scannerWithString:script];
			r=[_WebScriptTreeNode _programWithScanner:sc block:NO];
			//				NSLog(@"script=%@", r);
			// how do we pass all the environment context (windows, event, etc.)?
			// well, if we are a DOMElement we should know our DOMDocument and that should know everything
			// but sample code from the WWW shows that this method runs with "self" as the "this" object, i.e.
			// they use [[webView windowScriptObject] evaluateWebScript:@"xxx"]
			// and [[[webView windowScriptObject] valueForKeyPath:@"document.documentElement.offsetWidth"] floatValue]
#if 0	// disabled for tests if the parser is working well
			r=[r _evaluate];	// evaluate
			r=[r _getValue];	// dereference if needed
			r=[r _toString];	// always convert to NSString (?)
#endif
		}
	NS_HANDLER
		r=[NSString stringWithFormat:@"<WebScript Exception: %@>", [localException reason]];
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

- (void) setValue:(id) value forKey:(NSString *) key;
{ // KVC setter
	NIMP;
}

- (id) valueForKey:(NSString *) key;
{ // KVG getter
	return NIMP;
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
