/* simplewebkit
   WebDOMOperations.h

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
#import <WebKit/DOM.h>
#import <WebKit/DOMHTML.h>
#import <WebKit/DOMRange.h>

@class WebArchive;
@class WebFrame;

@interface RENAME(DOMDocument) (WebDOMOperations)
// FIXME: that is strange from the Doc - DOMHTMLElements don't inherit from DOMDocument but Doc says it is used in DOMHTMLAnchorElement
- (NSURL *) URLWithAttributeString:(NSString *) string;
- (WebFrame *) webFrame;
@end

@interface DOMHTMLFrameElement (WebDOMOperations)
- (WebFrame *) contentFrame;
@end

@interface DOMHTMLIFrameElement (WebDOMOperations)
- (WebFrame *) contentFrame;
@end

@interface DOMHTMLObjectFrameElement (WebDOMOperations)
- (WebFrame *) contentFrame;
@end

@interface DOMNode (WebDOMOperations)
- (WebArchive *) webArchive;
@end

@interface DOMRange (WebDOMOperations)
- (NSString *) markupString;
- (WebArchive *) webArchive;
@end
