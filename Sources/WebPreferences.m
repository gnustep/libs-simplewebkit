//
//  WebPreferences.m
//  SimpleWebKit
//
//  Created by H. Nikolaus Schaller on 18.11.07.
//  Copyright 2007 Golden Delicious Computers GmbH&Co. KG. All rights reserved.
//

#import "WebPreferences.h"
#import "Private.h"

NSString *WebPreferencesChangedNotification=@"WebPreferencesChangedNotification";

static NSString *PREF_DOMAIN=@"com.quantum-step.WebKit.WebPreferences";

@implementation WebPreferences

+ (WebPreferences *) standardPreferences;
{
	static WebPreferences *prefs;
	if(!prefs)
		{
		prefs=[[self alloc] initWithIdentifier:@"standardPreferences"];
		[prefs setAutosaves:YES];
		}
	return prefs;
}

- (id) init; { return [self initWithIdentifier:@""]; }

- (id) initWithIdentifier:(NSString *) ident
{
	if((self=[super init]))
		{
		_identifier=[ident retain];
		_dict=[[[NSUserDefaults standardUserDefaults] persistentDomainForName:PREF_DOMAIN] mutableCopy];
		}
	return self;
}

- (void) dealloc;
{
	[_identifier release];
	[_dict release];
	[super dealloc];
}

- (NSString *) identifier; { return _identifier; }

- (BOOL) autosaves; { return _autosaves; }
- (void) setAutosaves:(BOOL) flag; { _autosaves=flag; }

// FIXME: we need to carry a local copy!

- (void) setValue:(id) val forKey:(NSString *) key;
{ // set value
	if(val)
		[_dict setObject:val forKey:key];
	else
		[_dict removeObjectForKey:key];
	if(_autosaves)
		[[NSUserDefaults standardUserDefaults] setPersistentDomain:_dict forName:PREF_DOMAIN];
	// send WebPreferencesChangedNotification notification
}

#define STRING_GETTER(NAME, KEY) - (NSString *) NAME; { return [_dict objectForKey:KEY]; }
#define BOOL_GETTER(NAME, KEY) - (NSString *) NAME; { return [[_dict objectForKey:KEY] boolValue]; }
#define INT_GETTER(NAME, KEY) - (NSString *) NAME; { return [[_dict objectForKey:KEY] intValue]; }
#define STRING_SETTER(NAME, KEY) - (void) NAME:(NSString *) val; { return [self setValue:val forKey:KEY]; }
#define BOOL_SETTER(NAME, KEY) - (void) NAME:(BOOL) val; { return [self setValue:[NSNumber numberWithBool:val] forKey:KEY]; }
#define INT_SETTER(NAME, KEY) - (void) NAME:(int) val; { return [self setValue:[NSNumber numberWithInt:val] forKey:KEY]; }

STRING_GETTER(defaultTextEncodingName, @"TextEncoding");
STRING_SETTER(setDefaultTextEncodingName, @"TextEncoding");

- (void) encodeWithCoder:(NSCoder *) coder;
{
	NIMP;
}

- (id) initWithCoder:(NSCoder *) coder;
{
}

@end
