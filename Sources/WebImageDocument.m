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
	[_doc _setVisualRepresentation:nil];
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
	[frameView _setDocumentView:view];	// this should retain
	_doc=[frame DOMDocument];	// non-retained reference
	[_doc _setVisualRepresentation:view];	// make the view receive change notifications
	[view release];
	[super setDataSource:dataSource];
}

- (void) finishedLoadingWithDataSource:(WebDataSource *) source;
{
	WebFrame *webFrame=[source webFrame];
	WebView *webView=[webFrame webView];
	NSString *title;
#if 0
	NSLog(@"WebImageDocumentRepresentation finishedLoadingWithDataSource");
#endif
	[_image release];
	_image=[[NSImage alloc] initWithData:[source data]];
	[[_doc _visualRepresentation] setNeedsLayout:YES];
	[[source webFrame] _finishedLoading];	// notify
	title=[self title];
#if 0
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
		[self setAutoresizingMask:(NSViewWidthSizable|NSViewHeightSizable)];
#if defined(__mySTEP__) || MAC_OS_X_VERSION_10_2 < MAC_OS_X_VERSION_MAX_ALLOWED
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
	NSImage *image=[(_WebImageDocumentRepresentation *) [_dataSource representation] getImage];
#if 0
	NSLog(@"WebImageView layout img=%@", image);
#endif
	[self setImage:image];
	//	[self setFrame:(NSRect){ NSZeroPoint, [image size] }];	// resize to fit
}

- (void) setDataSource:(WebDataSource *) source;
{
	_dataSource=source;
}

- (void) setNeedsLayout:(BOOL) flag;
{
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
