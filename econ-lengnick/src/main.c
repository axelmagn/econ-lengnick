// Enable POSIX.1-2008 API functions (e.g. clock_gettime) when compiling with
// strict -std=c99
#define _POSIX_C_SOURCE 200809L

#include <math.h>
#include <stdint.h>
#include <stdlib.h>

#if defined(__EMSCRIPTEN__)
#define SOKOL_GLES3
#elif defined(_WIN32)
#define SOKOL_D3D11
#elif defined(__APPLE__)
#define SOKOL_METAL
#elif defined(__linux__)
#define SOKOL_GLCORE
#endif

#define SOKOL_IMPL
#include "sokol_app.h"
#include "sokol_gfx.h"
#include "sokol_glue.h"
#include "sokol_log.h"
#include "util/sokol_framebuffer.h"
#include "util/sokol_letterbox.h"

// include generated shaders file
// #include "shaders/triangle.glsl.h"

// Include Nuklear UI single-header library
#define NK_INCLUDE_FIXED_TYPES
#define NK_INCLUDE_STANDARD_IO
#define NK_INCLUDE_DEFAULT_ALLOCATOR
#define NK_INCLUDE_VERTEX_BUFFER_OUTPUT
#define NK_INCLUDE_FONT_BAKING
#define NK_INCLUDE_DEFAULT_FONT
#define NK_IMPLEMENTATION
#include "nuklear.h"

#define SOKOL_NUKLEAR_IMPL
#include "util/sokol_nuklear.h"

// ============================================================================
//
// CONSTANTS
//
// ============================================================================

#define WORLD_SIZE_X (128)
#define WORLD_SIZE_Y (128)

#define LIL_GUYS_MAX (16)

// ============================================================================
//
// MACROS
//
// ============================================================================

// ============================================================================
//
// TYPES
//
// ============================================================================

typedef struct {
  uint8_t a;
  uint8_t b;
  uint8_t g;
  uint8_t r;
} rgba_t;

typedef struct {
  size_t world_x;
  size_t world_y;
  rgba_t color;
} lil_guy_t;

static struct {
  // simulated model
  struct {
    int lil_guys_count;
    lil_guy_t lil_guys[LIL_GUYS_MAX];
  } model;

  // graphics context
  struct {
    sg_pass_action pass_action;
    sg_color bg_color;
    sfb_framebuffer framebuffer;
    uint32_t pixels[WORLD_SIZE_X][WORLD_SIZE_Y];
    float fade_speed;
  } gfx;
} state;

// ============================================================================
//
// FORWARD DECLARATIONS
//
// ============================================================================

rgba_t rgba_blend(rgba_t color1, rgba_t color2, float t);
rgba_t uint32_to_rgba(uint32_t color);
rgba_t sg_color_to_rgba(sg_color color);
uint32_t rgba_to_uint32(rgba_t color);

// ============================================================================
//
// IMPLEMENTATIONS
//
// ============================================================================

static void init(void) {
  printf("init started!\n");
  srand(time(NULL));

  sg_setup(&(sg_desc){
      .environment = sglue_environment(),
      .logger.func = slog_func,
  });

  snk_setup(&(snk_desc_t){
      .dpi_scale = sapp_dpi_scale(),
      .logger.func = slog_func,
      .enable_set_mouse_cursor = true,
  });

  sfb_setup(&(sfb_desc){
      .logger.func = slog_func,
  });

  state.gfx.bg_color.r = 0.1f;
  state.gfx.bg_color.g = 0.1f;
  state.gfx.bg_color.b = 0.12f;
  state.gfx.bg_color.a = 1.0f;

  state.gfx.fade_speed = 1.0;

  // init lil guys
  state.model.lil_guys_count = 4;
  for (int i = 0; i < LIL_GUYS_MAX; i++) {
    lil_guy_t *guy = &state.model.lil_guys[i];

    guy->world_x = rand() % WORLD_SIZE_X;
    guy->world_y = rand() % WORLD_SIZE_Y;

    uint8_t r = rand();
    uint8_t g = rand();
    uint8_t b = rand();
    uint8_t max_rgb = r > g ? r : g;
    max_rgb = b > max_rgb ? b : max_rgb;
    float scale = 255.0f / max_rgb;
    guy->color.a = 0xFF;
    guy->color.r = (uint8_t)(r * scale);
    guy->color.g = (uint8_t)(g * scale);
    guy->color.b = (uint8_t)(b * scale);
  }

  // Pass action setup
  state.gfx.pass_action =
      (sg_pass_action){.colors[0] = {
                           .load_action = SG_LOADACTION_CLEAR,
                           .clear_value = state.gfx.bg_color,
                       }};

  state.gfx.framebuffer = sfb_make_framebuffer(&(sfb_framebuffer_desc){
      .width = WORLD_SIZE_X,
      .height = WORLD_SIZE_Y,
      .format = SFB_FORMAT_RGBA8,
      .prescale = 8,
  });

  uint32_t bg_color = rgba_to_uint32(sg_color_to_rgba(state.gfx.bg_color));
  memset(&state.gfx.pixels, bg_color,
         sizeof(uint32_t) * WORLD_SIZE_X * WORLD_SIZE_Y);

  printf("init completed!\n");
}

static void frame(void) {
  // update lil guy
  // state.lil_dude_x =
  //     (state.lil_dude_x + WORLD_SIZE_X + (rand() % 3) - 1) % WORLD_SIZE_X;
  // state.lil_dude_y =
  //     (state.lil_dude_y + WORLD_SIZE_Y + (rand() % 3) - 1) % WORLD_SIZE_Y;

  // update lil guys
  for (int i = 0; i < state.model.lil_guys_count; i++) {
    lil_guy_t *guy = &state.model.lil_guys[i];
    guy->world_x =
        (guy->world_x + WORLD_SIZE_X + (rand() % 3) - 1) % WORLD_SIZE_X;
    guy->world_y =
        (guy->world_y + WORLD_SIZE_Y + (rand() % 3) - 1) % WORLD_SIZE_Y;
  }

  // update pixels
  double dt = sapp_frame_duration();

  for (int x = 0; x < WORLD_SIZE_X; x++) {
    for (int y = 0; y < WORLD_SIZE_Y; y++) {
      rgba_t pixel = uint32_to_rgba(state.gfx.pixels[x][y]);
      rgba_t bg_color = sg_color_to_rgba(state.gfx.bg_color);
      pixel = rgba_blend(pixel, bg_color, dt * state.gfx.fade_speed);
      state.gfx.pixels[x][y] = rgba_to_uint32(pixel);
    }
  }

  for (int i = 0; i < state.model.lil_guys_count; i++) {
    lil_guy_t *guy = &state.model.lil_guys[i];
    state.gfx.pixels[guy->world_x][guy->world_y] = rgba_to_uint32(guy->color);
  }

  // Build Nuklear UI
  struct nk_context *ctx = snk_new_frame();

  nk_style_hide_cursor(ctx);

  if (nk_begin(ctx, "Parameters", nk_rect(0, 0, 260, 240),
               NK_WINDOW_BORDER | NK_WINDOW_MOVABLE | NK_WINDOW_SCALABLE |
                   NK_WINDOW_MINIMIZABLE | NK_WINDOW_TITLE)) {

    nk_layout_row_dynamic(ctx, 25, 1);
    nk_property_int(ctx, "Lil Guys:", 0, &state.model.lil_guys_count,
                    LIL_GUYS_MAX, 1, 0.005f);

    nk_layout_row_dynamic(ctx, 25, 1);
    nk_label(ctx, "Background Clear Color:", NK_TEXT_LEFT);

    nk_layout_row_dynamic(ctx, 25, 1);
    nk_property_float(ctx, "Red:", 0.0f, &state.gfx.bg_color.r, 1.0f, 0.01f,
                      0.005f);
    nk_property_float(ctx, "Green:", 0.0f, &state.gfx.bg_color.g, 1.0f, 0.01f,
                      0.005f);
    nk_property_float(ctx, "Blue:", 0.0f, &state.gfx.bg_color.b, 1.0f, 0.01f,
                      0.005f);

    nk_layout_row_dynamic(ctx, 30, 1);
    if (nk_button_label(ctx, "Reset Background")) {
      state.gfx.bg_color.r = 0.1f;
      state.gfx.bg_color.g = 0.1f;
      state.gfx.bg_color.b = 0.12f;
    }
  }
  nk_end(ctx);

  // blit pixels to framebuffer
  sfb_update(state.gfx.framebuffer, &(sfb_update_desc){
                                        .pixels = SG_RANGE(state.gfx.pixels),
                                    });

  // Update clear color
  state.gfx.pass_action.colors[0].clear_value = state.gfx.bg_color;

  // Begin render pass
  sg_begin_pass(&(sg_pass){.action = state.gfx.pass_action,
                           .swapchain = sglue_swapchain()});

  // render framebuffer
  slbx_viewport vp = slbx_letterbox(sapp_width(), sapp_height(),
                                    &(slbx_letterbox_desc){
                                        .content_aspect_ratio = 1.0f,
                                    });
  sg_apply_viewport(vp.x, vp.y, vp.width, vp.height, true);
  // sfb_render(state.gfx.framebuffer);
  sfb_render_ex(state.gfx.framebuffer, &(sfb_render_desc){});

  // Draw triangle
  // sg_apply_pipeline(state.pip);
  // sg_apply_bindings(&state.bind);
  // sg_draw(0, 3, 1);

  // Draw Nuklear UI on top
  snk_render(sapp_width(), sapp_height());

  sg_end_pass();
  sg_commit();
}

static void event(const sapp_event *ev) { snk_handle_event(ev); }

static void cleanup(void) {
  snk_shutdown();
  sg_shutdown();
}

sapp_desc sokol_main(int argc, char *argv[]) {
  (void)argc;
  (void)argv;
  return (sapp_desc){
      .init_cb = init,
      .frame_cb = frame,
      .event_cb = event,
      .cleanup_cb = cleanup,
      .width = 800,
      .height = 600,
      .high_dpi = true,
      .window_title = "Sokol Triangle + Nuklear Starter",
      .icon.sokol_default = true,
      .logger.func = slog_func,
  };
}

rgba_t rgba_blend(rgba_t color1, rgba_t color2, float t) {
  rgba_t result = {
      .r = (uint8_t)(color1.r + (color2.r - color1.r) * t),
      .g = (uint8_t)(color1.g + (color2.g - color1.g) * t),
      .b = (uint8_t)(color1.b + (color2.b - color1.b) * t),
      .a = (uint8_t)(color1.a + (color2.a - color1.a) * t),
  };
  return result;
}

rgba_t uint32_to_rgba(uint32_t color) {
  rgba_t result;
  result.a = (0xFF000000 & color) >> 24;
  result.b = (0x00FF0000 & color) >> 16;
  result.g = (0x0000FF00 & color) >> 8;
  result.r = (0x000000FF & color) >> 0;
  return result;
}

rgba_t sg_color_to_rgba(sg_color color) {
  rgba_t result;
  result.a = (uint8_t)(0xFF * color.a);
  result.r = (uint8_t)(0xFF * color.r);
  result.g = (uint8_t)(0xFF * color.g);
  result.b = (uint8_t)(0xFF * color.b);
  return result;
}

uint32_t rgba_to_uint32(rgba_t color) {
  return (color.a << 24) | (color.b << 16) | (color.g << 8) | color.r;
}
