//
//  WebPDFDocumentRepresentation.m
//  SimpleWebKit
//
//  Created by Nikolaus Schaller on 27.01.07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "WebPDFDocumentRepresentation.h"
#import "Private.h"


@implementation _WebPDFDocumentRepresentation

// methods from WebDocumentRepresentation protocol

- (void) finishedLoadingWithDataSource:(WebDataSource *) source;
{
	NSLog(@"WebPDFDocumentRepresentation finishedLoadingWithDataSource");
	// initialize PDFDocument with [source data]
}

- (NSString *) title; { return [[[_dataSource response] URL] absoluteString]; }

@end
