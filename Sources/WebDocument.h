/* simplewebkit
   WebDocument.h

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
#import <AppKit/NSWindow.h>

@class WebDataSource;

@protocol WebDocumentRepresentation
- (BOOL) canProvideDocumentSource;
- (NSString *) documentSource;
- (void) finishedLoadingWithDataSource:(WebDataSource *) source;
- (void) receivedData:(NSData *) data withDataSource:(WebDataSource *) source;
- (void) receivedError:(NSError *) error withDataSource:(WebDataSource *) source;
- (void) setDataSource:(WebDataSource *) dataSource;
- (NSString *) title;
@end

@protocol WebDocumentSearching
- (BOOL) searchFor:(NSString *) string
		 direction:(BOOL) direction
	 caseSensitive:(BOOL) flag
			  wrap:(BOOL) wrap;
@end

@protocol WebDocumentText
- (NSAttributedString *) attributedString;
- (void) deselectAll;
- (void) selectAll;
- (NSAttributedString *) selectedAttributedString;
- (NSString *) selectedString;
- (NSString *) string;
- (BOOL) supportsTextEncoding;
@end

@protocol WebDocumentView
- (void) dataSourceUpdated:(WebDataSource *) source;
- (void) layout;
- (void) setDataSource:(WebDataSource *) source;
- (void) setNeedsLayout:(BOOL) flag;
- (void) viewDidMoveToHostWindow;
- (void) viewWillMoveToHostWindow:(NSWindow *) win;
@end
