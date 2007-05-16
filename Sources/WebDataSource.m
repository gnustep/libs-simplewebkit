/* simplewebkit
   WebDataSource.m

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

#import "Private.h"
#import <WebKit/WebDataSource.h>
#import <WebKit/WebResource.h>
#import <WebKit/WebFrameLoadDelegate.h>

#define ROBUSTNESS_TEST 0

@implementation WebDataSource

#if NO_USED

- (id) _initWithWebResource:(WebResource *) resource;
{ // could be an alternative to using _NSURLRequestNSData
	// make a resource with NSData://uuid, data, encoding etc.
	if((self = [super init]))
		{ // If an error occurs here, send a [self release] message and return nil.
		NSURL *url=[resource URL];
		_loadedData=[[resource data] retain];
		_initial=[NSURLRequest requestWithURL:url];
		_request=[_initial mutableCopy];
		_response=[[NSURLResponse alloc] initWithURL:url MIMEType:[resource MIMEType] expectedContentLength:[_loadedData length] textEncodingName:[resource textEncodingName]];
		}
	return self;
}
#endif

- (id) initWithRequest:(NSURLRequest *) request;
{
#if 0
	NSLog(@"WebDataSource initWithRequest %@", request);
#endif
	NSAssert(request != nil, @"trying to init for nil request");
    if((self = [super init]))
		{ // If an error occurs here, send a [self release] message and return nil.
		_initial=[request copy];
		_request=[_initial mutableCopy];
#if 1
		NSLog(@"WebDataSource load URL %@", [[_initial URL] absoluteString]);
#endif
		}
    return self;
}

- (void) dealloc;
{
#if 1
	NSLog(@"dealloc %@", self);
#endif
	[_connection cancel];	// cancel any pending actions 
	[_connection release];
	[_ident release];
	[_initial release];
	[_request release];
	[_response release];
	[_loadedData release];
	[_subresources release];
	[_subdatasources release];
	[_unreachableURL release];
	[(NSObject *) _representation release];
	[super dealloc];
}

- (NSString *) description; { return [NSString stringWithFormat:@"%@: %@ -> %@", [super description], _request, _response]; }

- (void) _cancel;
{
	[[_subdatasources allValues] makeObjectsPerformSelector:_cmd];	// cancel all still loading subresources
	[_subdatasources removeAllObjects];	// no longer loading
	[_connection cancel];
	[_connection release];
	_connection=nil;
}

- (BOOL) isLoading; { return _connection != nil; }

- (void) addSubresource:(WebResource *) res;
{
	NSAssert(res != nil, @"trying to add nil web resource");
	if(!_subresources)
		_subresources=[[NSMutableDictionary alloc] initWithCapacity:20];
	[_subresources setObject:res forKey:[res URL]];
}

- (NSData *) data; { return _loadedData; }

- (NSURLRequest *) initialRequest; { return _initial; }

- (void) _setParentDataSource:(WebDataSource *) parent;
{
	_parent=parent;
}

- (BOOL) _isSubresource; { return _parent != nil; }

- (WebDataSource *) _subresourceWithURL:(NSURL *) url delegate:(id <WebDocumentRepresentation>) rep;	// triggers loading if not (yet) available and optionally stalls main data source
{ // creates a subresource loader
	WebDataSource *subsource;
#if 1
	NSLog(@"url=%@", url);
	NSLog(@"_subresources[url]=%@", [_subresources objectForKey:url]);
#endif
	NSAssert(url != nil, @"trying to load nil subresource");
	NSAssert([_subresources objectForKey:url] == nil, @"already loaded!");
	subsource=[_subdatasources objectForKey:url];
#if 1
		NSLog(@"load subresource from %@", url);
		NSLog(@"_subdatasources=%@", _subdatasources);
		NSLog(@"subsource=%@", subsource);
#endif
	if(!subsource)
		{ // not yet known
#if 1
		NSLog(@"start new load");
#endif
		subsource=[[[isa alloc] initWithRequest:[NSURLRequest requestWithURL:url]] autorelease];	// make new request
		[subsource _setParentDataSource:self];
		if(!rep)
			rep=[[_WebDocumentRepresentation new] autorelease];
		[subsource _setRepresentation:rep];	// someone must handle...
		if(!_subdatasources)
			_subdatasources=[[NSMutableDictionary alloc] initWithCapacity:10];
		[_subdatasources setObject:subsource forKey:url];	// add to list of resources currently loading
		[subsource _setWebFrame:_webFrame];	// hm... finally this will set the frameName
		}
#if 1
		NSLog(@"started new load");
#endif
	return subsource;
}

- (void) _commitSubresource:(WebDataSource *) source;
{ // we are the parent and our subresource is done
	[[source representation] finishedLoadingWithDataSource:source];		// last chance for postprocessing
	[self addSubresource:[source mainResource]];	// save as WebResource
	[source retain];	// keep us for some more time
	[_subdatasources removeObjectForKey:[[source request] URL]];	// is no longer loading
#if 1
	NSLog(@"subresource committed (%d loaded, %d loading): %@", [_subresources count], [_subdatasources count], source);
#endif
	if(_finishedLoading && [_subdatasources count] == 0)
		{ // notification was postponed until subresources have been loaded
		_finishedLoading=NO;	// has been processed
		[_representation finishedLoadingWithDataSource:self];	// finally send postponed notification after all subresources are loaded (is allowed to trigger load of additional subresources)
		}
	[source release];	// may be our final release&dealloc
}

- (WebResource *) mainResource;
{
	return [[[WebResource alloc] initWithData:_loadedData
										  URL:[_response URL]
									 MIMEType:[_response MIMEType]
							 textEncodingName:[self textEncodingName]
									frameName:[_webFrame name]] autorelease];
}

- (NSString *) pageTitle; { return [_representation title]; }
	
- (id <WebDocumentRepresentation>) representation; { return _representation; }

- (void) _setRepresentation:(id <WebDocumentRepresentation>) rep;
{
	_representation=[(NSObject *) rep retain];
	[_representation setDataSource:self];		// we are the data source
}

- (NSMutableURLRequest *) request; { return _request; }

- (NSURLResponse *) response; { return _response; }

- (NSArray *) subresources; { return _subresources?[_subresources allValues]:[NSArray array]; }

- (WebResource *) subresourceForURL:(NSURL *) url;
{
	// should this trigger loading?
	return [_subresources objectForKey:url];
}

- (NSString *) textEncodingName;
{
	NSString *encoding=[[_webFrame webView] customTextEncodingName]; // get from WebView (if set)
	if(!encoding)
		encoding=[_response textEncodingName];
	if(!encoding)
		encoding=@"utf-8";	// default
	return encoding;
}

- (NSStringEncoding) _stringEncoding;
{
	[self textEncodingName];
	// convert text to string encoding constant
	return NSUTF8StringEncoding;	// default
}

- (NSURL *) unreachableURL; { return _unreachableURL; }
- (void) _setUnreachableURL:(NSURL *) url; { ASSIGN(_unreachableURL, url); }

- (WebArchive *) webArchive;
{
	// parse data or _webFrame into webArchive
	return NIMP;
}

- (WebFrame *) webFrame;
{
	return _webFrame;
}

- (void) _load;
{
	WebView *webView=[_webFrame webView];
	if([_request isKindOfClass:[_NSURLRequestNSData class]])
		{
		_connection=[NSObject new];	// dummy connection object
		_ident=[[[webView resourceLoadDelegate] webView:webView identifierForInitialRequest:_request fromDataSource:_parent?_parent:self] retain];
		if(!_parent)
			[[webView frameLoadDelegate] webView:webView didStartProvisionalLoadForFrame:_webFrame];
		[self connection:_connection didReceiveResponse:[(_NSURLRequestNSData *) _request response]];	// simulate callbacks from NSURLConnection
		[self connection:_connection didReceiveData:[(_NSURLRequestNSData *) _request data]];
		[self connectionDidFinishLoading:_connection];	// notify
		[_connection release];
		_connection=nil;
		}
	else
		{
		_connection=[[NSURLConnection connectionWithRequest:_request delegate:self] retain];
#if 1
		NSLog(@"connection = %@", _connection);
		NSLog(@"currentMode = %@", [[NSRunLoop currentRunLoop] currentMode]);
#endif
		_ident=[[[webView resourceLoadDelegate] webView:webView identifierForInitialRequest:_request fromDataSource:_parent?_parent:self] retain];
		if(!_parent)
			[[webView frameLoadDelegate] webView:webView didStartProvisionalLoadForFrame:_webFrame];
		}
}

- (void) _setWebFrame:(WebFrame *) wf;
{ // this triggers loading
	_webFrame=wf;
	[self _load];
}

// delegate callbacks during data reception - pass to representation or webview delegates

- (void) connection:(NSURLConnection *) connection didFailWithError:(NSError *) error;
{
	WebView *webView=[_webFrame webView];
#if 1
	NSLog(@"WebDataSource error: %@", error);
#endif
	[_representation receivedError:error withDataSource:self];
	[[webView resourceLoadDelegate] webView:webView resource:_ident didFailLoadingWithError:error fromDataSource:_parent?_parent:self];
	[_parent _commitSubresource:self];
	[_connection release];
	_connection=nil;
}

- (NSURLRequest *) connection:(NSURLConnection *) connection willSendRequest:(NSURLRequest *) request redirectResponse:(NSURLResponse *) redirectResponse;
{ // we received a HTTP redirect (not a HTML <meta http-equiv="Refresh" content="4;url=http://www.domain.com/link.html">)	
	WebView *webView=[_webFrame webView];
#if 1
	NSLog(@"willSendRequest: %@", request);
#endif
	request=[[webView resourceLoadDelegate] webView:webView
																				 resource:_ident
																	willSendRequest:request
																 redirectResponse:redirectResponse
																	 fromDataSource:_parent?_parent:self];
	[_request release];
	_request=[request mutableCopy];	// update to new current request
	return _request;
}

- (void) connection:(NSURLConnection *) connection didReceiveResponse:(NSURLResponse *) response;
{ // we have received the header - set up the WebRepresentation object determined by the MIME type
	WebView *webView=[_webFrame webView];
	long long len=[response expectedContentLength];
	Class repclass;
	_response=[response retain];
#if 1
	NSLog(@"response received: %@", response);
	if([response respondsToSelector:@selector(allHeaderFields)])
		NSLog(@"status code: %d all headers: %@", [(NSHTTPURLResponse *) response statusCode], [(NSHTTPURLResponse *) response allHeaderFields]);
	NSLog(@"mimeType: %@", [response MIMEType]);
	NSLog(@"expectedContentLength: %lld", [response expectedContentLength]);
	NSLog(@"suggestedFilename: %@", [response suggestedFilename]);
	NSLog(@"textEncodingName: %@", [response textEncodingName]);
#endif
	[[webView resourceLoadDelegate] webView:webView resource:_ident didReceiveResponse:response fromDataSource:_parent?_parent:self];
	if(!_loadedData && len >= 0 && len < 2000000)
		_loadedData=[[NSMutableData alloc] initWithCapacity:len];	// preallocate up to 2 MByte
	if(_representation)
		return;	// we already have one - don't allocate a representation
	repclass=[WebView _representationClassForMIMEType:[response MIMEType]];
	if(repclass == Nil)
		{ // don't know what to do now...		
#if 1
		NSLog(@"*** no repclass ***");
		NSLog(@"repclass=%@", NSStringFromClass(repclass));
		NSLog(@"response: %@", response);
		NSLog(@"URL: %@", [response URL]);
		NSLog(@"textEncodingName: %@", [response textEncodingName]);
#endif
		[_connection cancel];	// cancel any pending actions 
		return;
		}
	_representation=[[repclass alloc] init];	// should conform to <WebDocumentRepresentation>
	[_representation setDataSource:self];		// we are the data source
#if 0
	NSLog(@"representation: %@", _representation);
#endif
}

- (void) connection:(NSURLConnection *) connection didReceiveData:(NSData *) data;
{ // new data received, append and notify representation and view
	WebView *webView=[_webFrame webView];
#if 0
	NSLog(@"data received: %@", data);
#endif
	if(!_loadedData)
		_loadedData=[data mutableCopy];	// first segment
	else
		[_loadedData appendData:data];
	// we should not reparse for every byte we receive...
	// determine if we have already received enough to reparse again, i.e. compare with [response expectedContentLength]
#if !ROBUSTNESS_TEST
	[_representation receivedData:_loadedData withDataSource:self];	// pass on what we have (we may be a subresource!)
#endif
	[[webView resourceLoadDelegate] webView:webView resource:_ident didReceiveContentLength:[data length] fromDataSource:_parent?_parent:self];
}

-(void) connectionDidFinishLoading:(NSURLConnection *) connection;
{
	WebView *webView=[_webFrame webView];
#if 1
	NSLog(@"connectionDidFinishLoading: %@", connection);
#endif
#if ROBUSTNESS_TEST
	{ // try to make the html parser fail by passing incomplete HTML source
		int i;
		for(i=1; i<[_loadedData length]; i++)
			[_representation receivedData:[_loadedData subdataWithRange:NSMakeRange(0, i)] withDataSource:self];	// parse with every length we have
	}
#endif
	if([_subdatasources count] == 0)	// we can notify immediately and don't postpone
		[_representation finishedLoadingWithDataSource:self];
	else
		_finishedLoading=YES;	// postpone notification until all immediately loading subresources are available - note: there may be subresouces that load afterwards
	[_parent _commitSubresource:self];
	[_connection release];
	_connection=nil;
#if 1
	NSLog(@"subresources: %d loaded, %d loading: %@", [_subresources count], [_subdatasources count], self);
#endif
	[[webView resourceLoadDelegate] webView:webView resource:_ident didFinishLoadingFromDataSource:_parent?_parent:self];
}

@end

@implementation _NSURLRequestNSData

- (id) initWithData:(NSData *) data mime:(NSString *) mime textEncodingName:(NSString *) encoding baseURL:(NSURL *) url;
{
	NSAssert(data != nil, @"trying to load nil data");
	if((self=[super initWithURL:[NSURL URLWithString:@"about:"]]))	// we must supply a dummy URL...
		{
		_data=[data retain];
		_response=[[NSURLResponse alloc] initWithURL:url MIMEType:mime expectedContentLength:[data length] textEncodingName:encoding];
		}
	return self;
}

- (id) copyWithZone:(NSZone *) zone;
{
	_NSURLRequestNSData *c=[super copyWithZone:zone];
	if(c)
		{
		c->_data=[_data retain];
		c->_response=[_response retain];
		}
	return c;
}

- (id) mutableCopyWithZone:(NSZone *) zone;
{
	return [self copyWithZone:zone];	// we are not really mutable!
}

- (void) dealloc;
{
	[_data release];
	[_response release];
	[super dealloc];
}

- (NSURLResponse *) response; { return _response; }
- (NSData *) data { return _data; }
- (BOOL) HTTPShouldHandleCookies; { return NO; }

- (NSURL *) URL
{ // provide a unique name useful for caching
	return [NSURL URLWithString:[NSString stringWithFormat:@"webdata://%p-%u", _data, [_data length]]];
}

@end
