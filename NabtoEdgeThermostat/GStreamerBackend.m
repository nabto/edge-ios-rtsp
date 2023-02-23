#import "GStreamerBackend.h"

#include <gst/gst.h>
#include <gst/video/video.h>

GST_DEBUG_CATEGORY(debug_category);
#define GST_CAT_DEFAULT debug_category

@interface GStreamerBackend()
-(void)setUIMessage:(gchar*) message;
-(void)app_main;
-(void)check_initialization_complete;
@end

@implementation GStreamerBackend
{
    id ui_delegate;
    GstElement* pipeline;
    GMainContext* context;
    GMainLoop* main_loop;
    gboolean initialized;
    
    GstElement* video_sink;
    UIView* video_view;
    GstState state;
    GstState target_state;
    gint64 duration;
    gint64 desired_position;
    GstClockTime last_seek_time;
    gboolean is_live;
}

-(id)init:(id)uiDelegate videoView:(UIView*)video_view
{
    if (self = [super init])
    {
        self->ui_delegate = uiDelegate;
        self->video_view = video_view;
        self->duration = GST_CLOCK_TIME_NONE;
        
        GST_DEBUG_CATEGORY_INIT(debug_category, "TunnelVideo", 0, "iOS Tunnel Video");
        gst_debug_set_threshold_for_name("TunnelVideo", GST_LEVEL_DEBUG);
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self app_main];
        });
    }
    
    return self;
}

-(void)destroy
{
    if (main_loop)
    {
        g_main_loop_quit(main_loop);
        main_loop = NULL;
    }
}

-(void)play
{
    target_state = GST_STATE_PLAYING;
    is_live = (gst_element_set_state(pipeline, target_state) == GST_STATE_CHANGE_NO_PREROLL);
}

-(void)pause
{
    target_state = GST_STATE_PAUSED;
    is_live = (gst_element_set_state(pipeline, target_state) == GST_STATE_CHANGE_NO_PREROLL);
}

-(void)setUri:(NSString*)uri
{
    const char* cstr = [uri UTF8String];
    g_object_set(pipeline, "uri", cstr, NULL);
}

-(void)setUIMessage:(gchar*)message
{
    NSString* string = [NSString stringWithUTF8String:message];
    if (ui_delegate && [ui_delegate respondsToSelector:@selector(gstreamerSetUIMessage:)])
    {
        [ui_delegate gstreamerSetUIMessage:string];
    }
}

static void seek(GStreamerBackend* self, gint64 desired_position)
{
    if (desired_position == GST_CLOCK_TIME_NONE) return;
    
    gint64 diff = (gint64)(gst_util_get_timestamp() - self->last_seek_time);
    if (!(GST_CLOCK_TIME_IS_VALID(self->last_seek_time) && diff < GST_SEEK_MIN))
    {
        GST_DEBUG("Seeking to %"GST_TIME_FORMAT, GST_TIME_ARGS(desired_position));
        self->last_seek_time = gst_util_get_timestamp();
        gst_element_seek_simple(self->pipeline, GST_FORMAT_TIME, GST_SEEK_FLAG_FLUSH | GST_SEEK_FLAG_KEY_UNIT, desired_position);
    }
}

static void pipeline_source_setup_callback(GstBus* bus, GstElement* source, GStreamerBackend* self)
{
    const gchar* source_name = g_type_name(G_TYPE_FROM_INSTANCE(G_OBJECT(source)));
    if (g_str_equal("GstRTSPSrc", source_name))
    {
        g_object_set(source, "latency", GST_RTSPSRC_LATENCY, NULL);
        g_object_set(source, "protocols", GST_RTSP_LOWER_TRANS_TCP, NULL);
    }
}

static void error_callback(GstBus* bus, GstMessage* msg, GStreamerBackend* self)
{
    GError* err;
    gchar* debug_info;
    
    gst_message_parse_error(msg, &err, &debug_info);
    GST_DEBUG("Error received from Gst element %s: %s", GST_OBJECT_NAME(msg->src), err->message);
    g_clear_error(&err);
    g_free(debug_info);
    gst_element_set_state(self->pipeline, GST_STATE_NULL);
}

static void end_of_stream_callback(GstBus* bus, GstMessage* msg, GStreamerBackend* self)
{
    self->target_state = GST_STATE_PAUSED;
    self->is_live = (gst_element_set_state(self->pipeline, GST_STATE_PAUSED) == GST_STATE_CHANGE_NO_PREROLL);
    seek(self, 0);
}

static void clock_lost_callback(GstBus* bus, GstMessage* msg, GStreamerBackend* self)
{
    if (self->target_state >= GST_STATE_PLAYING)
    {
        gst_element_set_state(self->pipeline, GST_STATE_PAUSED);
        gst_element_set_state(self->pipeline, GST_STATE_PLAYING);
    }
}

static void state_changed_callback(GstBus* bus, GstMessage* msg, GStreamerBackend* self)
{
    GstState old_state, new_state, pending_state;
    gst_message_parse_state_changed(msg, &old_state, &new_state, &pending_state);
    
    if (GST_MESSAGE_SRC(msg) == GST_OBJECT(self->pipeline))
    {
        GST_DEBUG("State changed from %s to %s", gst_element_state_get_name(old_state), gst_element_state_get_name(new_state));
    }
}

static void buffering_callback(GstBus* bus, GstMessage* msg, GStreamerBackend* self)
{
    if (self->is_live) return;
    
    gint percent;
    gst_message_parse_buffering(msg, &percent);
    if (percent < 100 && self->target_state >= GST_STATE_PAUSED)
    {
        GST_DEBUG("Buffering %d%%", percent);
        gst_element_set_state(self->pipeline, GST_STATE_PAUSED);
    }
    else if (self->target_state >= GST_STATE_PLAYING)
    {
        gst_element_set_state(self->pipeline, GST_STATE_PLAYING);
    }
}

-(void)check_initialization_complete
{
    if (!initialized && video_view && main_loop)
    {
        GST_DEBUG("Initialization complete, notifying application.");
        gst_video_overlay_set_window_handle(GST_VIDEO_OVERLAY(pipeline), (guintptr)(id)video_view);
        if (ui_delegate && [ui_delegate respondsToSelector:@selector(gstreamerInitialized)])
        {
            [ui_delegate gstreamerInitialized];
        }
        initialized = TRUE;
    }
}

-(void)app_main
{
    GstBus* bus;
    GSource* bus_source;
    GError* error = NULL;
    void* udata = (__bridge void*)self;
    
    GST_DEBUG("Creating pipeline.");
    
    context = g_main_context_new();
    g_main_context_push_thread_default(context);
    
    pipeline = gst_parse_launch("playbin3", &error);
    if (error)
    {
        GST_ERROR("Unable to build pipeline: %s", error->message);
        g_clear_error(&error);
        return;
    }
    
    g_signal_connect(pipeline, "source-setup", G_CALLBACK(pipeline_source_setup_callback), udata);
    
    target_state = GST_STATE_READY;
    gst_element_set_state(pipeline, target_state);
    
    bus = gst_element_get_bus(pipeline);
    bus_source = gst_bus_create_watch(bus);
    g_source_set_callback(bus_source, (GSourceFunc)gst_bus_async_signal_func, NULL, NULL);
    g_source_attach(bus_source, context);
    g_source_unref(bus_source);
    
    GObject* bus_obj = G_OBJECT(bus);
    g_signal_connect(bus_obj, "message::error",         G_CALLBACK(error_callback), udata);
    g_signal_connect(bus_obj, "message::state-changed", G_CALLBACK(state_changed_callback), udata);
    g_signal_connect(bus_obj, "message::eos",           G_CALLBACK(end_of_stream_callback), udata);
    g_signal_connect(bus_obj, "message::buffering",     G_CALLBACK(buffering_callback), udata),
    g_signal_connect(bus_obj, "message::clock-lost",    G_CALLBACK(clock_lost_callback), udata);
    gst_object_unref(bus);
    
    GST_DEBUG("Entering main loop.");
    main_loop = g_main_loop_new(context, FALSE);
    [self check_initialization_complete];
    g_main_loop_run(main_loop);
    GST_DEBUG("Exited main loop");
    g_main_loop_unref(main_loop);
    main_loop = NULL;
    
    g_main_context_pop_thread_default(context);
    g_main_context_unref(context);
    gst_element_set_state(pipeline, GST_STATE_NULL);
    gst_object_unref (pipeline);
}

-(NSString*) getGStreamerVersion
{
    char *version_utf8 = gst_version_string();
    NSString *version_string = [NSString stringWithUTF8String:version_utf8];
    g_free(version_utf8);
    return version_string;
}

@end
