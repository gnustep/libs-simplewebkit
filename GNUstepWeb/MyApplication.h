//
//  MyApplication.h
//
//  Created by Dr. H. Nikolaus Schaller on Sun Aug 17 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface MyApplication : NSObject
{
	IBOutlet NSOutlineView *activity;
	NSMutableArray *activities;		// array of subresources
}

@end
