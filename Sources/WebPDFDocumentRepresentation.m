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

#if 1	// really required? we can't parse PDF before everything is received...
- (void) receivedData:(NSData *) data withDataSource:(WebDataSource *) source;
{
#if 1
	NSLog(@"WebPDFDocumentRepresentation receivedData");
#endif
}
#endif

- (void) receivedError:(NSError *) error withDataSource:(WebDataSource *) source;
{
	NSLog(@"WebPDFDocumentRepresentation receivedError: %@", error);
}

- (void) setDataSource:(WebDataSource *) dataSource; { _dataSource=dataSource; }

- (NSString *) title; { return [[[_dataSource response] URL] absoluteString]; }

- (BOOL) canProvideDocumentSource; { return NO; }

- (NSString *) documentSource;	{ return NIMP; }

@end
