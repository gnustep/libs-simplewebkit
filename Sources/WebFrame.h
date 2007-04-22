//
//  WebFrame.h
//  mySTEP
//
//  Created by Dr. H. Nikolaus Schaller on Mon Jan 05 2004.
//  Revised May 2006
//  Copyright (c) 2004 DSITRI. All rights reserved.
//

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
