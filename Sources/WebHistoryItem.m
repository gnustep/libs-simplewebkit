/* simplewebkit
   WebHistoryItem.m

   Copyright (C) 2007 Free Software Foundation, Inc.

   Author: Dr. H. Nikolaus Schaller

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

#import "Private.h"
#import <WebKit/WebHistoryItem.h>

NSString *WebHistoryItemChangedNotification=@"WebHistoryItemChangedNotification";

@implementation WebHistoryItem

- (void) _notify; { [[NSNotificationCenter defaultCenter] postNotificationName:WebHistoryItemChangedNotification object:self]; }
- (void) _touch; { _lastVisitedTimeInterval=[NSDate timeIntervalSinceReferenceDate]; _visitCount++; }
- (void) _setIcon:(NSImage *) icon; { ASSIGN(_icon, icon); [self _notify]; }
- (void) _setURL:(NSURL *) url; { ASSIGN(_URLString, [url absoluteString]); [self _notify]; }
- (int) _visitCount; { return _visitCount; }
- (void) _setVisitCount:(int) v; { _visitCount=v; }

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
	if((c=[[WebHistoryItem allocWithZone:zone] init]))
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

- (BOOL) isEqual:(id) o
{
	WebHistoryItem *other=(WebHistoryItem *) o;
	if(o == self)
		return YES;
	return [_URLString isEqualToString:other->_URLString];
}

@end
