//
//  WebPlugIn.h
//  mySTEP
//
//  Created by Dr. H. Nikolaus Schaller on Tue May 16 2006.
//  Copyright (c) 2006 DSITRI. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSObject (WebPlugIn)
- (id) objectForWebScript;
- (void) webPlugInDestroy;
- (void) webPlugInInitialize;
- (void) webPlugInSetIsSelected:(BOOL) flag;
- (void) webPlugInStart;
- (void) webPlugInStop;
@end
