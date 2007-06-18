/* simplewebkit
   WebImageDocumentRepresentation.m

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

#import "WebImageDocument.h"
#import "Private.h"

@implementation _WebImageDocumentRepresentation

- (void) dealloc;
{
	[_image release];
	[super dealloc];
}

// methods from WebDocumentRepresentation protocol

- (void) setDataSource:(WebDataSource *) dataSource;
{
	Class viewclass;
	WebFrame *frame=[dataSource webFrame];
	WebFrameView *frameView=[frame frameView];
	NSView <WebDocumentView> *view;
	// well, we should know what it is...
	viewclass=[WebView _viewClassForMIMEType:[[dataSource response] MIMEType]];
	view=[[viewclass alloc] initWithFrame:[frameView frame]];
	[view setDataSource:dataSource];
	[frameView _setDocumentView:view];
	[[frame DOMDocument] _setVisualRepresentation:view];	// make the view receive change notifications
	[view release];
	[super setDataSource:dataSource];
}

- (void) finishedLoadingWithDataSource:(WebDataSource *) source;
{
		WebFrame *webFrame=[source webFrame];
		WebView *webView=[webFrame webView];
		NSString *title;
#if 1
	NSLog(@"WebImageDocumentRepresentation finishedLoadingWithDataSource");
#endif
	[_image release];
	_image=[[NSImage alloc] initWithData:[source data]];
	[[[[source webFrame] DOMDocument] _visualRepresentation] setNeedsLayout:YES];
	title=[self title];
#if 1
	NSLog(@"notify delegate for title: %@", title, [webView frameLoadDelegate]);
#endif
	[[webView frameLoadDelegate] webView:webView didReceiveTitle:title forFrame:webFrame];	// update title
	[(NSView <WebDocumentView> *)[[[source webFrame] frameView] documentView] dataSourceUpdated:source];	// notify frame view
}

- (void) receivedData:(NSData *) data withDataSource:(WebDataSource *) source;
{
#if 0
	NSLog(@"WebImageDocumentRepresentation receivedData");
#endif
#if 0	// handle partial image data
	[_image release];
	_image=[[NSImage alloc] initWithData:[source data]]; // try to load again
	//	[[[[source webFrame] DOMDocument] _visualRepresentation] setNeedsLayout:YES];
#endif
}

- (NSString *) title;
{
	if(_image)
		{ // has been loaded
		NSString *file=[[[[_dataSource response] URL] path] lastPathComponent];
		NSSize size=[_image size];
		return [NSString stringWithFormat:@"%@ %ux%u Pixel", file, (unsigned) size.width, (unsigned) size.height];
		}
	return nil;	// no title yet
}

- (NSImage *) getImage; { return _image; }

@end

@implementation _WebImageDocumentView

- (id) initWithFrame:(NSRect) rect
{
	if((self=[super initWithFrame:rect]))
		{
#ifndef GNUSTEP
		[self setAllowsCutCopyPaste:YES];
		[self setAnimates:YES];
#endif
		[self setEditable:NO];
		[self setImageAlignment:NSImageAlignTopLeft];
		[self setImageFrameStyle:NSImageFrameNone];
		[self setImageScaling:NSScaleNone];
		}
	return self;
}

- (void) dataSourceUpdated:(WebDataSource *) source;
{
}

- (void) layout;
{
}

- (void) setDataSource:(WebDataSource *) source;
{
		_dataSource=source;
}

- (void) setNeedsLayout:(BOOL) flag;
{ // getImage from our rep.
	// we could/should postpone until we really drawRect
	NSImage *image=[(_WebImageDocumentRepresentation *) [_dataSource representation] getImage];
	NSLog(@"img=%@", image);
	[self setImage:image];
//	[self setFrame:(NSRect){ NSZeroPoint, [image size] }];	// resize to fit
}

- (void) viewDidMoveToHostWindow;
{
}

- (void) viewWillMoveToHostWindow:(NSWindow *) win;
{
}

@end
