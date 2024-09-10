//
//  GStreamerBackendError.h
//  NabtoEdgeVideo
//
//  Created by Ulrik Gammelby on 10/09/2024.
//  Copyright © 2024 Nabto. All rights reserved.
//

#ifndef GStreamerBackendError_h
#define GStreamerBackendError_h

typedef NS_ENUM(NSInteger, GstBackendError) {
    GstNotFound      = 1,
    GstNotAuthorized = 2,
    GstWrongDomain   = 3,
    GstOther         = 9999
};

#endif /* GStreamerBackendError_h */
