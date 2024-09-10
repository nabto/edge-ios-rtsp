//
//  GStreamerBackendDelegate.h
//  Nabto Edge Video
//
//  Created by Ahmad Saleh on 16/02/2023.
//  Copyright © 2023 Nabto. All rights reserved.
//

#ifndef GStreamerBackendDelegate_h
#define GStreamerBackendDelegate_h

#import <Foundation/Foundation.h>
#include "GStreamerBackend.h"
#include "GStreamerBackendError.h"

@protocol GStreamerBackendDelegate <NSObject>

@optional
/* Called when the GStreamer backend has finished initializing
 * and is ready to accept orders. */
-(void) onInitialized;
-(void) onError:(GstBackendError)errorCode message:(NSString *)message;
-(void) onBuffering;
-(void) onBufferingDone;
@end

#endif /* GStreamerBackendDelegate_h */
