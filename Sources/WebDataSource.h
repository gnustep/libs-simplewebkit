//
//  WebDataSource.h
//  mySTEP
//
//  Created by Dr. H. Nikolaus Schaller on Mon Jan 05 2004.
//  Revised May 2006
//  Copyright (c) 2004 DSITRI. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Foundation/NSURLConnection.h>
#import <Foundation/NSURLRequest.h>
#import <Foundation/NSURLResponse.h>
#import <WebKit/WebDocument.h>

@class WebArchive;
@class WebFrame;
@class WebResource;

@interface WebDataSource : NSObject
{
	NSURLConnection *_connection;								// our connection while we are loading
	id <WebDocumentRepresentation> _representation;	// representation - created as soon as header has been received
	NSURLRequest *_initial;
	NSMutableURLRequest *_request;
	NSURLResponse *_response;
	NSMutableData *_loadedData;
	NSMutableDictionary *_subresources;					// WebResource objects
	NSMutableDictionary *_subdatasources;				// the WebDataSource objects that are still loading
	WebDataSource *_parent;											// if we are a subresource
	id _ident;																	// identifier for WebResourceLoadDelegate
	WebFrame *_webFrame;
	NSURL *_unreachableURL;
	BOOL _finishedLoading;
}

- (void) addSubresource:(WebResource *) res;
- (NSData *) data;
- (NSURLRequest *) initialRequest;
- (id) initWithRequest:(NSURLRequest *) request;
- (BOOL) isLoading;
- (WebResource *) mainResource;
- (NSString *) pageTitle;
- (id <WebDocumentRepresentation>) representation;
- (NSMutableURLRequest *) request;
- (NSURLResponse *) response;
- (NSArray *) subresources;
- (WebResource *) subresourceForURL:(NSURL *) url;
- (NSString *) textEncodingName;
- (NSURL *) unreachableURL;
- (WebArchive *) webArchive;
- (WebFrame *) webFrame;

@end
