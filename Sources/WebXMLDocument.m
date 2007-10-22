/* simplewebkit
   WebXMLDocumentRepresentation.m

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

#import "WebXMLDocument.h"


@implementation _WebXMLDocumentRepresentation

// methods from WebDocumentRepresentation protocol

- (void) finishedLoadingWithDataSource:(WebDataSource *) source;
{
	/*
	 check if we have something similar to:

	 <?xml version="1.0"?>
	 <rss version="2.0">

	 if yes:

	 NSURL *url=[[source initialRequest] URL];
	 NSURL *feed=[[[NSURL alloc] initWithScheme:@"feed" host:[url host] path:[url path]] autorelease];
	 [[webframe webFrame] _performClientRedirectToURL:feed delay:0.0];
	*/
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

- (NSString *) title; { return [[[_dataSource response] URL] absoluteString]; }

- (BOOL) canProvideDocumentSource; { return YES; }

- (NSString *) documentSource;
{ // XML should be in UTF8...
	return [[[NSString alloc] initWithData:[_dataSource data] encoding:NSUTF8StringEncoding] autorelease];
}

@end
