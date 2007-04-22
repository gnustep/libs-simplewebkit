//
//  DOMCSS.h
//  SimpleWebKit
//
//  Created by Nikolaus Schaller on 12.03.07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <WebKit/DOMCore.h>

@interface DOMCSSStyleDeclaration : DOMElement
{
}

- (id) initWithString:(NSString *) style forDocument:(RENAME(DOMDocument) *) doc;	// for <style>css</style> or <tag style="css">

@end