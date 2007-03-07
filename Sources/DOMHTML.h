//
//  DOMHTML.h
//  SimpleWebKit
//
//  Created by Nikolaus Schaller on 28.01.07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <WebKit/DOMCore.h>

@interface DOMHTMLElement : DOMElement

+ (BOOL) _closeNotRequired;				// has no (explicit) close tag
+ (BOOL) _goesToHead;					// always becomes a child of <head>
+ (BOOL) _ignore;						// don't create nodes
+ (BOOL) _streamline;					// include embedded tags as plain strings (<title>xxx<b> etc. or <script><!-- ...)

- (NSString *) outerHTML;
- (NSString *) innerHTML;
- (NSAttributedString *) attributedString;

@end

@interface DOMHTMLDocument : DOMHTMLElement		// the whole document - not the same as DOMDocument!?!
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

@interface DOMHTMLFrameSetElement : DOMHTMLElement		// <frameset>
@end

@interface DOMHTMLFrameElement : DOMHTMLElement		// <frame>
@end

@interface DOMHTMLIFrameElement : DOMHTMLFrameElement	// <iframe>
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

@interface DOMHTMLLabelElement : DOMHTMLElement	// <label>
@end

@interface DOMHTMLTextAreaElement : DOMHTMLElement	// <textarea>
@end

// plus some more...

// all other tags are plain DOMHTMLElements (e.g. <center>)

