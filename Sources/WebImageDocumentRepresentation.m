//
//  WebImageDocumentRepresentation.m
//  SimpleWebKit
//
//  Created by Nikolaus Schaller on 27.01.07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "WebImageDocumentRepresentation.h"
#import "Private.h"

@implementation _WebImageDocumentRepresentation

// methods from WebDocumentRepresentation protocol

- (void) finishedLoadingWithDataSource:(WebDataSource *) source;
{
	NSLog(@"WebImageDocumentRepresentation finishedLoadingWithDataSource");
	// initialize NSImage with [source data]
}

- (void) receivedData:(NSData *) data withDataSource:(WebDataSource *) source;
{
	// handle partial image data
#if 1
	NSLog(@"WebImageDocumentRepresentation receivedData");
#endif
}

- (void) receivedError:(NSError *) error withDataSource:(WebDataSource *) source;
{
	NSLog(@"WebImageDocumentRepresentation receivedError: %@", error);
}

- (void) setDataSource:(WebDataSource *) dataSource; { _dataSource=dataSource; }

- (NSString *) title;
{
	NSString *file=[[[[_dataSource response] URL] path] lastPathComponent];
	NSSize size=NSZeroSize;
	return [NSString stringWithFormat:@"%@ %ux&u Pixel", file, size.width, size.height];
}

- (BOOL) canProvideDocumentSource; { return NO; }

- (NSString *) documentSource;	{ return NIMP; }

@end

@interface _WebImageDocumentView : NSImageView <WebDocumentView>

@end

@implementation _WebImageDocumentView

@end

@implementation _WebImageDocumentView (NSPrivate)

- (void) dataSourceUpdated:(WebDataSource *) source;
{
}

- (void) layout;
{
}

- (void) setDataSource:(WebDataSource *) source;
{
}

- (void) setNeedsLayout:(BOOL) flag;
{
}

- (void) viewDidMoveToHostWindow;
{
}

- (void) viewWillMoveToHostWindow:(NSWindow *) win;
{
}

@end