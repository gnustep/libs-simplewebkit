/* simplewebkit
   WebFrame.m

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

#import <Foundation/NSXMLParser.h>
#import <WebKit/WebFrame.h>
#import <WebKit/WebFrameLoadDelegate.h>
#import <WebKit/WebView.h>
#import <WebKit/WebBackForwardList.h>
#import <WebKit/WebHistory.h>
#import <WebKit/DOM.h>
#import "Private.h"

static NSMutableArray *_pageCache;	// global page cache - retains WebDataSource objects even if not in view hierarchy

@implementation WebFrame

- (id) initWithName:(NSString *) n webFrameView:(WebFrameView *) frameView webView:(WebView *) webView
{
   if((self=[super init]))
		{ // If an error occurs here, send a [self release] message and return nil.
		_name=[n retain];
		_frameView=[frameView retain];
		_webView=[webView retain];
		[frameView _setWebFrame:self];
		_domDocument=[[RENAME(DOMDocument) alloc] _initWithName:@"#DOM" namespaceURI:nil];	// attach empty DOMDocument
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

- (void) _orphanize;
{
	_parent=nil;	// weak pointer!
}

- (void) dealloc;
{
#if 0
	NSLog(@"dealloc %@: %@", NSStringFromClass(isa), self);
#endif
	[self stopLoading];	// cancel any pending actions (i.e. _provisionalDataSource)
	[[_webView frameLoadDelegate] webView:_webView willCloseFrame:self];
	[_dataSource release];
	[_name release];
	[_frameView release];
	[_webView release];
	[_children makeObjectsPerformSelector:@selector(_orphanize)];
	[_children release];
	[_request release];
	[_dataSource release];
	[_frameElement release];	// within our parent's DOM tree
	[_domDocument release];
	[super dealloc];
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
	// this may trigger the whole loading execution chain; but from the RunLoop - which may even issue a new call to -reload!
	[_provisionalDataSource performSelector:@selector(_setWebFrame:) withObject:self afterDelay:0.0];
}

- (void) _addToHistory;
{
	int cache=[[_webView backForwardList] pageCacheSize];
	// FIXME: handle private surfing mode
	WebHistoryItem *item=[[WebHistoryItem alloc] initWithURLString:[[[_dataSource response] URL] absoluteString]
															 title:[[_dataSource representation] title]
										   lastVisitedTimeInterval:[NSDate timeIntervalSinceReferenceDate]];
	[[WebHistory optionalSharedHistory] addItems:[NSArray arrayWithObject:item]];
	if(![[[_webView backForwardList] currentItem] isEqual:item])
		[[_webView backForwardList] addItem:item];	// add unless it is the same as the current (i.e. after a reload)
	[item release];
	if(cache > 0)
		{
		if(!_pageCache)
			_pageCache=[NSMutableArray new];
		[_pageCache insertObject:self atIndex:0];
		}
	while([_pageCache count] > cache)
		{ // remove at end (oldest)
		[_pageCache removeLastObject];
		}
}

- (void) loadRequest:(NSURLRequest *) req;
{
	NSEnumerator *e=[_pageCache objectEnumerator];
	WebFrame *cached;
	NSAssert(req != nil, @"trying to load nil request");
#if 1
	NSLog(@"%@ loadRequest:%@", self, req);
#endif
	[_request autorelease];
	_request=[req copy];	// make a copy so that we can reload it any time
	while((cached=[e nextObject]))
		{
		// FIXME: ignore anchor!
		if([[[[cached dataSource] request] URL] isEqual:[req URL]])
			{ // found
#if 1
			NSLog(@"page found in cache: %@", cached);
#endif
#if 0
			// [_webView _setWebFrame:cached]
			// [_webFrameView removeFromSuperview];
			// [_webView _addSubview:[cached webFrameView]]
			// replace our webView's webFrame and webFrameView
			// locate the anchor and scroll the view
			// i.e. scan the textStorage for a matching DOMHTMLAnchorElementAnchorName attribute
			return;
#endif
			}
		}
	[self reload];
}

- (void) _loadRequestFromRedirectTimer:(NSTimer *) timer;
{
	NSURLRequest *request=[NSURLRequest requestWithURL:[timer userInfo]];
#if 0
	NSLog(@"do redirect");
#endif
	[timer invalidate];	// so that the loadRequest does not again...
	_reloadTimer=nil;
	[self loadRequest:request];
}

- (void) _performClientRedirectToURL:(NSURL *) URL delay:(NSTimeInterval) seconds;
{
	if(_reloadTimer && [_reloadTimer isValid])
		{
#if 0
		NSLog(@"cancel redirect");
#endif
		[_reloadTimer invalidate];	// cancel the meta redirect timer
		_reloadTimer=nil;
		[[_webView frameLoadDelegate] webView:_webView didCancelClientRedirectForFrame:self];
		}
	if(URL)
		{ // create a new one
		_reloadTimer=[NSTimer scheduledTimerWithTimeInterval:seconds target:self selector:@selector(_loadRequestFromRedirectTimer:) userInfo:URL repeats:NO];
		[[_webView frameLoadDelegate] webView:_webView willPerformClientRedirectToURL:URL delay:seconds fireDate:[_reloadTimer fireDate] forFrame:self];
		}
}

- (void) stopLoading;
{
#if 0
	NSLog(@"stop loading");
#endif
	[self _performClientRedirectToURL:nil delay:0.0];	// cancel any redirection timer
	// does this explicitly stop the data source from loading?
	[_provisionalDataSource release];
	_provisionalDataSource=nil;
	[_children makeObjectsPerformSelector:_cmd];		// recursively stop loading of all child frames!
}

- (void) _failedWithError:(NSError *) error;
{ // callback from data source
	if(_provisionalDataSource)
		[[_webView frameLoadDelegate] webView:_webView didFailProvisionalLoadWithError:error forFrame:self];
	else
		[[_webView frameLoadDelegate] webView:_webView didFailLoadWithError:error forFrame:self];
}

- (void) _didStartLoad;
{ // callback from _load
	[[_webView frameLoadDelegate] webView:_webView didStartProvisionalLoadForFrame:self];
}

- (void) _didReceiveData;
{ // callback from data source, i.e. all the server side redirects are done
	if(_provisionalDataSource)
		{ // first call changes to committed state
#if 0
		NSLog(@"WebFrame _didReceiveData from %@, replacing %@", _provisionalDataSource, _dataSource);
#endif
		NSAssert(_provisionalDataSource != nil, @"_didReceiveData occurred without _provisionalDataSource");
#if 0
		NSLog(@"WebFrame _provisionalDataSource=%@", _provisionalDataSource);
#endif
		[_dataSource autorelease];	// previous - if any
		_dataSource=_provisionalDataSource;	// become new owner
		_provisionalDataSource=nil;
		[[_webView frameLoadDelegate] webView:_webView didCommitLoadForFrame:self];
		// here, we receive data and should display new data
		}
}

- (void) _finishedLoading;
{ // callback from data source
	[self _didReceiveData];	// if we did receive 0 bytes...
	[self _addToHistory];
	[[_webView frameLoadDelegate] webView:_webView didFinishLoadForFrame:self];	// set status "Done."
}

- (void) loadAlternateHTMLString:(NSString *) string baseURL:(NSURL *) url forUnreachableURL:(NSURL *) unreach;
{ // render HTML string
	// should suppress finishedLoading etc.
	// or can we simply use setHTML for the DOM root? - no this requires a HTML parser for individual DOM nodes
	[self loadRequest:[[[_NSURLRequestNSData alloc] initWithData:[string dataUsingEncoding:NSUTF8StringEncoding] mime:@"text/html" textEncodingName:@"utf-8" baseURL:url] autorelease]];
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
	// FIXME: API doc says: search 'other main frame hierarchies' (how to find those? ask [_webView mainFrame]?)
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
	// if [NSApp currentEvent] has control Key pressed, pop up specific context menu that allows to follow the link in current or new window, to save the page or link contents, to copy&paste etc.
	
	if(link)
		{
		WebFrame *newFrame=nil;
		// CHECKME: shouldn't we already resolve the link when processing the DOMHTMLAnchorElement to allow text drag&drop?
		// we may have conflicting requirements: when moving the mouse over the cursor or using ToolTips, the link should NOT yet be resolved
		// FIXME: check if [[_dataSource response] URL] exists!
		NSURL *url=[[NSURL URLWithString:link relativeToURL:[[_dataSource response] URL]] absoluteURL];	// normalize
		NSString *scheme=[url scheme];
#if 0
		NSLog(@"url=%@", url);
		NSLog(@"scheme=%@", scheme);
#endif
		if([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"])
			{ // open in (new) window
			NSString *target=[[tv textStorage] attribute:DOMHTMLAnchorElementTargetWindow atIndex:charIndex effectiveRange:NULL];
			NSURLRequest *request=[NSURLRequest requestWithURL:url];
#if 1
			NSLog(@"jump to link %@ for target %@", link, target);
#endif
			if(target && ([target isEqualToString:@"_blank"] || !(newFrame=[self findFrameNamed:target])))
				{ // if not found or explicitly wanted or not found by name, create a new window
				WebView *newView=[[_webView UIDelegate] webView:_webView createWebViewWithRequest:request];	// should create a new view window loading the request - or return nil
				if(newView)
					{
					if(![target hasPrefix:@"_"])
						[[newView mainFrame] _setFrameName:target];
					[[_webView UIDelegate] webViewShow:newView];	// and show
					return YES;	// done
					}
				}
				if(!newFrame)
					newFrame=self;	// show in current window - if no target given or named frame not found, but no new window created (because delegate did not create new view window)
			// an intra-page anchor should just scroll and call [[webView frameLoadDelegate] webView:webView didChangeLocationWithinPageForFrame:self];
			[newFrame loadRequest:request];	// make page load (new) URL
			return YES;
			}
		else
			return [[NSWorkspace sharedWorkspace] openURL:url];	// open by default application, e.g. mailto: etc.
		}
	return NO;	// ignored
}

@end
