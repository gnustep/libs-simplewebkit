//
//  WebDataSource.m
//  mySTEP
//
//  Created by Dr. H. Nikolaus Schaller on Mon Jan 05 2004.
//  Revised May 2006
//  Copyright (c) 2004 DSITRI. All rights reserved.
//

#import "Private.h"
#import <WebKit/WebDataSource.h>
#import <WebKit/WebResource.h>

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
		_connection=[[NSURLConnection connectionWithRequest:_request delegate:self] retain];
		_isLoading=YES;

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
	[_connection cancel];	// cancel any pending actions 
	[_connection release];
	[_initial release];
	[_request release];
	[_response release];
	[_loadedData release];
	[_subresources release];
	[_unreachableURL release];
	[(NSObject *) _representation release];
	[super dealloc];
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

- (WebResource *) mainResource; { return NIMP; }

- (NSString *) pageTitle; { return _representation?[_representation title]:nil; }
	
- (id <WebDocumentRepresentation>) representation; { return _representation; }

- (NSMutableURLRequest *) request; { return _request; }

- (NSURLResponse *) response; { return _response; }

- (NSArray *) subresources; { return [_subresources allValues]; }

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

- (NSURL *) unreachableURL; { return _unreachableURL; }
- (void) _setUnreachableURL:(NSURL *) url; { ASSIGN(_unreachableURL, url); }

- (WebArchive *) webArchive;
{
	// parse data into webArchive
	return NIMP;
}

- (WebFrame *) webFrame;
{
	return _webFrame;
}

- (void) _setWebFrame:(WebFrame *) wf;
{
	_webFrame=wf;
}

// delegate callbacks during data reception - pass to representation

- (void) connection:(NSURLConnection *) connection didFailWithError:(NSError *) error;
{
	NSLog(@"WebDataSource error: %@", error);
	[_representation receivedError:(NSError *)error withDataSource:self];
}

- (NSURLRequest *) connection:(NSURLConnection *) connection willSendRequest:(NSURLRequest *) request redirectResponse:(NSURLResponse *) redirectResponse;
{
	[_request release];
	_request=[request mutableCopy];	// new current request
	// modify request
	return _request;
}

- (void) connection:(NSURLConnection *) connection didReceiveResponse:(NSURLResponse *) response;
{
	long long len=[response expectedContentLength];
	Class repclass;
	Class viewclass;
	NSView <WebDocumentView> *view;
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
	if(!_loadedData && len > 0 && len < 2000000)
		_loadedData=[[NSMutableData alloc] initWithCapacity:len];	// preallocate up to 2 MByte
	repclass=[WebView _representationClassForMIMEType:[response MIMEType]];
#if 1
	NSLog(@"repclass=%@", NSStringFromClass(repclass));
#endif
	if(repclass == Nil)
		return;	// don't know what to do now...
	_representation=[[repclass alloc] init];	// should conform to <WebDocumentRepresentation>
	[_representation setDataSource:self];		// we are the data source
#if 1
	NSLog(@"representation: %@", _representation);
#endif
	// FIXME: shouldn't this better be handled by a notification handler???
	viewclass=[WebView _viewClassForMIMEType:[response MIMEType]];
	view=[[viewclass alloc] initWithFrame:[[_webFrame frameView] frame]];
	[[_webFrame frameView] _setDocumentView:view];
	[view setNeedsLayout:YES];
	[view release];
}

- (void) connection:(NSURLConnection *) connection didReceiveData:(NSData *) data;
{ // new data received, append
#if 0
	NSLog(@"data received: %@", data);
#endif
	if(!_loadedData)
		_loadedData=[data mutableCopy];	// first segment
	else
		[_loadedData appendData:data];
	// determine if we have received enough to reparse again, i.e. compare with expectedContentLength
	[_representation receivedData:_loadedData withDataSource:self];
}

-(void) connectionDidFinishLoading:(NSURLConnection *) connection;
{
	NSLog(@"connectionDidFinishLoading: %@", connection);
	_isLoading=NO;	// finished
	[_representation finishedLoadingWithDataSource:self];	// notify
}

@end

@implementation _WebNSDataSource

- (id) initWithData:(NSData *) data MIMEType:(NSString *) mime textEncodingName:(NSString *) encoding baseURL:(NSURL *) url;
{
	if((self=[super init]))
		{
		_loadedData=[data retain];
		_response=[[NSURLResponse alloc] initWithURL:url MIMEType:mime expectedContentLength:[data length] textEncodingName:encoding];
		}
	return self;
}

- (void) _setWebFrame:(WebFrame *) wf;
{ // set web frame and simulate loading
	_webFrame=wf;
	_isLoading=YES;
	[_response autorelease];	// will be retained once more
	[self connection:nil didReceiveResponse:_response];	// we have no connection...
#if 0
	NSLog(@"data received: %@", _loadedData);
#endif
	[_representation receivedData:_loadedData withDataSource:self];
	[self connectionDidFinishLoading:nil];	// notify
}

@end
