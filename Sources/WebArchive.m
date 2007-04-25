//
//  WebArchive.m
//  mySTEP
//
//  Created by Dr. H. Nikolaus Schaller on 12.03.2007.
//  Copyright (c) 2006 DSITRI. All rights reserved.
//

#import <WebKit/WebArchive.h>
#import <WebKit/WebResource.h>

#import "Private.h"

NSString *WebArchivePboardType=@"WebArchivePboardType";

@implementation WebArchive

- (NSData *) _archivedData;
{
	return NIMP;
}

- (id) initWithData:(NSData *) data;
{
	return NIMP;
}

- (id) initWithMainResource:(WebResource *) main subresources:(NSArray *) sub subframeArchives:(NSArray *) frames;
{
	if((self=[super init]))
		{
		_mainResource=[main retain];
		_subframeArchives=[sub retain];
		_subresources=[frames retain];
		}
	return self;
}

- (void) dealloc;
{
	[_mainResource release];
	[_subframeArchives release];
	[_subresources release];
	[super dealloc];
}

- (WebResource *) mainResource; { return _mainResource; }
- (NSArray *) subframeArchives; { return _subframeArchives; }
- (NSArray *) subresources; { return _subresources; }

@end
