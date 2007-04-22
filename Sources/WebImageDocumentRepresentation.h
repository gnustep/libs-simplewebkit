//
//  WebImageDocumentRepresentation.h
//  SimpleWebKit
//
//  Created by Nikolaus Schaller on 27.01.07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/NSImage.h>
#import <WebKit/WebFrameView.h>
#import <WebKit/WebFrame.h>
#import <WebKit/WebDataSource.h>
#import <WebKit/WebDocument.h>
#import <WebKit/WebHistoryItem.h>
#import <WebKit/WebView.h>
#import "WebDocumentRepresentation.h"

@interface _WebImageDocumentRepresentation : _WebDocumentRepresentation
{
	NSImage *_image;
}

- (NSImage *) getImage;	// get as good as we can - may be a placeholder

@end

@interface _WebImageDocumentView : NSImageView <WebDocumentView>
{
	WebDataSource *_dataSource;
	BOOL _needsLayout;
}

@end

