//
//  WebResource.h
//  mySTEP
//
//  Created by Dr. H. Nikolaus Schaller on Tue Jun 20 2006.
//  Copyright (c) 2006 DSITRI. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface WebResource : NSObject
{
	NSData *_data;
	NSString *_frameName;
	NSString *_MIMEType;
	NSString *_textEncodingName;
	NSURL *_URL;
}

- (NSData *) data;
- (NSString *) frameName;
- (id) initWithData:(NSData *) data URL:(NSURL *) url MIMEType:(NSString *) mime textEncodingName:(NSString *) encoding frameName:(NSString *) name;
- (NSString *) MIMEType;
- (NSString *) textEncodingName;
- (NSURL *) URL;

@end
