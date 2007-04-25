//
//  WebFrame.m
//  mySTEP
//
//  Created by Dr. H. Nikolaus Schaller on Mon Jan 05 2004.
//  Revised May 2006
//  Copyright (c) 2004 DSITRI. All rights reserved.
//

#import <Foundation/NSXMLParser.h>
#import <WebKit/WebFrame.h>
#import <WebKit/WebFrameLoadDelegate.h>
#import <WebKit/DOM.h>
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
		[frameView _setDocumentView:nil];	// will be created and set by the WebDocumentRepresentation soon as MIME-type becomes known from the data source
		[frameView _setWebFrame:self];
		_domDocument=[[RENAME(DOMDocument) alloc] _initWithName:@"#DOM" namespaceURI:nil document:nil];	// attach empty DOMDocument
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
	[[_webView frameLoadDelegate] webView:_webView willCloseFrame:self];
	[_dataSource release];
	[_name release];
	[_frameView release];
	[_webView release];
	[_children release];
	[_request release];
	[_dataSource release];
	[_frameElement release];	// within our parent's DOM tree
	[_domDocument release];
	[super dealloc];
}

- (void) loadRequest:(NSURLRequest *) req;
{
#if 1
	NSLog(@"%@ loadRequest:%@", self, req);
#endif
	// check if it is the same URL with a different Anchor (#here)
	// in that case don't load again (or load from cache?) but try to locate the anchor and scroll the view
	// i.e. scan the textStorage for a matching DOMHTMLAnchorElementAnchorName attribute
	[_request autorelease];
	_request=[req copy];	// make a copy so that we can reload it any time
	[self reload];
}

- (void) stopLoading;
{
#if 1
	NSLog(@"stop loading");
#endif
	// this should also cancel any <meta redirect> timer
	// - (void)webView:(WebView *)sender didCancelClientRedirectForFrame:(WebFrame *)frame
	[_provisionalDataSource release];
	_provisionalDataSource=nil;
	[_children makeObjectsPerformSelector:_cmd];		// recursively stop loading of all child frames!
}

- (void) reload;
{
#if 1
	NSLog(@"reload %@", self);
	NSLog(@"_request=%@", _request);
#endif
	[self stopLoading];
	_provisionalDataSource=[[WebDataSource alloc] initWithRequest:_request];
	NSAssert(_provisionalDataSource != nil, @"can't init with request");
#if 1
	NSLog(@"loading %@", _provisionalDataSource);
#endif
	[_provisionalDataSource _setWebFrame:self];	// this may trigger the whole loading execution chain
}

#if OLD
- (void) _receivedData:(WebDataSource *) dataSource;
{ // let our WebDataView know
	NSLog(@"WebFrame _receivedData");
	[(NSView <WebDocumentView> *)[_frameView documentView] dataSourceUpdated:dataSource];
}
#endif

- (void) _finishedLoading;
{ // callback from data source
#if 1
	NSLog(@"WebFrame finishedLoading from %@, replacing %@", _provisionalDataSource, _dataSource);
#endif
	NSAssert(_provisionalDataSource != nil, @"_finishedLoading occurred without _provisionalDataSource");
	[_dataSource autorelease];	// previous - if any
	_dataSource=_provisionalDataSource;	// become new owner
	_provisionalDataSource=nil;
#if 1
	NSLog(@"WebFrame _provisionalDataSource=%@", _provisionalDataSource);
#endif
	[[_webView frameLoadDelegate] webView:_webView didFinishLoadForFrame:self];	// set status "Done."
}

- (void) loadAlternateHTMLString:(NSString *) string baseURL:(NSURL *) url forUnreachableURL:(NSURL *) unreach;
{ // render HTML string
	[self loadRequest:[[_NSURLRequestNSData alloc] initWithData:[string dataUsingEncoding:NSUTF8StringEncoding] mime:@"text/html" textEncodingName:@"utf-8" baseURL:url]];
}

- (void) loadArchive:(WebArchive *) archive;
{
	NIMP;
}

- (void) loadData:(NSData *) data MIMEType:(NSString *) mime textEncodingName:(NSString *) encoding baseURL:(NSURL *) url;
{ // NOTE: data might be incomplete, i.e. we will be called again as soon as new data arrives
	[self loadRequest:[[_NSURLRequestNSData alloc] initWithData:data mime:mime textEncodingName:encoding baseURL:url]];
}

- (void) loadHTMLString:(NSString *) string baseURL:(NSURL *) url;
{
	[self loadData:[string dataUsingEncoding:NSUTF8StringEncoding]
		  MIMEType:@"text/html"
  textEncodingName:@"utf-8"
		   baseURL:url];
}

- (WebFrame *) _findFrameNamed:(NSString *) n;
{ // recursively search full tree
	NSEnumerator *e=[_children objectEnumerator];
	WebFrame *child;
	WebFrame *result;
	if([n isEqualToString:_name])
		return self;	// found
	while((child=[e nextObject]))
		{
		if((result=[child _findFrameNamed:n]))
			return result;	// found!
		}
	return nil;
}

- (WebFrame *) findFrameNamed:(NSString *) n;
{
	WebFrame *f, *r;
	if([n isEqualToString:@"_self"] || [n isEqualToString:@"_current"])
		return self;
	if([n isEqualToString:@"_parent"])
		return _parent?_parent:self;
	if([n isEqualToString:@"_top"])
		{ // find root element
		f=self;
		while((r=[f parentFrame]))
			f=r;	// search top element
		return r;
		}
	if([n isEqualToString:_name])
		return self;
	f=self;
	while(f)
		{ // search in full child tree
		if((r=[f _findFrameNamed:n]))
			return r;	// found
		f=[f parentFrame];	// try next level
		}
	// FIXME: searh other main frame hierarchies (how to find those???)
	return nil;
}

- (WebDataSource *) dataSource; { return _dataSource; }
- (WebDataSource *) provisionalDataSource; { return _provisionalDataSource; }
- (WebFrame *) parentFrame; { return _parent; }
- (NSArray *) childFrames; { return _children; }
- (WebFrameView *) frameView; { return _frameView; }
- (WebView *) webView; { return _webView; }
- (NSString *) name; { return _name; }
- (void) _setFrameName:(NSString *) n; { ASSIGN(_name, n); }
- (RENAME(DOMDocument) *) DOMDocument; { return _domDocument; }
- (DOMHTMLElement *) frameElement; { return _frameElement; }
- (void) _setFrameElement:(DOMHTMLElement *) e; { ASSIGN(_frameElement, e); }

// we are the delegate of the NSTextView that renders the <body> element and should handle click on link

- (BOOL) textView:(NSTextView *) tv clickedOnLink:(id) link atIndex:(unsigned) charIndex;
{
	if(link)
		{
		WebFrame *newFrame=nil;
		// CHECKME: shouldn't we already resolve the link when processing the DOMHTMLAnchorElement to allow text drag&drop?
		// we may have conflicting requirements: when moving the mouse over the cursor or using ToolTips, the link should NOT yet be resolved
		// FIXME: check if [[_dataSource response] URL] exists!
		NSURL *url=[[NSURL URLWithString:link relativeToURL:[[_dataSource response] URL]] absoluteURL];	// normalize
		NSString *scheme=[url scheme];
#if 1
		NSLog(@"url=%@", url);
		NSLog(@"scheme=%@", scheme);
#endif
		if([scheme isEqualToString:@"javascript"])
			{
			// FIXME: check for "javascript" scheme
			}
		else if([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"])
			{ // open ourselves in (new) window
			NSString *target=@"_self";	// default
			NSURLRequest *request=[NSURLRequest requestWithURL:url];
			// FIXME: get from ??? e.g. the DOMHTMLTargetAttribute string attributes at charIndex
			// find out if we have a DOMHTMLTargetAttribute which names the window (frame) we should reload			
#if 1
			NSLog(@"jump to link %@ for target %@", link, target);
#endif
			if([target isEqualToString:@"_blank"])
				{ // create a new window
					// there should be a context menu for a link so that we can call this manually
				WebView *newView=[[_webView UIDelegate] webView:_webView createWebViewWithRequest:request];	// should create a new window - or return nil
				if(newView)
					{
					[[_webView UIDelegate] webViewShow:newView];	// and show
					return YES;	// done
					}
				}
			else if(target)
				newFrame=[self findFrameNamed:target];	// find by name
			if(!newFrame)
				newFrame=self;
			// push current location to history
			[newFrame loadRequest:request];	// make page load (new) URL
			return YES;
			}
		else
			return [[NSWorkspace sharedWorkspace] openURL:url];	// open by default application, e.g. mailto: etc.
		}
	return NO;	// ignored
}

@end
