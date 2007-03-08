/* simplewebkit
   WebImageDocumentRepresentation.m

   Copyright (C) 2007 Free Software Foundation, Inc.

   Author: Dr. H. Nikolaus Schaller

   This file is part of the GNUstep Database Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
*/

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
