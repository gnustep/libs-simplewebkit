/* simplewebkit
   WebUIDelegate.h

   Copyright (C) 2007 Free Software Foundation, Inc.

   Author: Dr. H. Nikolaus Schaller

   This file is part of the GNUstep Database Library.

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

