//
//  WebDownload.h
//  mySTEP
//
//  Created by Dr. H. Nikolaus Schaller on Tue May 16 2006.
//  Copyright (c) 2006 DSITRI. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/DOM.h>

@interface WebDownload : NSURLDownload
{
}

- (NSWindow *) downloadWindowForAuthenticationSheet:(WebDownload *) sender;

@end