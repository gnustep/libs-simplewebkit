//
//  WebFrame.m
//  mySTEP
//
//  Created by Dr. H. Nikolaus Schaller on Mon Jan 05 2004.
//  Revised May 2006
//  Copyright (c) 2004 DSITRI. All rights reserved.
//

#import <WebKit/WebFrame.h>
#import <WebKit/DOM.h>
#import <Foundation/NSXMLParser.h>
#import "Private.h"

@implementation WebFrame

- (id) initWithName:(NSString *) n webFrameView:(WebFrameView *) frameView webView:(WebView *) webView
{
    self=[super init];
    if(self)
		{ // If an error occurs here, send a [self release] message and return nil.
		_name=[n retain];
		_frameView=[frameView retain];
		_webView=[webView retain];
		[frameView _setDocumentView:nil];	// will be set as soon as MIME-type becomes known from data source
		[frameView _setWebFrame:self];
		_domDocument=[[RENAME(DOMDocument) alloc] _initWithName:@"#DOM" namespaceURI:nil document:nil];
		}
    return self;
}

- (void) _addChildFrame:(WebFrame *) child;
{
	if(!_children)
		_children=[[NSMutableArray alloc] initWithCapacity:5];
	[_children addObject:child];
	[child _setParentFrame:self];
}

- (void) _setParentFrame:(WebFrame *) parent;
{
	_parent=parent;	// weak pointer!
}

- (void) dealloc;
{
#if 1
	NSLog(@"dealloc %@: %@", NSStringFromClass(isa), self);
#endif
	[self stopLoading];	// cancel any pending actions (i.e. _provisionalDataSource)
	[_dataSource release];
	[_name release];
	[_frameView release];
	[_webView release];
	[_children release];
	[_request release];
	[_dataSource release];
	[_domDocument release];
	[super dealloc];
}

- (void) loadRequest:(NSURLRequest *) req;
{
#if 1
	NSLog(@"%@ loadRequest:%@", self, req);
#endif
	[_request autorelease];
	_request=[req copy];	// make a copy so that we can reload any time
	[self reload];
}

- (void) stopLoading;
{
	[_provisionalDataSource release];
	_provisionalDataSource=nil;
}

- (void) reload;
{
#if 1
	NSLog(@"reload %@", self);
	NSLog(@"_request=%@", _request);
#endif
	_provisionalDataSource=[[WebDataSource alloc] initWithRequest:_request];
	[_provisionalDataSource _setWebFrame:self];
}

// FIXME: shouldn't this be based on a Notification?

- (void) _startedLoading;
{
	[[_webView UIDelegate] webView:_webView didStartProvisionalLoadForFrame:self];
}

- (void) _receivedData:(WebDataSource *) dataSource;
{ // let our WebDataView know
	NSLog(@"WebFrame _receivedData");
	[(NSView <WebDocumentView> *)[_frameView documentView] dataSourceUpdated:dataSource];
}

- (void) _finishedLoading;
{ // callback from data source
#if 1
	NSLog(@"WebFrame finishedLoading");
#endif
	[_dataSource autorelease];	// previous - if any
	_dataSource=_provisionalDataSource;
	_provisionalDataSource=nil;
	[[_webView UIDelegate] webView:_webView didFinishLoadForFrame:self];	// set status "Done."
}

- (void) loadAlternateHTMLString:(NSString *) string baseURL:(NSURL *) url forUnreachableURL:(NSURL *) unreach;
{ // render HTML string
	_provisionalDataSource=[[_WebNSDataSource alloc] initWithData:[string dataUsingEncoding:NSUTF8StringEncoding] MIMEType:@"text/html" textEncodingName:@"utf-8" baseURL:url];
	[_provisionalDataSource _setUnreachableURL:unreach];
	[_provisionalDataSource _setWebFrame:self];	// this triggers loading for _WebNSDataSource
}

- (void) loadArchive:(WebArchive *) archive;
{
	NIMP;
}

- (void) loadData:(NSData *) data MIMEType:(NSString *) mime textEncodingName:(NSString *) encoding baseURL:(NSURL *) url;
{ // NOTE: data might be incomplete, i.e. we will be called again as soon as new data arrives
	_provisionalDataSource=[[_WebNSDataSource alloc] initWithData:data MIMEType:mime textEncodingName:encoding baseURL:url];
	[_provisionalDataSource _setWebFrame:self];	// this triggers loading
}

- (void) loadHTMLString:(NSString *) string baseURL:(NSURL *) url;
{
	[self loadData:[string dataUsingEncoding:NSUTF8StringEncoding]
		  MIMEType:@"text/html"
  textEncodingName:@"utf-8"
		   baseURL:url];
}

- (WebFrame *) findFrameNamed:(NSString *) n;
{
	if([n isEqualToString:@"_self"] || [n isEqualToString:@"_current"])
		return self;
	if([n isEqualToString:@"_parent"])
		return _parent?_parent:self;
	if([n isEqualToString:@"_top"])
		{
		WebFrame *f=self;
		while([f parentFrame])
			f=[f parentFrame];	// search top element
		return f;
		}
	if([n isEqualToString:_name])
		return self;
	// FIXME: search descendents and parents
	return nil;
}

- (WebDataSource *) dataSource; { return _dataSource; }
- (WebDataSource *) provisionalDataSource; { return _provisionalDataSource; }
- (WebFrame *) parentFrame; { return _parent; }
- (NSArray *) childFrames; { return _children; }
- (WebFrameView *) frameView; { return _frameView; }
- (WebView *) webView; { return _webView; }
- (NSString *) name; { return _name; }

- (RENAME(DOMDocument) *) DOMDocument;
{
	return _domDocument;	// root document
}

- (DOMHTMLElement *) frameElement;
{
	id rep=[_dataSource representation];
	return [rep respondsToSelector:@selector(frameElement)]?[rep frameElement]:nil;
}

@end