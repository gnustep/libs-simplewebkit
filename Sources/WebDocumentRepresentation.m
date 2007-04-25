//
//  WebDocumentRepresentation.m
//  SimpleWebKit
//
//  Created by Nikolaus Schaller on 27.01.07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "WebDocumentRepresentation.h"
#import "Private.h"

@implementation _WebDocumentRepresentation

// generic methods from WebDocumentRepresentation protocol

- (void) finishedLoadingWithDataSource:(WebDataSource *) source; { return; }

// we should from time to time call [WebDocumentView dataSourceUpdated:source]

- (void) receivedData:(NSData *) data withDataSource:(WebDataSource *) source; { return; }

- (void) receivedError:(NSError *) error withDataSource:(WebDataSource *) source;
{ // default error handler
	NSLog(@"%@ receivedError: %@", NSStringFromClass(isa), error);
}

// default implementations

- (void) setDataSource:(WebDataSource *) dataSource; { _dataSource=dataSource; }

- (NSString *) title; { return nil; }	// default
- (BOOL) canProvideDocumentSource; { return NO; }
- (NSString *) documentSource;	{ return NIMP; }

- (NSString *) description;
{
	return [NSString stringWithFormat:@"%@: %@", [super description], _dataSource];
}

@end

@implementation NSView (WebDocumentView)

- (void) _recursivelySetNeedsLayout;
{ // make all our subviews reparse from DOM tree [xxx setNeedsLayout:YES];
	if([self respondsToSelector:@selector(setNeedsLayout:)])
		[(id <WebDocumentView>) self setNeedsLayout:YES];
	[[self subviews] makeObjectsPerformSelector:_cmd];
}

@end
