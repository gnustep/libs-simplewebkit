//
//  WebScriptObject.m
//  mySTEP
//
//  Created by Dr. H. Nikolaus Schaller on Tue May 16 2006.
//  Copyright (c) 2006 DSITRI. All rights reserved.
//

#import <WebKit/WebDOMOperations.h>
#import "Private.h"

@implementation WebScriptObject

+ (BOOL) throwException:(NSString *) message;
{
	NIMP;
	return NO;
}

- (id) callWebScriptMethod:(NSString *) name withArguments:(NSArray *) args;
{
	return NIMP;
}

- (id) evaluateWebScript:(NSString *) script;
{
	return NIMP;
}

- (void) removeWebScriptKey:(NSString *) key;
{
	NIMP;
}

- (void) setException:(NSString *) message;
{
	NIMP;
}

- (void) setWebScriptValueAtIndex:(unsigned int) index value:(id) value;
{
	NIMP;
}

- (NSString *) stringRepresentation;
{
	return NIMP;
}

- (id) webScriptValueAtIndex:(unsigned int) index;
{
	return NIMP;
}

	// KVC

- (void) setValue:(id) val forKey:(NSString *) path;
{
	NIMP;
}

- (id) valueForKey:(NSString *) path;
{
	return NIMP;
}

@end