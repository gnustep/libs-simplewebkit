//
//  WebDOMOperations.h
//  mySTEP
//
//  Created by Dr. H. Nikolaus Schaller on Tue May 16 2006.
//  Copyright (c) 2006 DSITRI. All rights reserved.
//

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