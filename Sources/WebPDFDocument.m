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

#import "WebPDFDocument.h"
#import "Private.h"


@implementation _WebPDFDocumentRepresentation

// methods from WebDocumentRepresentation protocol

- (void) finishedLoadingWithDataSource:(WebDataSource *) source;
{
	NSLog(@"WebPDFDocumentRepresentation finishedLoadingWithDataSource");
	// initialize PDFDocument with [source data]
}

- (NSString *) title; { return [[[_dataSource response] URL] absoluteString]; }

@end

@implementation _WebPDFDocumentView

- (id) initWithFrame:(NSRect) rect
{
	if((self=[super initWithFrame:rect]))
		{
		}
	return self;
}

- (void) dataSourceUpdated:(WebDataSource *) source;
{
}

- (void) layout;
{
	// update contents from binary data
}

- (void) setDataSource:(WebDataSource *) source;
{
	_dataSource=source;
}

- (void) setNeedsLayout:(BOOL) flag;
{ // getImage from our rep.
	_needsLayout=flag;
}

- (void) viewDidMoveToHostWindow;
{
	// FIXME:
}

- (void) viewWillMoveToHostWindow:(NSWindow *) win;
{
	// FIXME:
}

- (void) drawRect:(NSRect) rect
{
	if(_needsLayout)
		[self layout];
	[super drawRect:rect];
}

@end
