/* simplewebkit
   WebView.m
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
#import <WebKit/WebView.h>
#import <WebKit/WebFrame.h>
#import <WebKit/WebBackForwardList.h>

// default document representations we understand
#import "WebHTMLDocumentRepresentation.h"
#import "WebHTMLDocumentView.h"
#import "WebImageDocumentRepresentation.h"
#import "WebPDFDocumentRepresentation.h"
#import "WebXMLDocumentRepresentation.h"

@implementation WebView

static NSMutableDictionary *_viewClasses;
static NSMutableDictionary *_representationClasses;
static NSArray *_htmlMimeTypes;

+ (BOOL) canShowMIMEType:(NSString *) MIMEType;
{
	return [self _viewClassForMIMEType:MIMEType] != Nil;
}

+ (BOOL) canShowMIMETypeAsHTML:(NSString *) MIMEType
{
	return [_htmlMimeTypes containsObject:MIMEType];	// FIXME: case insensitive???
}

+ (void) initialize;
{
#if 0
	NSLog(@"WebView +initialize");
#endif
	[self setMIMETypesShownAsHTML:[NSArray arrayWithObjects:@"text/html", nil]];
	[self registerViewClass:[_WebHTMLDocumentView class]
		representationClass:[_WebHTMLDocumentRepresentation class]
				forMIMEType:@"text/html"];	// we are ourselves the default for HTML
	[self registerViewClass:[NSImageView class]
		representationClass:[_WebImageDocumentRepresentation class]
				forMIMEType:@"image/"];		// match all images
	[self registerViewClass:self	// [_WebPDFDocumentView class] - subclass of NSPDFView
		representationClass:[_WebPDFDocumentRepresentation class]
				forMIMEType:@"text/pdf"];
	[self registerViewClass:self	// [_WebXMLDocumentView class]
		representationClass:[_WebXMLDocumentRepresentation class]
				forMIMEType:@"text/xml"];
}

+ (NSArray *) MIMETypesShownAsHTML; { return _htmlMimeTypes; }

+ (void) registerViewClass:(Class) class representationClass:(Class) repClass forMIMEType:(NSString *) type;
{
#if 0
	NSLog(@"registerViewClass:%@ representationClass:%@ forMIMEType:%@", NSStringFromClass(class), NSStringFromClass(repClass), type);
#endif
	if(!_viewClasses)
		{ // allocate container(s)
		_viewClasses=[[NSMutableDictionary alloc] initWithCapacity:5];
		_representationClasses=[[NSMutableDictionary alloc] initWithCapacity:5];
		}
	if(class != Nil && repClass != Nil)
		{
		[_viewClasses setObject:class forKey:type];
		[_representationClasses setObject:repClass forKey:type];
		}
	else
		{
		[_viewClasses removeObjectForKey:type];
		[_representationClasses removeObjectForKey:type];
		}
}

+ (void) setMIMETypesShownAsHTML:(NSArray *) types;
{
	ASSIGN(_htmlMimeTypes, types);
}

+ (Class) _representationClassForMIMEType:(NSString *) type;
{ // find representation class
	Class cls;
	NSArray *c;
	c=[type componentsSeparatedByString:@";"];
	type=[c objectAtIndex:0];	// ignore ; parameters
	if([self canShowMIMETypeAsHTML:type])
		type=@"text/html";
	if((cls=[_representationClasses objectForKey:type]))
		return cls;	// appears to match
	c=[type componentsSeparatedByString:@"/"];
	type=[[c objectAtIndex:0] stringByAppendingString:@"/"];	// get major type component only and append /
	cls=[_representationClasses objectForKey:type];
	return cls;
}

+ (Class) _viewClassForMIMEType:(NSString *) type;
{ // find view class
	Class cls;
	NSArray *c=[type componentsSeparatedByString:@";"];
	type=[c objectAtIndex:0];	// ignore ; parameters
	if([self canShowMIMETypeAsHTML:type])
		type=@"text/html";
	if((cls=[_viewClasses objectForKey:type]))
		return cls;	// appears to match full type
	c=[type componentsSeparatedByString:@"/"];
	type=[[c objectAtIndex:0] stringByAppendingString:@"/"];	// get major type component only and append /
	cls=[_viewClasses objectForKey:type];	// check for wildcard match
	return cls;
}

- (id) initWithFrame:(NSRect) rect;
{
	return [self initWithFrame:rect frameName:nil groupName:nil];
}

- (id) initWithFrame:(NSRect) rect frameName:(NSString *) name groupName:(NSString *) group;
{
#if 0
	NSLog(@"mySTEP: WebView initWithFrame:%@", NSStringFromRect(rect));
#endif
	if((self=[super initWithFrame:rect]))
		{
		WebFrameView *frameView=[[WebFrameView alloc] initWithFrame:(NSRect){ NSZeroPoint, rect.size}];	// view for the main frame
		_mainFrame=[[WebFrame alloc] initWithName:name webFrameView:frameView webView:self];	// assign a WebFrame
		[self addSubview:frameView];		// make it our subview with same size
		[frameView setAutoresizingMask:(NSViewWidthSizable|NSViewHeightSizable)];	// autoresize main Frame with WebView
		[frameView setAllowsScrolling:YES];	// main view can always scroll (if needed)
		[frameView release];
		_groupName=[group retain];
		_drawsBackground=YES;
		}
	return self;
}

#if 0
- (void) awakeFromNib
{
	NSLog(@"mySTEP: WebView awakeFromNib");
}
#endif

- (void) dealloc;
{
	[_mainFrame release];
	[_groupName release];
	[_backForwardList release];
	[_customAgent release];
	[_customTextEncoding release];
	[_applicationName release];
	[super dealloc];
}

- (WebFrame *) mainFrame;   { return _mainFrame; }
- (id) UIDelegate; { return _uiDelegate; }
- (void) setUIDelegate:(id) uid; { _uiDelegate=uid; }
- (NSString *) groupName; { return _groupName; }
- (void) setGroupName:(NSString *) str; { ASSIGN(_groupName, str); }

- (WebBackForwardList *) backForwardList; { return _backForwardList; }

- (void) setMaintainsBackForwardList:(BOOL) flag;
{
	if(flag && !_backForwardList)
		_backForwardList=[[WebBackForwardList alloc] init];
	else if(!flag && _backForwardList)
		[_backForwardList release], _backForwardList=nil;
}

- (NSString *) applicationNameForUserAgent; { return _applicationName; }
- (void) setApplicationNameForUserAgent:(NSString *) name; { _applicationName=[name retain]; }
- (NSString *) customUserAgent; { return _customAgent; }
- (void) setCustomUserAgent:(NSString *) agent; { _customAgent=[agent retain]; }
- (NSString *) customTextEncodingName; { return _customTextEncoding; }
- (void) setCustomTextEncodingName:(NSString *) name; { _customTextEncoding=[name retain]; }

	// FIXME

- (BOOL) canGoBack; { return NO; }
- (BOOL) canGoForward; { return NO; }

- (IBAction) takeStringURLFrom:(id) sender;
{
	// add http:// prefix if there is none yet
	NSURL *u=[NSURL URLWithString:[sender stringValue]];
#if 0
	NSLog(@"takeStringURL %@", u);
#endif
	[_mainFrame loadRequest:[NSURLRequest requestWithURL:u]];
}

- (double) estimatedProgress;
{
// FIXME
	return 0.0;
}

- (IBAction) reload:(id) sender;
{
	[_mainFrame reload];
}

- (IBAction) stopLoading:(id) sender;
{
	[_mainFrame stopLoading];
}

- (NSString *) stringByEvaluatingJavaScriptFromString:(NSString *) script;
{
	return @"JavaScript not implemented";
}

- (IBAction) goBack:(id) sender; { NIMP; }
- (IBAction) goForward:(id) sender; { NIMP; }
- (IBAction) makeTextLarger:(id) sender; { NIMP; }
- (IBAction) makeTextSmaller:(id) sender; { NIMP; }

- (void) drawRect:(NSRect) rect;
{
	if(_drawsBackground)
		{
#if 1
		[[NSColor redColor] set];
#else
		[[NSColor whiteColor] set];
#endif
		NSRectFill(rect);
		}
	[@"WebView" drawAtPoint:NSMakePoint(10,10) withAttributes:nil];
}

- (BOOL) validateMenuItem:(id <NSMenuItem>) menuItem
{
	NSString *sel=NSStringFromSelector([menuItem action]);
	if([sel isEqualToString:@"goBack:"]) return [self canGoBack];
	if([sel isEqualToString:@"goForward:"]) return [self canGoForward];
	return YES;
}

// private methods!

- (BOOL) drawsBackground;
{
	return _drawsBackground;
}

- (void) setDrawsBackground:(BOOL) flag;
{
	_drawsBackground=flag;
}

/* callbacks we should generate for UIdelegate!

- (WebView *) webView:(WebView *)sender createWebViewWithRequest:(NSURLRequest *)request

	[_uiDelegate webViewShow:self];

[_uiDelegate webView:self didCommitLoadForFrame:(WebFrame *)frame];	// set status "Loading..."
[_uiDelegate webView:self didStartProvisionalLoadForFrame:(WebFrame *)frame];	// set status "Loading URL"
[_uiDelegate webView:self didReceiveTitle:(NSString *)title forFrame:(WebFrame *)frame];	// update title
[_uiDelegate webView:self didFinishLoadForFrame:(WebFrame *)frame];	// set status "Done."

*/

@end
