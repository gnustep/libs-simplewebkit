/* simplewebkit
   DOMCSS.m

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

#import <WebKit/WebView.h>
#import "Private.h"

/*
 we need a mechanism to look up the database for a given DOM-Tree node (selectors)
 (taking the hierarchy into account) and return a NSDictionary with the
 styles as needed for an attributed string
 so we must translate some of the CSS attribute names to NSxxxAttributeName, e.g.
 background-color -> NSBackgroundAttributeName
 color -> NSTextColorAttibuteName
 
 and the original CSS attribute value should also be available for building an element inspector (?)
 */

/*
 
 TODO:
 
 look at http://svn.gna.org/viewcvs/etoile/trunk/Etoile/Services/User/Jabber/ETXML/ETXMLXHTML-IMParser.m?rev=2495&view=auto
 
 what we can (re)use

 */

@implementation DOMStyleSheet

@end

@implementation DOMStyleSheetList

@end

@implementation DOMCSSMediaList

@end

// OLD

@implementation DOMCSSStyleDeclaration

- (id) initWithString:(NSString *) style forDocument:(RENAME(DOMDocument) *) doc;
{ // for <style>css</style> or <tag style="css">
	if((self=[super init]))
		{
		NSScanner *sc=[NSScanner scannerWithString:style];
		// parse style string...
		}
	return self;
}

@end


