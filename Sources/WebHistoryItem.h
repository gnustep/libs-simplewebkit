//
//  WebHistoryItem.h
//  mySTEP
//
//  Created by Dr. H. Nikolaus Schaller on Tue May 16 2006.
//  Copyright (c) 2006 DSITRI. All rights reserved.
//

#import <Cocoa/Cocoa.h>

extern NSString *WebHistoryItemChangedNotification;

@interface WebHistoryItem : NSObject <NSCopying>
{
	NSString *_alternateTitle;
	NSImage *_icon;
	NSString *_originalURLString;
	NSString *_title;
	NSString *_URLString;
	NSTimeInterval _lastVisitedTimeInterval;
}

- (NSString *) alternateTitle;
- (NSImage *) icon;
- (id) initWithURLString:(NSString *) url title:(NSString *) title lastVisitedTimeInterval:(NSTimeInterval) time;
- (NSTimeInterval) lastVisitedTimeInterval;
- (NSString *) originalURLString;
- (void) setAlternateTitle:(NSString *) title;
- (NSString *) title;
- (NSString *) URLString;

@end
