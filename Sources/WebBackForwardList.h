//
//  WebBackForwardList.h
//  mySTEP
//
//  Created by Dr. H. Nikolaus Schaller on Tue May 16 2006.
//  Copyright (c) 2006 DSITRI. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class WebHistoryItem;

@interface WebBackForwardList : NSObject
{
	NSMutableArray *_backList;
	NSMutableArray *_forwardList;
	WebHistoryItem *_currentItem;
	int _capacity;
	unsigned _pageCacheSize;	// just stored here but not used internaly
}

- (void) addItem:(WebHistoryItem *) item;
- (WebHistoryItem *) backItem;
- (int) backListCount;
- (NSArray *) backListWithLimit:(int) limit;
- (int) capacity;
- (BOOL) containsItem:(WebHistoryItem *) item;
- (WebHistoryItem *) currentItem;
- (WebHistoryItem *) forwardItem;
- (int) forwardListCount;
- (NSArray *) forwardListWithLimit:(int) limit;
- (void) goBack;
- (void) goForward;
- (void) goToItem:(WebHistoryItem *) item;
- (id) init;
- (WebHistoryItem *) itemAtIndex:(int) index;
- (unsigned) pageCacheSize;
- (void) setCapacity:(int) size;
- (void) setPageCacheSize:(unsigned) size;

@end