/* simplewebkit
   DOMHTML.h

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

#import <WebKit/DOMCore.h>

@class DOMCSSStyleDeclaration;
@class WebDataSource;
@class WebFrame;
@class _WebDocumentRepresentation;
@class NSTextTable, NSTextTableBlock;	// we don't explicitly import since we can't rely on its existence

#ifndef NIMP
#define NIMP NSLog(@"not implemented: %@", NSStringFromSelector(_cmd)), (id) nil
#endif
#ifndef ASSIGN
#define ASSIGN(var, val) ([var release], var=[val retain])
#endif

@interface DOMHTMLElement : DOMElement

+ (BOOL) _closeNotRequired;				// has no (explicit) close tag
+ (BOOL) _goesToHead;					// always becomes a child of <head>
+ (BOOL) _ignore;						// don't create nodes
+ (BOOL) _streamline;					// include embedded tags as plain strings (<title>xxx<b> etc. or <script><!-- ...)

- (NSString *) outerHTML;
- (NSString *) innerHTML;
- (NSAttributedString *) attributedString;
- (NSURL *) URLWithAttributeString:(NSString *) string;	// we don't inherit from DOMDocument...
- (WebFrame *) webFrame;

- (DOMCSSStyleDeclaration *) _style;		// get appropriate CSS definition by tag, tag level, id, class, etc.
- (void) _layout:(NSView *) parent index:(unsigned) idx;
- (void) _trimSpaces:(NSMutableAttributedString *) str;
- (NSAttributedString *) _tableCellsForTable:(NSTextTable *) table;
- (void) _awakeFromDocumentRepresentation:(_WebDocumentRepresentation *) rep;
- (void) _elementLoaded;	// element has been loaded

@end

@class WebFrame;

@interface DOMHTMLDocument : DOMHTMLElement			// the whole document
{
	WebDataSource *_dataSource;		// the datasource we belong to - not retained!
	WebFrame *_webFrame;			// the webframe we belong to - not retained!
}

- (void) _setWebFrame:(WebFrame *) frame;
- (WebFrame *) webFrame;
- (void) _setWebDataSource:(WebDataSource *) src;
- (WebDataSource *) _webDataSource;

@end

@interface DOMHTMLHtmlElement : DOMHTMLElement		// <html> - has <head> and <body> and <frameset> children
@end

@interface DOMHTMLHeadElement : DOMHTMLElement		// <head>
@end

@interface DOMHTMLTitleElement : DOMHTMLElement		// <title>
@end

@interface DOMHTMLMetaElement : DOMHTMLElement		// <meta>
@end

@interface DOMHTMLLinkElement : DOMHTMLElement		// <link>
@end

@interface DOMHTMLStyleElement : DOMHTMLElement		// <style>
@end

@interface DOMHTMLScriptElement : DOMHTMLElement	// <script>
@end

@interface DOMHTMLObjectElement : DOMHTMLElement	// <object>
@end

@interface DOMHTMLParamElement : DOMHTMLElement	// <param>
@end

@interface DOMHTMLFrameSetElement : DOMHTMLElement		// <frameset>
@end

@interface DOMHTMLFrameElement : DOMHTMLElement		// <frame>
@end

@interface DOMHTMLIFrameElement : DOMHTMLFrameElement	// <iframe>
@end

@interface DOMHTMLObjectFrameElement : DOMHTMLFrameElement	// <applet> or <object>
@end

@interface DOMHTMLBodyElement : DOMHTMLElement	// <body>
@end

@interface DOMHTMLDivElement : DOMHTMLElement	// <div>
@end

@interface DOMHTMLSpanElement : DOMHTMLElement	// <div>
@end

@interface DOMHTMLFontElement : DOMHTMLElement	// <font>
@end

@interface DOMHTMLAnchorElement : DOMHTMLElement	// <a>
@end

@interface DOMHTMLImageElement : DOMHTMLElement	// <img>
@end

@interface DOMHTMLBRElement : DOMHTMLElement	// <br>
@end

@interface DOMHTMLParagraphElement : DOMHTMLElement	// <p>
@end

@interface DOMHTMLHRElement : DOMHTMLElement	// <hr>
@end

@interface DOMHTMLTableElement : DOMHTMLElement	// <table>
@end

@interface DOMHTMLTableRowElement : DOMHTMLElement	// <tr>
@end

@interface DOMHTMLTableCellElement : DOMHTMLElement	// <td>
@end

@interface DOMHTMLFormElement : DOMHTMLElement	// <form>
@end

@interface DOMHTMLInputElement : DOMHTMLElement	// <input>
@end

@interface DOMHTMLButtonElement : DOMHTMLElement	// <button>
@end

@interface DOMHTMLSelectElement : DOMHTMLElement	// <select>
@end

@interface DOMHTMLOptionElement : DOMHTMLElement	// <option>
@end

@interface DOMHTMLOptGroupElement : DOMHTMLElement	// <optgroup>
@end

@interface DOMHTMLLabelElement : DOMHTMLElement	// <label>
@end

@interface DOMHTMLTextAreaElement : DOMHTMLElement	// <textarea>
@end

// plus some more...

// all other tags are plain DOMHTMLElements (e.g. <center>)

