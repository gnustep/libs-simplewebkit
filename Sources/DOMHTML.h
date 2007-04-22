//
//  DOMHTML.h
//  SimpleWebKit
//
//  Created by Nikolaus Schaller on 28.01.07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <WebKit/DOMCore.h>

@class DOMCSSStyleDeclaration;
@class WebDataSource;
@class WebFrame;
@class _WebDocumentRepresentation;

@interface DOMHTMLElement : DOMElement

+ (BOOL) _closeNotRequired;				// has no (explicit) close tag
+ (BOOL) _goesToHead;					// always becomes a child of <head>
+ (BOOL) _ignore;						// don't create nodes
+ (BOOL) _streamline;					// include embedded tags as plain strings (<title>xxx<b> etc. or <script><!-- ...)

- (NSString *) outerHTML;
- (NSString *) innerHTML;
- (NSAttributedString *) attributedString;
- (NSURL *) URLWithAttributeString:(NSString *) string;	// we don't inherit from DOMDocument...
- (NSData *) _loadSubresourceWithAttributeString:(NSString *) string;
- (WebFrame *) webFrame;

- (DOMCSSStyleDeclaration *) _cssStyle;
- (NSMutableDictionary *) _style;		// get appropriate CSS definition by tag, tag level, id, class, etc. recursively going upwards
- (void) _layout:(NSView *) view;		// layout view according to the DOM node (may swap the view within its superview!)
- (void) _trimSpaces:(NSMutableAttributedString *) str;
- (NSAttributedString *) _tableCellsForTable:(NSTextTable *) table row:(unsigned *) row col:(unsigned *) col;
- (void) _awakeFromDocumentRepresentation:(_WebDocumentRepresentation *) rep;	// node has just been decoded but not processed otherwise
- (void) _elementLoaded;	// element has been loaded

@end

@class WebFrame;

@interface DOMHTMLDocument : DOMHTMLElement			// the whole document
{
	WebDataSource *_dataSource;		// the datasource we belong to - not retained!
	WebFrame *_webFrame;			// the webframe we belong to - not retained!
	NSTimer *_timer;					// redirection timer
}

- (void) _setWebFrame:(WebFrame *) frame;
- (WebFrame *) webFrame;
- (void) _setWebDataSource:(WebDataSource *) src;
- (WebDataSource *) _webDataSource;
- (void) _setRedirectTimer:(NSTimer *) timer;

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

