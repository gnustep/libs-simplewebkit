/* simplewebkit
   WebResourceLoadDelegate.h

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

