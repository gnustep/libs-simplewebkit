//
//  WebXMLDocumentRepresentation.m
//  SimpleWebKit
//
//  Created by Nikolaus Schaller on 27.01.07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "WebXMLDocumentRepresentation.h"


@implementation _WebXMLDocumentRepresentation

// methods from WebDocumentRepresentation protocol

- (void) finishedLoadingWithDataSource:(WebDataSource *) source;
{
	NSLog(@"WebXMLDocumentRepresentation finishedLoadingWithDataSource");
}

- (void) receivedData:(NSData *) data withDataSource:(WebDataSource *) source;
{
	// handle partial XML data
	// should analyze the XML data and pretty/colorizes print or indicate errors
#if 1
	NSLog(@"WebXMLDocumentRepresentation receivedData");
#endif
}

- (void) receivedError:(NSError *) error withDataSource:(WebDataSource *) source;
{
	NSLog(@"WebXMLDocumentRepresentation receivedError: %@", error);
}

- (void) setDataSource:(WebDataSource *) dataSource; { _dataSource=dataSource; }

- (NSString *) title; { return [[[_dataSource response] URL] absoluteString]; }

- (BOOL) canProvideDocumentSource; { return YES; }

- (NSString *) documentSource;
{ // should be in UTF8...
	return [[[NSString alloc] initWithData:[_dataSource data] encoding:NSUTF8StringEncoding] autorelease];
}

@end
