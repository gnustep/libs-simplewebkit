/* simplewebkit
   WebHistory.h

   Copyright (C) 2007 Free Software Foundation, Inc.

   Author: Dr. H. Nikolaus Schaller

   This file is part of the GNUstep Simple Webkit.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
*/

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
	
