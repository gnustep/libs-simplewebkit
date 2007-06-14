/* simplewebkit
   WebImageDocumentRepresentation.h

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

#import <Foundation/Foundation.h>
#import <AppKit/NSImage.h>
#import <WebKit/WebFrameView.h>
#import <WebKit/WebFrame.h>
#import <WebKit/WebDataSource.h>
#import <WebKit/WebDocument.h>
#import <WebKit/WebHistoryItem.h>
#import <WebKit/WebView.h>
#import "WebDocumentRepresentation.h"

@interface _WebImageDocumentRepresentation : _WebDocumentRepresentation
{
	NSImage *_image;
}

- (NSImage *) getImage;	// get as good as we can - may be a placeholder

@end

@interface _WebImageDocumentView : NSImageView <WebDocumentView>
{
	WebDataSource *_dataSource;
	BOOL _needsLayout;
}

@end

