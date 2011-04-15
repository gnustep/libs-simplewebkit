/* simplewebkit
   ECMAScriptPrototype.h

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

#import <Foundation/Foundation.h>
#import <WebKit/WebScriptObject.h>

// FIXME - all these objects should implement the WebScriptObject methods and KVC (representing _get, _put, _call etc.)

@interface _ConcreteWebScriptObject : WebScriptObject
{
	WebScriptObject *prototype;
	//	id value;	// do we need that?
	NSMutableDictionary *properties;
	NSMutableDictionary *attributes;	// an NSNumber object for each property containing WebScriptPropertyAttribute bits
}

@end

@interface _ConcreteWebScriptArray : _ConcreteWebScriptObject
// overrides _put method
@end

@interface _ConcreteWebScriptFunction : _ConcreteWebScriptObject

@end

@interface _ConcreteWebScriptString : _ConcreteWebScriptObject

@end
