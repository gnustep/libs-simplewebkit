/* simplewebkit
   Private.h

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

   Revision $Id: WebDocumentRepresentation.h 515 2007-05-07 07:07:18Z hns $

*/

#import <Foundation/Foundation.h>
#import <WebKit/WebDataSource.h>
#import <WebKit/WebDocument.h>
#import <WebKit/WebFrame.h>
#import <WebKit/WebFrameView.h>
#import <WebKit/WebHistoryItem.h>
#import <WebKit/WebView.h>

#ifndef NIMP
#define NIMP NSLog(@"not implemented: [%@ %@] - %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), self), (id) nil
#endif
#ifndef ASSIGN
#define ASSIGN(var, val) ([var release], var=[val retain])
#endif

@interface WebFrameView (Private)
- (void) _setDocumentView:(NSView *) view;
- (void) _setWebFrame:(WebFrame *) wframe;
- (NSRect) _recommendedDocumentFrame;
@end

@interface WebDataSource (Private)
- (NSStringEncoding) _textEncoding;
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
- (void) _setDOMDocument:(RENAME(DOMDocument) *) doc;
- (void) _addToHistory;
- (void) _didStartLoad;
- (void) _didReceiveData;
- (void) _failedWithError:(NSError *) error;
- (void) _finishedLoading;
- (void) _performClientRedirectToURL:(NSURL *) URL delay:(NSTimeInterval) seconds;
@end

@interface WebHistoryItem (Private)
- (void) _touch;
- (void) _setIcon:(NSImage *) icon;
- (void) _setURL:(NSURL *) url;
- (int) _visitCount;
- (void) _setVisitCount:(int) v;
@end

@interface WebView (Private)
+ (Class) _representationClassForMIMEType:(NSString *) type;
+ (Class) _viewClassForMIMEType:(NSString *) type;
- (BOOL) drawsBackground;
- (void) setDrawsBackground:(BOOL) flag;
- (DOMCSSStyleDeclaration *) _styleForElement:(DOMElement *) element pseudoElement:(NSString *) pseudoElement parentStyle:(DOMCSSStyleDeclaration *) parent;
- (void) _spliceNode:(DOMNode *) node to:(NSMutableAttributedString *) str parentStyle:(DOMCSSStyleDeclaration *) parent parentAttributes:(NSDictionary *) parentAttributes;
@end

@interface NSView (WebDocumentView)
- (void) _recursivelySetNeedsLayout;
@end

@interface WebPreferences (Private)

- (BOOL) authorAndUserStylesEnabled;
- (void) setAuthorAndUserStylesEnabled:(BOOL) flag;
- (BOOL) developerExtrasEnabled;
- (void) setDeveloperExtrasEnabled:(BOOL) flag;

@end
