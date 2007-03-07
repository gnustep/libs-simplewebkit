//
//  WebHTMLDocumentView.h
//  mySTEP
//
//  Created by Dr. H. Nikolaus Schaller on Tue Sep 01 2005.
//  Copyright (c) 2005 DSITRI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebFrameView.h>
#import <WebKit/WebFrame.h>
#import <WebKit/WebDataSource.h>
#import <WebKit/WebDocument.h>
#import <WebKit/WebHistoryItem.h>
#import <WebKit/WebView.h>
#import <WebKit/DOM.h>
#import <AppKit/NSTextView.h>

@interface _WebHTMLDocumentView : NSView <WebDocumentView, WebDocumentText>	// our document view is a NSTextView which (re)loads HTML as an NSAttributedString
{
	WebDataSource *_dataSource;
	BOOL _needsLayout;
}
@end

