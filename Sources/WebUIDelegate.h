//
//  WebFrameLoadDelegate.h
//  mySTEP
//
//  Created by Dr. H. Nikolaus Schaller on Sat Jan 27 2007.
//  Copyright (c) 2007 DSITRI. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class WebView, WebFrame;

// used as UIDelegate of WebView

@interface NSObject (WebViewUIDelegate)
- (WebView *) webView:(WebView *)sender createWebViewWithRequest:(NSURLRequest *)request;
- (void) webViewShow:(WebView *)sender;
- (void) webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame;
- (void) webView:(WebView *)sender didReceiveTitle:(NSString *)title forFrame:(WebFrame *)frame;
- (void) webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame;
@end

