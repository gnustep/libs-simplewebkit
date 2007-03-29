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

- (id) initWithRequest:(NSURLRequest *) request;
{
#if 0
	NSLog(@"WebDataSource initWithRequest %@", request);
#endif
    if((self = [super init]))
		{ // If an error occurs here, send a [self release] message and return nil.
		_initial=[request copy];
		_request=[_initial mutableCopy];
		// modify request webView:resource:willSendRequest:redirectResponse:fromDataSource:
#if 0
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
	if(_isLoading)
		;
	[_connection cancel];	// cancel any pending actions 
	[_connection release];
	[_initial release];
	[_request release];
	[_response release];
	[_loadedData release];
	[_subresources release];
	[_loadingSubresources release];
	[_unreachableURL release];
	[(NSObject *) _representation release];
	[super dealloc];
}

- (NSString *) description; { return [NSString stringWithFormat:@"%@: %@ -> %@", [super description], _request, _response]; }
- (void) _cancel;
{
	[_connection cancel];
	[_connection release];
	_connection=nil;
	// cancel all still loading subresources
}

- (BOOL) isLoading; { return _isLoading; }

- (void) addSubresource:(WebResource *) res;
{
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

- (void) _loadSubresourceWithURL:(NSURL *) url;
{
	url=[url absoluteURL];
	if(![_subresources objectForKey:url] && ![_loadingSubresources objectForKey:url])
		{ // not yet known
		WebDataSource *sub=[[[isa alloc] initWithRequest:[NSURLRequest requestWithURL:url]] autorelease];	// make new request
#if 1
		NSLog(@"load subresource from %@", url);
#endif
		[sub _setParentDataSource:self];
		if(!_loadingSubresources)
			_loadingSubresources=[[NSMutableDictionary alloc] initWithCapacity:10];
		[_loadingSubresources setObject:sub forKey:url];	// add to list of resources currently loading
		// FIXME: this triggers a frameload callback but the subresource must learn about the webFrame it belongs to!?!
		[sub _setWebFrame:_webFrame];
		}
	else
		NSLog(@"already loading %@", url);
}

- (void) _commitSubresource:(WebDataSource *) source;
{ // subresource is done
#if 1
	NSLog(@"subresource committed: %@", source);
#endif
	[self addSubresource:[source mainResource]];	// save
	[_loadingSubresources removeObjectForKey:[[source request] URL]];
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

- (NSMutableURLRequest *) request; { return _request; }

- (NSURLResponse *) response; { return _response; }

- (NSArray *) subresources; { return _subresources?[_subresources allValues]:[NSArray array]; }

- (WebResource *) subresourceForURL:(NSURL *) url;
{
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
	// convert to string encoding value
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

- (void) _setWebFrame:(WebFrame *) wf;
{ // this triggers loading
	WebView *webView=[wf webView];
	_webFrame=wf;
	_isLoading=YES;
	if([_request isKindOfClass:[_NSURLRequestNSData class]])
		{
		[[webView frameLoadDelegate] webView:webView didStartProvisionalLoadForFrame:wf];
		[self connection:nil didReceiveResponse:[(_NSURLRequestNSData *) _request response]];	// simulate callbacks from NSURLConnection
		[self connection:nil didReceiveData:[(_NSURLRequestNSData *) _request data]];
		[self connectionDidFinishLoading:nil];	// notify
		}
	else
		{
		_connection=[[NSURLConnection connectionWithRequest:_request delegate:self] retain];
		[[webView frameLoadDelegate] webView:webView didStartProvisionalLoadForFrame:wf];
		}
}

// delegate callbacks during data reception - pass to representation

- (void) connection:(NSURLConnection *) connection didFailWithError:(NSError *) error;
{
#if 1
	NSLog(@"WebDataSource error: %@", error);
#endif
	_isLoading=NO;
	[_representation receivedError:(NSError *)error withDataSource:self];
	// how do we indicate the error???
	// should we really commit?
	// can the WebResource denote an erroneous resource???
	[_parent _commitSubresource:self]; 
}

- (NSURLRequest *) connection:(NSURLConnection *) connection willSendRequest:(NSURLRequest *) request redirectResponse:(NSURLResponse *) redirectResponse;
{
	[_request release];
	_request=[request mutableCopy];	// new current request
	// modify request
	return _request;
}

- (void) connection:(NSURLConnection *) connection didReceiveResponse:(NSURLResponse *) response;
{ // we have received the header - set up the WebRepresentation object determined by the MIME type
	long long len=[response expectedContentLength];
	Class repclass;
	_response=[response retain];
#if 0
	NSLog(@"response received: %@", response);
	if([response respondsToSelector:@selector(allHeaderFields)])
		NSLog(@"status code: %d all headers: %@", [(NSHTTPURLResponse *) response statusCode], [(NSHTTPURLResponse *) response allHeaderFields]);
	NSLog(@"mimeType: %@", [response MIMEType]);
	NSLog(@"expectedContentLength: %lld", [response expectedContentLength]);
	NSLog(@"suggestedFilename: %@", [response suggestedFilename]);
	NSLog(@"textEncodingName: %@", [response textEncodingName]);
#endif
	// [[webView frameLoadDelegate] webView:webView didCommitLoadForFrame:_webFrame];
	if(!_loadedData && len > 0 && len < 2000000)
		_loadedData=[[NSMutableData alloc] initWithCapacity:len];	// preallocate up to 2 MByte
	repclass=[WebView _representationClassForMIMEType:[response MIMEType]];
	if(repclass == Nil)
		{ // don't know what to do now...
#if 1
		NSLog(@"repclass=%@", NSStringFromClass(repclass));
		NSLog(@"response: %@", response);
		NSLog(@"URL: %@", [response URL]);
		NSLog(@"textEncodingName: %@", [response textEncodingName]);
#endif
		[_connection cancel];	// cancel any pending actions 
		return;
		}
	if(_representation && [(NSObject *) _representation class] == repclass)
		;	// we are already initialized...
	[(NSObject *) _representation release];	// delete existing representation
	_representation=[[repclass alloc] init];	// should conform to <WebDocumentRepresentation>
	[_representation setDataSource:self];		// we are the data source
#if 0
	NSLog(@"representation: %@", _representation);
#endif
}

- (void) connection:(NSURLConnection *) connection didReceiveData:(NSData *) data;
{ // new data received, append and notify representation and view
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
	[_representation receivedData:_loadedData withDataSource:self];	// pass on what we have
    [(NSView <WebDocumentView> *)[[_webFrame frameView] documentView] dataSourceUpdated:self];
#endif
}

-(void) connectionDidFinishLoading:(NSURLConnection *) connection;
{
	NSLog(@"connectionDidFinishLoading: %@", connection);
#if ROBUSTNESS_TEST
	{ // try to make the html parser fail by passing incomplete HTML source
		int i;
		for(i=1; i<[_loadedData length]; i++)
			[_representation receivedData:[_loadedData subdataWithRange:NSMakeRange(0, i)] withDataSource:self];	// parse with every length we have
	}
#endif
	// FIXME: shouldn't we notify only after all subresources have finished loading as well???
	_isLoading=NO;	// finished
	[_representation finishedLoadingWithDataSource:self];	// notify
	[_parent _commitSubresource:self]; 
}

@end

@implementation _NSURLRequestNSData

- (id) initWithData:(NSData *) data mime:(NSString *) mime textEncodingName:(NSString *) encoding baseURL:(NSURL *) url;
{
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

-(NSURL *) URL { return [NSURL URLWithString:@""]; }

@end
