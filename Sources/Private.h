//
//  Private.h
//  mySTEP
//
//  Created by Dr. H. Nikolaus Schaller on Tue Sep 01 2005.
//  Copyright (c) 2005 DSITRI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebDataSource.h>
#import <WebKit/WebDocument.h>
#import <WebKit/WebFrame.h>
#import <WebKit/WebFrameView.h>
#import <WebKit/WebHistoryItem.h>
#import <WebKit/WebView.h>

#ifndef NIMP
#define NIMP NSLog(@"not implemented: %@ - %@", NSStringFromSelector(_cmd), self), (id) nil
#endif
#ifndef ASSIGN
#define ASSIGN(var, val) ([var release], var=[val retain])
#endif

@interface WebFrameView (Private)
- (void) _setDocumentView:(NSView *) view;
- (void) _setWebFrame:(WebFrame *) wframe;
@end

@interface WebDataSource (Private)
- (NSStringEncoding) _stringEncoding;
- (void) _setUnreachableURL:(NSURL *) url;
- (void) _setWebFrame:(WebFrame *) wframe;
- (WebDataSource *) _subresourceWithURL:(NSURL *) url delegate:(id <WebDocumentRepresentation>) rep;	// triggers loading if not (yet) available and optionally stalls main data source
- (void) _setParentDataSource:(WebDataSource *) source;
- (void) _commitSubresource:(WebDataSource *) source;
- (void) _setRepresentation:(id <WebDocumentRepresentation>) rep;	// the object that receives notifications
- (BOOL) _isSubresource;
@end

@interface _NSURLRequestNSData : NSURLRequest
{
	NSData *_data;				// data to return
	NSURLResponse *_response;	// virtual response...
}

- (id) initWithData:(NSData *) data mime:(NSString *) mime textEncodingName:(NSString *) encoding baseURL:(NSURL *) url;
- (NSURLResponse *) response;
- (NSData *) data;

@end

// @interface _WebNSDataSource : WebDataSource
// - (id) initWithData:(NSData *) data MIMEType:(NSString *) mime textEncodingName:(NSString *) encoding baseURL:(NSURL *) url;
// @end

@interface WebFrame (Private)
- (void) _setParentFrame:(WebFrame *) parent;	// weak pointer
- (void) _setFrameName:(NSString *) name;
- (void) _addChildFrame:(WebFrame *) child;
- (void) _setFrameElement:(DOMHTMLElement *) element;
- (void) _finishedLoading;
- (void) _receivedData:(WebDataSource *) dataSource;
@end

@interface WebHistoryItem (Private)
- (void) _touch;
- (void) _setIcon:(NSImage *) icon;
- (void) _setURL:(NSURL *) url;
@end

@interface WebView (Private)
+ (Class) _representationClassForMIMEType:(NSString *) type;
+ (Class) _viewClassForMIMEType:(NSString *) type;
- (BOOL) drawsBackground;
- (void) setDrawsBackground:(BOOL) flag;
@end

@interface NSView (WebDocumentView)
- (void) _recursivelySetNeedsLayout;
@end
