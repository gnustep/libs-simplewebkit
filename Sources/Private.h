//
//  Private.h
//  mySTEP
//
//  Created by Dr. H. Nikolaus Schaller on Tue Sep 01 2005.
//  Copyright (c) 2005 DSITRI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebFrameView.h>
#import <WebKit/WebFrame.h>
#import <WebKit/WebDataSource.h>
#import <WebKit/WebDocument.h>
#import <WebKit/WebHistoryItem.h>
#import <WebKit/WebView.h>

#ifndef NIMP
#define NIMP NSLog(@"not implemented: %@", NSStringFromSelector(_cmd)), (id) nil
#endif
#ifndef ASSIGN
#define ASSIGN(var, val) ([var release], var=[val retain])
#endif

@interface WebFrameView (Private)
- (void) _setDocumentView:(NSView *) view;
- (void) _setWebFrame:(WebFrame *) wframe;
@end

@interface WebDataSource (Private)
- (void) _setUnreachableURL:(NSURL *) url;
- (void) _setWebFrame:(WebFrame *) wframe;
@end

@interface _WebNSDataSource : WebDataSource
- (id) initWithData:(NSData *) data MIMEType:(NSString *) mime textEncodingName:(NSString *) encoding baseURL:(NSURL *) url;
@end

@interface WebFrame (Private)
- (void) _setParentFrame:(WebFrame *) parent;	// weak pointer
- (void) _addChildFrame:(WebFrame *) child;
- (void) _setFrameElement:(DOMElement *) element;
- (void) _startedLoading;
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
