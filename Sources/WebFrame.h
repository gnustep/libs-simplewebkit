/* simplewebkit
   WebFrame.h

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

#import <Cocoa/Cocoa.h>
#import <Foundation/NSURLRequest.h>
#import <WebKit/WebDataSource.h>
#import <WebKit/WebDOMOperations.h>

@class WebFrameView;
@class WebView;

@class WebArchive;		// not yet implemented

@interface WebFrame : NSObject
{
	WebDataSource *_dataSource;
	WebDataSource *_provisionalDataSource;
	NSString *_name;			// our name
	WebFrameView *_frameView;	// our frame view
	RENAME(DOMDocument) *_domDocument;
	DOMHTMLElement *_frameElement;
	WebView *_webView;			// our web view
	WebFrame *_parent;
	NSMutableArray *_children;	// loading will create children
	NSURLRequest *_request;
	NSTimer *_reloadTimer;		// redirection timer
}

- (NSArray *) childFrames;
- (WebDataSource *) dataSource;
- (RENAME(DOMDocument) *) DOMDocument;
- (WebFrame *) findFrameNamed:(NSString *) name;
- (DOMHTMLElement *) frameElement;
- (WebFrameView *) frameView;
- (id) initWithName:(NSString *) frameName
	   webFrameView:(WebFrameView *) frameView
			webView:(WebView *) webView;
- (void) loadAlternateHTMLString:(NSString *) string baseURL:(NSURL *) url forUnreachableURL:(NSURL *) unreach;
- (void) loadArchive:(WebArchive *) archive;
- (void) loadData:(NSData *) data MIMEType:(NSString *) mime textEncodingName:(NSString *) encoding baseURL:(NSURL *) url;
- (void) loadHTMLString:(NSString *) string baseURL:(NSURL *) url;
- (void) loadRequest:(NSURLRequest *) request;
- (NSString *) name;
- (WebFrame *) parentFrame;
- (WebDataSource *) provisionalDataSource;
- (void) reload;
- (void) stopLoading;
- (WebView *) webView;

@end
