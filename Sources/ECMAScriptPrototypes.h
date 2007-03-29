//
//  ECMAScriptPrototype.h
//  mySTEP
//
//  Created by Dr. H. Nikolaus Schaller on March 2007.
//  Copyright (c) 2005 DSITRI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebScriptObject.h>

@interface _ConcreteWebScriptObject : WebScriptObject
{
	WebScriptObject *prototype;
	//	id value;	// do we need that?
	NSMutableDictionary *properties;
	NSMutableDictionary *attributes;	// an NSNumber object for each property containing WebScriptPropertyAttribute
}

@end

@interface _ConcreteWebScriptArray : _ConcreteWebScriptObject
// overrides _put method
@end

@interface _ConcreteWebScriptFunction : _ConcreteWebScriptObject

@end