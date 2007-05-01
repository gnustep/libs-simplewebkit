/* simplewebkit
   WebArchive.m

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


#import <WebKit/WebArchive.h>
#import <WebKit/WebResource.h>

#import "Private.h"

NSString *WebArchivePboardType=@"WebArchivePboardType";

@implementation WebArchive

- (NSData *) _archivedData;
{
	return NIMP;
}

- (id) initWithData:(NSData *) data;
{
	return NIMP;
}

- (id) initWithMainResource:(WebResource *) main subresources:(NSArray *) sub subframeArchives:(NSArray *) frames;
{
	if((self=[super init]))
		{
		_mainResource=[main retain];
		_subframeArchives=[sub retain];
		_subresources=[frames retain];
		}
	return self;
}

- (void) dealloc;
{
	[_mainResource release];
	[_subframeArchives release];
	[_subresources release];
	[super dealloc];
}

- (WebResource *) mainResource; { return _mainResource; }
- (NSArray *) subframeArchives; { return _subframeArchives; }
- (NSArray *) subresources; { return _subresources; }

@end
