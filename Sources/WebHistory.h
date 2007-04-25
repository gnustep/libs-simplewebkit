//
//  WebHistory.h
//  mySTEP
//
//  Created by Dr. H. Nikolaus Schaller on Tue May 16 2006.
//  Copyright (c) 2006 DSITRI. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class WebHistoryItem;

extern NSString *WebHistoryItemsKey;

extern NSString *WebHistoryAllItemsRemovedNotification;
extern NSString *WebHistoryItemsAddedNotification;
extern NSString *WebHistoryItemsRemovedNotification;
extern NSString *WebHistoryLoadedNotification;
extern NSString *WebHistorySavedNotification;

@interface WebHistory : NSObject
{
	NSMutableDictionary *_itemsByURL;		// all items indexed by URL
	NSMutableDictionary *_itemGroupsByDates;	// all items grouped (&ordered?) on a single day, indexed by date 
	int _historyAgeInDaysLimit;
	int _historyItemLimit;
}

+ (WebHistory *) optionalSharedHistory;
+ (void) setOptionalSharedHistory:(WebHistory *) history;

- (void) addItems:(NSArray *) items;
- (int) historyAgeInDaysLimit;
- (int) historyItemLimit;
- (id) init;	// create empty web history
- (WebHistoryItem *) itemForURL:(NSURL *) url;
- (BOOL) loadFromURL:(NSURL *) url error:(NSError **) error;
- (NSArray *) orderedItemsLastVisitedOnDay:(NSCalendarDate *) date;
- (NSArray *) orderedLastVisitedDays;
- (void) removeAllItems;
- (void) removeItems:(NSArray *) items;
- (BOOL) saveToURL:(NSURL *) url error:(NSError **) error;
- (void) setHistoryAgeInDaysLimit:(int) limit;
- (void) setHistoryItemLimit:(int) limit;

@end
	
