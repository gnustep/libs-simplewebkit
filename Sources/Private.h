/* simplewebkit
   Private.h

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
