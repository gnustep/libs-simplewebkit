//
//  WebPlugInContainer.h
//  mySTEP
//
//  Created by Dr. H. Nikolaus Schaller on Mar 25 2007.
//  Copyright (c) 2006 DSITRI. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class WebFrame;

@interface NSObject (WebPlugInContainer)
- (WebFrame *) webFrame;
- (void) webPlugInContainerLoadRequest:(NSURLRequest *) request inFrame:(NSString *) target;
- (NSColor *) webPlugInContainerSelectionColor;
- (void) webPlugInContainerShowStatus:(NSString *) msg;
@end
