/* simplewebkit
   WebFrameView.h

   Copyright (C) 2007-2010 Free Software Foundation, Inc.

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
#import <AppKit/NSView.h>
#import <WebKit/WebDocument.h>

@class WebFrame;

@interface WebFrameView : NSView
{
	WebFrame *_webFrame;		// the frame we are asked to display
}

// The only subview of this WebFrameView is a NSScrollView (if we allow scrolling).
// The elements to be displayed are laid out properly in the subviews of that scroll view.
// They can be e.g. NSTextView, NSPopUpButton, NSTextField, NSButton, or another WebFrameView depending
// on the tags found in the HTML source


- (BOOL) allowsScrolling;
- (NSView *) documentView;
- (WebFrame *) webFrame;
- (void) setAllowsScrolling:(BOOL) flag;
- (void) _setDocumentView:(NSView /* <WebDocumentView> */ *) view;
- (void) _setWebFrame:(WebFrame *) wframe;

@end
