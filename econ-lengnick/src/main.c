// Enable POSIX.1-2008 API functions (e.g. clock_gettime) when compiling with
// strict -std=c99
#define _POSIX_C_SOURCE 200809L

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

#define THINGS_MAX (8192)
#define EVENTS_MAX (1024)

// ============================================================================
//
// TYPES
//
// ============================================================================

typedef uint64_t currency_t;
typedef uint64_t amount_t;
typedef uint16_t coord_t;
typedef size_t thing_id_t;

typedef enum {
  // collection occupancy
  // not needed since things are never destroyed during a run (only on reset)
  // FLAG_USED = (1 << 0),

  // kind
  FLAG_FIRM = (1 << 1),
  FLAG_HOUSEHOLD = (1 << 2),

  // bools
  FLAG_OPEN_POSITION = (1 << 3),
} thing_flag_t;

typedef struct {
  uint8_t flags;
  /// amount of money the thing possesses
  currency_t liquidity;
  /// amount of goods demand (felt for households, observed for firms)
  amount_t current_demand;

  /// coordinates on the world map
  coord_t world_x;
  coord_t world_y;

  union {
    struct {
      thing_id_t employer;
      currency_t reservation_wage;
    } household;
    struct {
      /// the price of each item in the inventory
      currency_t goods_price;
      /// the price the firm will pay for labor power
      currency_t wage_rate;
      /// amount of goods on hand
      amount_t inventory;
      currency_t monthly_revenue;
      amount_t months_since_hire_failure;
      thing_id_t worker_on_notice;
    } firm;
  } kind;
} thing_t;

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

// ============================================================================
//
// STATIC DATA
//
// ============================================================================

static struct {
  // simulated model
  struct {
    size_t steps;

    size_t things_len;
    thing_t things[THINGS_MAX];

  } model;

  struct {
    thing_id_t occupancy[WORLD_SIZE_X][WORLD_SIZE_Y];
  } cache;

  // graphics context
  struct {
    sg_pass_action pass_action;
    sg_color bg_color;
    sfb_framebuffer framebuffer;
    uint32_t pixels[WORLD_SIZE_X][WORLD_SIZE_Y];
    float fade_speed;
  } gfx;
} state = {
    .gfx.bg_color.r = 0.1,
    .gfx.bg_color.g = 0.1,
    .gfx.bg_color.b = 0.12,
    .gfx.bg_color.a = 1.0,

    .gfx.fade_speed = 1.0,
};

static struct {
  struct {
    float labor_supply;
    uint8_t month_length;
  } model;

  struct {
    size_t count;
    uint32_t color;
    /// amount of liquidity assigned to each household at t=0
    currency_t init_liquidity;
    /// reservation wage assigned to each household at t=0
    currency_t init_reservation_wage;
    /// unemployed reservation wage decay rate
    float unemployed_wage_decay_rate;
    /// Fraction of demand supplied that will satisfy the household desire
    float satisfaction_fraction;
    /// decay rate for consumption expenditure function (alpha)
    /// in the range 0 < alpha < 1
    float consumption_expenditure_decay;
    /// probability of searching for new work, if employed (pi)
    float employed_search_probability;
    /// fraction a new firms price has to be less than the old firm before the
    /// new firm will be picked (zeta)
    float price_switching_threshold;
    /// probability of looking for firm with cheaper prices
    float price_switching_prob;
    /// probability of replacing a firm that fails to supply
    float quant_switching_prob;
    /// how far around their position the household can see when searching
    float visibility_radius;
  } household;

  struct {
    size_t count;
    uint32_t color;
    /// amount of liquidity assigned to each firm at t=0
    currency_t init_liquidity;
    /// price of goods at each firm at t=0
    currency_t init_goods_price;
    /// amount of inventory in each firm at t=0
    amount_t init_inventory;
    /// initial wage rate at t=0
    currency_t init_wage_rate;
    /// the expected demand for goods per month
    amount_t expected_demand;
    /// number of months of filled positions before wage will be reduced (gamma)
    amount_t wage_reduction_months;
    /// upper bound for the wage adjustments (delta)
    float wage_adjustment_upper;
    /// range that inventories can be mantained relative to demand
    float inventory_phi_upper;
    float inventory_phi_lower;
    /// range that prices can be marked up over costs
    float price_phi_upper;
    float price_phi_lower;
    /// upper bound for the price adjustment (upsilon)
    float price_adjustment_upper;
    /// probability of changing the goods price (theta)
    float price_adjustment_prob;
    /// productivity multiple by which labor power is turned into labor output
    /// (lambda)
    float productivity_multiple;
    /// percentage of income to reserve to cover bad times (chi)
    float reserved_income_multiple;
  } firm;
} config = {
    .household =
        {
            .count = 128,
            .color = (0xFF << 24) | (0xFF << 16) | (0xFF << 8) | 0x00,
            .init_liquidity = 100000,
            .unemployed_wage_decay_rate = 0.9f,
            .satisfaction_fraction = 0.95f,
            .consumption_expenditure_decay = 0.9f,
            .employed_search_probability = 0.1f,
            .price_switching_threshold = 0.01f,
            .price_switching_prob = 0.25f,
            .quant_switching_prob = 0.25f,
            .visibility_radius = 8,
        },

    .firm =
        {
            .count = 32,
            .color = (0xFF << 24) | (0xFF << 16) | (0x00 << 8) | 0xFF,
            .init_liquidity = 400000,
            .init_goods_price = 1000,
            .init_inventory = 0,
            .init_wage_rate = 100000,
            .expected_demand = 1,
            .wage_reduction_months = 24,
            .wage_adjustment_upper = 0.019,
            .inventory_phi_upper = 1.0,
            .inventory_phi_lower = 1.025,
            .price_phi_upper = 1.15,
            .price_phi_lower = 1.025,
            .price_adjustment_upper = 0.02,
            .price_adjustment_prob = 0.75,
            .productivity_multiple = 3.0,
            .reserved_income_multiple = 0.1,
        },
};

// ============================================================================
//
// FORWARD DECLARATIONS
//
// ============================================================================

// gfx
static void gfx_init();
static void gfx_framebuffer_render();

// gui
static void gui_update();

// model
static void model_reset();
static void model_tick();

// things
static void things_draw();
static void thing_move_to(thing_id_t thing_id, size_t x, size_t y);
static void thing_try_move_to(thing_id_t thing_id, size_t x, size_t y);
static void thing_try_random_move(thing_id_t thing_id);
static void things_validate_occupancy();

// firms
static void firms_init();
static void firms_update();

// households
static void households_init();

// config
static float config_marginal_cost_deflator();

// colors
static rgba_t rgba_blend(rgba_t color1, rgba_t color2, float t);
static rgba_t uint32_to_rgba(uint32_t color);
static rgba_t sg_color_to_rgba(sg_color color);
static uint32_t rgba_to_uint32(rgba_t color);
static double rand_uniform(double min, double max);

// ============================================================================
//
// IMPLEMENTATIONS
//
// ============================================================================

// ----------------------------------------------------------------------------
// Sokol Entrypoints
// ----------------------------------------------------------------------------

static void init(void) {
  // srand(time(NULL));
  srand(42);
  gfx_init();
  model_reset();
}

static void frame() {
  printf("frame\n");
  model_tick();

  gui_update();

  things_draw();

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
  gfx_framebuffer_render();

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
      .window_title = "Econ Lengnick",
      .icon.sokol_default = true,
      .logger.func = slog_func,
  };
}

// ----------------------------------------------------------------------------
// GFX
// ----------------------------------------------------------------------------

static void gfx_init() {
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
}

/// render framebuffer
static void gfx_framebuffer_render() {
  // framebuffer should be letterboxed
  slbx_viewport vp = slbx_letterbox(sapp_width(), sapp_height(),
                                    &(slbx_letterbox_desc){
                                        .content_aspect_ratio = 1.0f,
                                    });
  sg_apply_viewport(vp.x, vp.y, vp.width, vp.height, true);
  sfb_render(state.gfx.framebuffer);
}
// ----------------------------------------------------------------------------
// GUI
// ----------------------------------------------------------------------------
static void gui_update() {
  struct nk_context *ctx = snk_new_frame();

  nk_style_hide_cursor(ctx);

  if (nk_begin(ctx, "Parameters", nk_rect(0, 0, 260, 240),
               NK_WINDOW_BORDER | NK_WINDOW_MOVABLE | NK_WINDOW_SCALABLE |
                   NK_WINDOW_MINIMIZABLE | NK_WINDOW_TITLE)) {

    // nk_layout_row_dynamic(ctx, 25, 1);
    // nk_property_int(ctx, "Lil Guys:", 0, &state.model.lil_guys_count,
    //                 LIL_GUYS_MAX, 1, 0.005f);

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
  if (nk_begin(ctx, "Statisics", nk_rect(290, 0, 260, 240),
               NK_WINDOW_BORDER | NK_WINDOW_MOVABLE | NK_WINDOW_SCALABLE |
                   NK_WINDOW_MINIMIZABLE | NK_WINDOW_TITLE)) {
  }
  nk_end(ctx);
}

// ----------------------------------------------------------------------------
// Model
// ----------------------------------------------------------------------------
static void model_reset() {
  // zeroth thing is always zeroed
  state.model.things_len = 1;
  state.model.things[0] = (thing_t){0};
  memset(&state.cache.occupancy, 0,
         sizeof(thing_id_t) * WORLD_SIZE_X * WORLD_SIZE_Y);

  firms_init();
  households_init();
  things_validate_occupancy();
}

static void model_tick() {
  printf("model_tick 01\n");

  // tmp
  things_validate_occupancy();

  // if (state.model.steps % config.model.month_length == 0) {
  //   // TODO: month start
  // } else if ((state.model.steps + 1) % config.model.month_length == 0) {
  //   // TODO: month end
  // }

  // TODO: day tick

  // TODO: log stats

  // TEMP: move households around constantly
  printf("model_tick 02\n");
  for (int i = 0; i < state.model.things_len; i++) {
    thing_t *thing = &state.model.things[i];
    if (thing->flags & FLAG_HOUSEHOLD) {
      thing_try_random_move(i);
    }
  }

  state.model.steps++;
  things_validate_occupancy();
}

// ----------------------------------------------------------------------------
// Things
// ----------------------------------------------------------------------------
static void things_draw() {
  memset(&state.gfx.pixels, 0, sizeof(uint32_t) * WORLD_SIZE_X * WORLD_SIZE_Y);
  for (int i = 0; i < state.model.things_len; i++) {
    thing_t *thing = &state.model.things[i];
    size_t x = thing->world_x;
    size_t y = thing->world_y;
    if (thing->flags & FLAG_FIRM) {
      state.gfx.pixels[x][y] = config.firm.color;
    } else if (thing->flags & FLAG_HOUSEHOLD) {
      state.gfx.pixels[x][y] = config.household.color;
    }
  }
}

static void thing_move_to(thing_id_t thing_id, size_t x, size_t y) {
  printf("[debug] moving thing (%zu) to (%zu, %zu)\n", thing_id, x, y);
  assert(thing_id > 0);
  assert(thing_id < state.model.things_len);
  assert(x < WORLD_SIZE_X);
  assert(y < WORLD_SIZE_Y);
  assert(state.cache.occupancy[x][y] == 0);
  thing_t *thing = &state.model.things[thing_id];
  assert(state.cache.occupancy[thing->world_x][thing->world_y] == thing_id);
  state.cache.occupancy[thing->world_x][thing->world_y] = 0;
  thing->world_x = x;
  thing->world_y = y;
  state.cache.occupancy[x][y] = thing_id;
}

inline static void thing_try_move_to(thing_id_t thing_id, size_t x, size_t y) {
  if (state.cache.occupancy[x][y] != 0)
    return;
  thing_move_to(thing_id, x, y);
}

static void thing_place_randomly(thing_id_t thing_id) {
  thing_t *thing = &state.model.things[thing_id];
  size_t x, y, attempts = 0;
  do {
    x = rand() % WORLD_SIZE_X;
    y = rand() % WORLD_SIZE_Y;
    attempts++;
  } while (state.cache.occupancy[x][y] > 0 && attempts < 2048);
  assert(state.cache.occupancy[x][y] == 0);
  thing->world_x = x;
  thing->world_y = y;
  state.cache.occupancy[x][y] = thing_id;
  printf("[debug] placed thing (%zu) randomly at (%zu, %zu)\n", thing_id, x, y);
}

static void thing_try_random_move(thing_id_t thing_id) {
  thing_t *thing = &state.model.things[thing_id];
  int dx = (rand() % 3) - 1;
  int dy = (rand() % 3) - 1;
  int x = (thing->world_x + WORLD_SIZE_X + dx) % WORLD_SIZE_X;
  int y = (thing->world_y + WORLD_SIZE_Y + dy) % WORLD_SIZE_Y;
  thing_try_move_to(thing_id, x, y);
}

static void things_validate_occupancy() {
  // validate thing -> occupancy mapping
  for (size_t i = 1; i < state.model.things_len; i++) {
    thing_t *thing = &state.model.things[i];
    size_t x = thing->world_x;
    size_t y = thing->world_y;
    assert(state.cache.occupancy[x][y] == i);
  }

  // validate occupancy -> thing mapping
  for (size_t x = 0; x < WORLD_SIZE_X; x++) {
    for (size_t y = 0; y < WORLD_SIZE_Y; y++) {
      thing_id_t id = state.cache.occupancy[x][y];
      if (id == 0)
        continue;
      assert(state.model.things[id].world_x == x);
      assert(state.model.things[id].world_y == y);
    }
  }
}

static thing_t *things_iter_next(size_t *index, uint8_t flag_filter) {
  assert(index != NULL);
  while (*index < state.model.things_len &&
         !(state.model.things[*index].flags & flag_filter)) {
    *index = *index + 1;
  }
  return *index < state.model.things_len ? &state.model.things[*index] : NULL;
}

// ----------------------------------------------------------------------------
// Firms
// ----------------------------------------------------------------------------
static void firms_init() {
  for (int i = 0; i < config.firm.count; i++) {
    size_t idx = state.model.things_len;
    assert(idx < THINGS_MAX);
    state.model.things[idx] = (thing_t){
        .flags = FLAG_FIRM,
        .liquidity = config.firm.init_liquidity,
        .current_demand = config.firm.expected_demand,
        .kind.firm =
            {
                .goods_price = config.firm.init_goods_price,
                .wage_rate = config.firm.init_wage_rate,
                .inventory = config.firm.init_inventory,
                .monthly_revenue = 0,
            },
    };
    thing_place_randomly(idx);
    state.model.things_len++;
  }
}

// static void firm_set_wage_rate(thing_t *firm) {
//   if (firm->flags & FLAG_OPEN_POSITION) {
//     // raise wage
//     firm->kind.firm.wage_rate *=
//         1 + rand_uniform(0, config.firm.wage_adjustment_upper);
//   } else if (firm->kind.firm.months_since_hire_failure >=
//              config.firm.wage_reduction_months) {
//     // lower wage
//     firm->kind.firm.wage_rate *=
//         1 - rand_uniform(0, config.firm.wage_adjustment_upper);
//   }
// }

// ----------------------------------------------------------------------------
// Households
// ----------------------------------------------------------------------------

static void households_init() {
  for (int i = 0; i < config.household.count; i++) {
    size_t idx = state.model.things_len;
    assert(idx < THINGS_MAX);
    state.model.things[idx] = (thing_t){
        .flags = FLAG_HOUSEHOLD,
        .liquidity = config.household.init_liquidity,
        .current_demand = 0,
        .world_x = rand() % WORLD_SIZE_X,
        .world_y = rand() % WORLD_SIZE_Y,
        .kind.household =
            {
                .employer = 0,
                .reservation_wage = config.household.init_reservation_wage,
            },
    };
    thing_place_randomly(idx);
    state.model.things_len++;
  }
}

// ----------------------------------------------------------------------------
// Config
// ----------------------------------------------------------------------------
static float config_marginal_cost_deflator() {
  return config.firm.productivity_multiple * config.model.labor_supply *
         config.model.month_length;
}

// ----------------------------------------------------------------------------
// Colors
// ----------------------------------------------------------------------------

static rgba_t rgba_blend(rgba_t color1, rgba_t color2, float t) {
  rgba_t result = {
      .r = (uint8_t)(color1.r + (color2.r - color1.r) * t),
      .g = (uint8_t)(color1.g + (color2.g - color1.g) * t),
      .b = (uint8_t)(color1.b + (color2.b - color1.b) * t),
      .a = (uint8_t)(color1.a + (color2.a - color1.a) * t),
  };
  return result;
}

static rgba_t uint32_to_rgba(uint32_t color) {
  rgba_t result;
  result.a = (0xFF000000 & color) >> 24;
  result.b = (0x00FF0000 & color) >> 16;
  result.g = (0x0000FF00 & color) >> 8;
  result.r = (0x000000FF & color) >> 0;
  return result;
}

static rgba_t sg_color_to_rgba(sg_color color) {
  rgba_t result;
  result.a = (uint8_t)(0xFF * color.a);
  result.r = (uint8_t)(0xFF * color.r);
  result.g = (uint8_t)(0xFF * color.g);
  result.b = (uint8_t)(0xFF * color.b);
  return result;
}

static uint32_t rgba_to_uint32(rgba_t color) {
  return (color.a << 24) | (color.b << 16) | (color.g << 8) | color.r;
}

static double rand_uniform(double min, double max) {
  assert(min < max);
  return min + rand() / (double)RAND_MAX * (max - min);
}
