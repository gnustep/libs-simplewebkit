//
//  DOMCSS.m
//  SimpleWebKit
//
//  Created by Nikolaus Schaller on 12.03.07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <WebKit/WebView.h>
#import "Private.h"

@implementation DOMCSSStyleDeclaration

- (id) initWithString:(NSString *) style forDocument:(RENAME(DOMDocument) *) doc;
{ // for <style>css</style> or <tag style="css">
	if((self=[super init]))
		{
		NSScanner *sc=[NSScanner scannerWithString:style];
		// parse style string...
		}
	return self;
}

@end
