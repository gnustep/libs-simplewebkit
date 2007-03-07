//
//  WebResource.m
//  mySTEP
//
//  Created by Dr. H. Nikolaus Schaller on Tue May 16 2006.
//  Copyright (c) 2006 DSITRI. All rights reserved.
//

#import "Private.h"
#import <WebKit/WebResource.h>

@implementation WebResource

- (NSData *) data; { return _data; }
- (NSString *) frameName; { return _frameName; }
- (NSString *) MIMEType; { return _MIMEType; }
- (NSString *) textEncodingName; { return _textEncodingName; }
- (NSURL *) URL; { return _URL; }

- (id) initWithData:(NSData *) data URL:(NSURL *) url MIMEType:(NSString *) mime textEncodingName:(NSString *) encoding frameName:(NSString *) name;
{
	if((self=[super init]))
		{
		_data=[data retain];
		_frameName=[name retain];
		_MIMEType=[mime retain];
		_textEncodingName=[encoding retain];
		_URL=[url retain];
		}
	return self;
}


- (void) dealloc;
{
	[_data release];
	[_frameName release];
	[_MIMEType release];
	[_textEncodingName release];
	[_URL release];
	[super dealloc];
}

@end
