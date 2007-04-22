//
//  WebDocumentRepresentation.h
//  SimpleWebKit
//
//  Created by Nikolaus Schaller on 27.01.07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebFrameView.h>
#import <WebKit/WebFrame.h>
#import <WebKit/WebDataSource.h>
#import <WebKit/WebDocument.h>
#import <WebKit/WebHistoryItem.h>
#import <WebKit/WebView.h>

@interface _WebDocumentRepresentation : NSObject <WebDocumentRepresentation>
{
	WebDataSource *_dataSource;		// our data source
	id _delegate;					// who should receive update notifications?
}

@end
