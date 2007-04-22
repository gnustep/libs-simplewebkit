//
//  WebHTMLDocumentRepresentation.h
//  mySTEP
//
//  Created by Dr. H. Nikolaus Schaller on Tue Sep 01 2005.
//  Copyright (c) 2005 DSITRI. All rights reserved.
//

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

@end
