/* simplewebkit
   WebCSSDocumentRepresentation.h

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

#import "WebCSSDocumentRepresentation.h"
#import "Private.h"

@implementation _WebCSSDocumentRepresentation

// methods from WebDocumentRepresentation protocol

- (void) finishedLoadingWithDataSource:(WebDataSource *) source;
{
	// FIXME: which encoding should we use?
	NSString *css=[[NSString alloc] initWithData:[source data] encoding:NSUTF8StringEncoding];
	NSLog(@"WebCSSDocumentRepresentation finishedLoadingWithDataSource");
	// parse CSS document
	// how do we handle @include ??? - we should not block until we have loaded the resource
	[css release];
}

@end
