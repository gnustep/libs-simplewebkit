//
//  WebPreferences.h
//  SimpleWebKit
//
//  Created by H. Nikolaus Schaller on 18.11.07.
//  Copyright 2007 Golden Delicious Computers GmbH&Co. KG. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface WebPreferences : NSObject	// this is a proxy into NSUserDefaults
{
	NSMutableDictionary *_dict;
	NSString *_identifier;
	BOOL _autosaves;
}

+ (WebPreferences *) standardPreferences;

- (BOOL) autosaves;
- (NSString *) defaultTextEncodingName;
- (NSString *) identifier;
- (id) initWithIdentifier:(NSString *) ident;
- (void) setAutosaves:(BOOL) flag;

@end

extern NSString *WebPreferencesChangedNotification;
