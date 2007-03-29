/* simplewebkit
   WebPDFDocumentRepresentation.m

   Copyright (C) 2007 Free Software Foundation, Inc.

   Author: Dr. H. Nikolaus Schaller

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
