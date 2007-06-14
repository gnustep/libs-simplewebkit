//
//  WebTextDocumentRepresentation.m
//  SimpleWebKit
//
//  Created by Nikolaus Schaller on 27.01.07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "WebTextDocumentRepresentation.h"
#import "Private.h"

@implementation _WebTextDocumentRepresentation

// methods from WebDocumentRepresentation protocol

- (void) finishedLoadingWithDataSource:(WebDataSource *) source;
{
	// FIXME: which encoding should we use?
	NSString *str=[[NSString alloc] initWithData:[source data] encoding:NSUTF8StringEncoding];
	NSLog(@"WebTextDocumentRepresentation finishedLoadingWithDataSource");
	// display in our related NSTextView as plain text
}

@end