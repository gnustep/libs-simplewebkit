/* simplewebkit
   WebFrameLoadDelegate.h

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

@class WebView, WebFrame, WebScriptObject;

// used as frameLoadDelegate of WebView

@interface NSObject (WebFrameLoadDelegate)

- (void) webView:(WebView *) sender didCancelClientRedirectForFrame:(WebFrame *) frame;
- (void) webView:(WebView *) sender didChangeLocationWithinPageForFrame:(WebFrame *) frame;
- (void) webView:(WebView *) sender didCommitLoadForFrame:(WebFrame *) frame;
- (void) webView:(WebView *) sender didFailLoadWithError:(NSError *) error forFrame:(WebFrame *) frame;
- (void) webView:(WebView *) sender didFailProvisionalLoadWithError:(NSError *) error forFrame:(WebFrame *) frame;
- (void) webView:(WebView *) sender didFinishLoadForFrame:(WebFrame *) frame;
- (void) webView:(WebView *) sender didReceiveIcon:(NSImage *) image forFrame:(WebFrame *) frame;
- (void) webView:(WebView *) sender didReceiveTitle:(NSString *) title forFrame:(WebFrame *) frame;
- (void) webView:(WebView *) sender didStartProvisionalLoadForFrame:(WebFrame *) frame;
- (void) webView:(WebView *) sender serverRedirectedForDataSource:(WebFrame *) frame;
- (void) webView:(WebView *) sender willCloseFrame:(WebFrame *) frame;
- (void) webView:(WebView *) sender willPerformClientRedirectToURL:(NSURL *) url delay:(NSTimeInterval) seconds fireDate:(NSDate *) date forFrame:(WebFrame *) frame;
- (void) webView:(WebView *) sender windowScriptObjectAvailable:(WebScriptObject *) script;

@end

