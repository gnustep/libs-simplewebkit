//
//  WebArchive.h
//  mySTEP
//
//  Created by Dr. H. Nikolaus Schaller on 12.03.2007.
//  Copyright (c) 2006 DSITRI. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/DOM.h>

extern NSString *WebArchivePboardType;

@class WebResource;

@interface WebArchive : NSObject
{
	WebResource *_mainResource;
	NSMutableArray *_subframeArchives;
	NSMutableArray *_subresources;
}

- (id) initWithData:(NSData *) data;
- (id) initWithMainResource:(WebResource *) main subresources:(NSArray *) sub subframeArchives:(NSArray *) frames;
- (WebResource *) mainResource;
- (NSArray *) subframeArchives;
- (NSArray *) subresources;

@end
	
