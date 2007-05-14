/* simplewebkit
   WebDocumentRepresentation.m

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

	 Revision $Id: WebDocumentRepresentation.h 515 2007-05-07 07:07:18Z hns $

*/

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
