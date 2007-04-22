//
//  WebHistoryItem.m
//  mySTEP
//
//  Created by Dr. H. Nikolaus Schaller on Tue May 16 2006.
//  Copyright (c) 2006 DSITRI. All rights reserved.
//

#import "Private.h"
#import <WebKit/WebHistoryItem.h>

NSString *WebHistoryItemChangedNotification=@"WebHistoryItemChangedNotification";

@implementation WebHistoryItem

- (NSString *) alternateTitle; { return _alternateTitle; }
- (NSImage *) icon; { return _icon; }

- (id) initWithURLString:(NSString *) url
				   title:(NSString *) title
 lastVisitedTimeInterval:(NSTimeInterval) time;
{
	if((self=[super init]))
		{
		_originalURLString=[url retain];
		_URLString=[url retain];
		_title=[title retain];
		_lastVisitedTimeInterval=time;
		}
	return self;
}

- (void) dealloc;
{
	[_alternateTitle release];
	[_icon release];
	[_originalURLString release];
	[_title release];
	[_URLString release];
	[super dealloc];
}

- (id) copyWithZone:(NSZone *) zone;
{
	WebHistoryItem *c;
	if((c=[[NSObject allocWithZone:zone] init]))
		{
		c->_originalURLString=[_originalURLString retain];
		c->_URLString=[_URLString retain];
		c->_title=[_title retain];
		c->_lastVisitedTimeInterval=_lastVisitedTimeInterval;
		}
	return c;
}

- (NSTimeInterval) lastVisitedTimeInterval; { return _lastVisitedTimeInterval; }
- (NSString *) originalURLString; { return _originalURLString; }
- (void) setAlternateTitle:(NSString *) title; { ASSIGN(_alternateTitle, title); [self _notify]; }
- (NSString *) title; { return _title; }
- (NSString *) URLString; { return _URLString; }

- (void) _notify; { [[NSNotificationCenter defaultCenter] postNotificationName:WebHistoryItemChangedNotification object:self]; }
- (void) _touch; { _lastVisitedTimeInterval=[NSDate timeIntervalSinceReferenceDate]; }
- (void) _setIcon:(NSImage *) icon; { ASSIGN(_icon, icon); [self _notify]; }
- (void) _setURL:(NSURL *) url; { ASSIGN(_URLString, url); [self _notify]; }

@end