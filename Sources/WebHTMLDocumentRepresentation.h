/* simplewebkit
   WebHTMLDocumentRepresentation.h

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

#import <Foundation/Foundation.h>
#import <WebKit/WebDataSource.h>
#import <WebKit/DOM.h>
#import "WebDocumentRepresentation.h"

@interface _WebHTMLDocumentRepresentation : _WebDocumentRepresentation
{
	RENAME(DOMDocument) *_doc;		// current document - just a pointer to the object created by WebFrame
	DOMHTMLElement *_root;			// current root - just a pointer
	DOMHTMLHeadElement *_head;		// current head - just a pointer
	DOMHTMLBodyElement *_body;		// current body - just a pointer
	DOMHTMLFrameSetElement *_frameSet;	// current frameset - just a pointer
	NSMutableArray *_elementStack;	// stack of current objects for adding children
	id _parser;
}

- (id) _parser;		// get access to the parser

@end

@interface NSXMLParser (NSPrivate)
- (void) _setReadMode:(int) mode;
- (NSArray *) _tagPath;					// path of all tags
- (void) _setEncoding:(NSStringEncoding) enc;
- (void) _parseData:(NSData *) data;	// incremental parsing
- (void) _stall:(BOOL) flag;
- (BOOL) _isStalled;
@end

@interface _WebRTFDocumentRepresentation : _WebHTMLDocumentRepresentation

@end
