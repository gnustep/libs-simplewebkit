//
//  WebResourceLoadDelegate.h
//  mySTEP
//
//  Created by Dr. H. Nikolaus Schaller on Fri Apr 06 2007.
//  Copyright (c) 2007 DSITRI. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class WebView, WebDataSource;

// used as resourceLoadDelegate of WebView

@interface NSObject (WebResourceLoadDelegate)

- (id) webView:(WebView *) sender identifierForInitialRequest:(NSURLRequest *) req fromDataSource:(WebDataSource *) src;
- (void) webView:(WebView *) sender plugInFailedWithError:(NSError *) error dataSource:(WebDataSource *) src;
- (void) webView:(WebView *) sender resource:(id) ident didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *) ch fromDataSource:(WebDataSource *) src;
- (void) webView:(WebView *) sender resource:(id) ident didFailLoadingWithError:(NSError *) error fromDataSource:(WebDataSource *) src;
- (void) webView:(WebView *) sender resource:(id) ident didFinishLoadingFromDataSource:(WebDataSource *) src;
- (void) webView:(WebView *) sender resource:(id) ident didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *) ch fromDataSource:(WebDataSource *) src;
- (void) webView:(WebView *) sender resource:(id) ident didReceiveContentLength:(unsigned) len fromDataSource:(WebDataSource *) src;
- (void) webView:(WebView *) sender resource:(id) ident didReceiveResponse:(NSURLResponse *) resp fromDataSource:(WebDataSource *) src;
- (NSURLRequest *) webView:(WebView *) sender resource:(id) ident willSendRequest:(NSURLRequest *) req redirectResponse:(NSURLResponse *) resp fromDataSource:(WebDataSource *) src;

@end

