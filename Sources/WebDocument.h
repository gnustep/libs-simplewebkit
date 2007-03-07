//
//  WebDocument.h
//  mySTEP
//
//  Created by Dr. H. Nikolaus Schaller on Tue Sep 01 2005.
//  Copyright (c) 2005 DSITRI. All rights reserved.
//

#import <Cocoa/Cocoa.h>

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
