/* simplewebkit
   WebResource.m

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
#import "Private.h"
#import <WebKit/WebResource.h>

@implementation WebResource

- (NSData *) data; { return _data; }
- (NSString *) frameName; { return _frameName; }
- (NSString *) MIMEType; { return _MIMEType; }
- (NSString *) textEncodingName; { return _textEncodingName; }
- (NSURL *) URL; { return _URL; }

- (id) initWithData:(NSData *) data URL:(NSURL *) url MIMEType:(NSString *) mime textEncodingName:(NSString *) encoding frameName:(NSString *) name;
{
	if((self=[super init]))
		{
		_data=[data retain];
		_frameName=[name retain];
		_MIMEType=[mime retain];
		_textEncodingName=[encoding retain];
		_URL=[url retain];
		}
	return self;
}


- (void) dealloc;
{
	[_data release];
	[_frameName release];
	[_MIMEType release];
	[_textEncodingName release];
	[_URL release];
	[super dealloc];
}

@end
