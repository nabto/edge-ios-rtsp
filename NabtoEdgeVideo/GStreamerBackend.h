#import <Foundation/Foundation.h>
#import "GStreamerBackendDelegate.h"
#import <UIKit/UIKit.h>

#define GST_SEEK_MIN (500 * GST_MSECOND)
#define GST_RTSPSRC_LATENCY 200

typedef enum GstRTSPLowerTrans
{
    GST_RTSP_LOWER_TRANS_UNKNOWN   = 0,
    GST_RTSP_LOWER_TRANS_UDP       = 1 << 0,
    GST_RTSP_LOWER_TRANS_UDP_MCAST = 1 << 1,
    GST_RTSP_LOWER_TRANS_TCP       = 1 << 2,
    GST_RTSP_LOWER_TRANS_HTTP      = 1 << 3,
    GST_RTSP_LOWER_TRANS_TLS       = 1 << 4
} GstRTSPLowerTrans;

@interface GStreamerBackend : NSObject

-(NSString*)getGStreamerVersion;

-(id)init:(id)uiDelegate videoView:(UIView*)video_view;

-(void)destroy;

-(void)play;

-(void)pause;

-(void)setUri:(NSString*)uri;

@end
