// ============================================================================
//
// 2D Lengnick Simulation
//
// TODO:
// - [ ] populate firms & households
// - [ ] render firms & households
//
// ============================================================================
#ifndef __LENGNICK2D_MODEL_H
#define __LENGNICK2D_MODEL_H

#include <assert.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

// ============================================================================
// Constants
// ============================================================================

#define SIMD_ALIGNMENT (64)
#define THINGS_MAX (8192)
#define RELATIONS_PER_THING_MAX (8)

// shift memory addresses upward into alignment
#define ALIGN_UP(val, alignment)                                               \
  (((val) + ((alignment) - 1)) & ~((alignment) - 1))

#define SIMD_ALIGN_UP(val) (ALIGN_UP(val, SIMD_ALIGNMENT))

// ============================================================================
// Types
// ============================================================================

typedef uint64_t lnk_currency_t;
typedef uint64_t lnk_amount_t;
typedef uint16_t lnk_coord_t;

typedef size_t lnk_id_t;

typedef enum {
  LNK_SUCCESS = 0x00,      // success
  LNK_ERROR = 0x01,        // general error
  LNK_ERROR_MALLOC = 0x02, // memory allocation error
} lnk_result_t;

typedef enum {
  LNK_FLAG_ACTIVE = (1 << 0),
  LNK_FLAG_FIRM = (1 << 1),
  LNK_FLAG_HOUSEHOLD = (1 << 2),
  LNK_FLAG_HAS_OPEN_POSITION = (1 << 3),
} lnk_flag_t;

typedef struct {
  // collection
  size_t count;
  size_t capacity;
  size_t offset;
  lnk_id_t first_free;
  void *buffer_aligned;

  // shared
  uint8_t *flags;
  lnk_currency_t *liquidity;
  lnk_amount_t *current_demand;
  lnk_coord_t *world_x;
  lnk_coord_t *world_y;

  // household
  lnk_id_t *employer;
  lnk_currency_t *reservation_wage;

  // firm
  lnk_currency_t *goods_price;
  lnk_currency_t *wage_rate;
  lnk_currency_t *monthly_revenue;
  lnk_amount_t *inventory;
  lnk_amount_t *months_since_hire_failure;
  lnk_id_t *worker_on_notice;

  // free list
  lnk_id_t *next_free;
} lnk_things_t;

typedef lnk_things_t lnk_thing_handle_t;

typedef enum {
  LNK_PRNG_POPULATE,
} lnk_prng_stream_t;

typedef struct {
  uint64_t state; // rng state.  all values are possible.
  uint64_t inc;   // controls which RNG "stream" is selected.  Always odd.
} lnk_prng_t;

typedef void *(*lnk_alloc_t)(size_t);
typedef void (*lnk_free_t)(void *);

// ============================================================================
// Globals
// ============================================================================
static struct {
  lnk_things_t things;
} lnk_state = {0};

static struct {
  // world
  // ---------
  size_t firms_max;
  size_t households_max;
  lnk_coord_t world_size_x;
  lnk_coord_t world_size_y;
  uint64_t prng_seed;

  // household
  // ---------

  /// distance that households can search for suppliers and employers
  size_t visibility_radius;
  /// distance that households are willing to walk in search of suppliers and
  /// employers
  size_t walk_radius;

  /// amount of liquidity assigned to each household at t=0
  lnk_currency_t initial_household_liquidity;
  /// reservation wage assigned to each household at t=0
  lnk_currency_t initial_reservation_wage;
  /// unemployed reservation wage decay rate
  float unemployed_wage_decay_rate;
  /// Fraction of demand supplied that will satisfy the household desire
  float satisfaction_fraction;
  /// decay rate for consumption expenditure function (alpha)
  float consumption_expenditure_decay;

  // firm

} lnk_config = {
    .firms_max = 256,
    .households_max = 1024,
    .world_size_x = 2048,
    .world_size_y = 2048,
    .prng_seed = 42,
};

static lnk_alloc_t lnk_alloc = malloc;
static lnk_free_t lnk_free = free;

// ============================================================================
// API
// ============================================================================

lnk_result_t lnk_init();
void lnk_deinit();

lnk_result_t lnk_things_alloc();
lnk_result_t lnk_things_populate();
void lnk_things_free();

lnk_id_t lnk_thing_create();
lnk_result_t lnk_thing_get_handle(lnk_thing_handle_t *handle, lnk_id_t id);

void lnk_prng_seed(lnk_prng_t *rng, uint64_t seed, uint64_t sequence);
uint32_t lnk_prng_next(lnk_prng_t *rng);

void *malloc_aligned(size_t alignment, size_t size);
void free_aligned(void *ptr);

// ============================================================================
// Functions
// ============================================================================

lnk_result_t lnk_init() {
  lnk_result_t err;

  err = lnk_things_alloc(&lnk_state.things);
  if (err)
    return err;

  return LNK_SUCCESS;
}

/// allocate and initialize a lnk_things table, aligned for SIMD
lnk_result_t lnk_things_alloc() {
  lnk_things_t *things = &lnk_state.things;

  // TODO: configurable capacity
  size_t capacity = THINGS_MAX;
  lnk_things_t inner = {0};
  // zeroeth thing is always zeroed
  inner.count = 1;
  inner.capacity = capacity;

  uintptr_t offset = 0;

  // shared
  inner.flags = (void *)offset;
  offset += capacity * sizeof(uint8_t);

  offset = SIMD_ALIGN_UP(offset);
  inner.liquidity = (void *)offset;
  offset += capacity * sizeof(lnk_currency_t);

  offset = SIMD_ALIGN_UP(offset);
  inner.current_demand = (void *)offset;
  offset += capacity * sizeof(lnk_amount_t);

  offset = SIMD_ALIGN_UP(offset);
  inner.world_x = (void *)offset;
  offset += capacity * sizeof(lnk_coord_t);

  offset = SIMD_ALIGN_UP(offset);
  inner.world_y = (void *)offset;
  offset += capacity * sizeof(lnk_coord_t);

  // household
  offset = SIMD_ALIGN_UP(offset);
  inner.employer = (void *)offset;
  offset += capacity * sizeof(lnk_id_t);

  offset = SIMD_ALIGN_UP(offset);
  inner.reservation_wage = (void *)offset;
  offset += capacity * sizeof(lnk_currency_t);

  // firm
  offset = SIMD_ALIGN_UP(offset);
  inner.goods_price = (void *)offset;
  offset += capacity * sizeof(lnk_currency_t);

  offset = SIMD_ALIGN_UP(offset);
  inner.wage_rate = (void *)offset;
  offset += capacity * sizeof(lnk_currency_t);

  offset = SIMD_ALIGN_UP(offset);
  inner.monthly_revenue = (void *)offset;
  offset += capacity * sizeof(lnk_currency_t);

  offset = SIMD_ALIGN_UP(offset);
  inner.inventory = (void *)offset;
  offset += capacity * sizeof(lnk_amount_t);

  offset = SIMD_ALIGN_UP(offset);
  inner.months_since_hire_failure = (void *)offset;
  offset += capacity * sizeof(lnk_amount_t);

  offset = SIMD_ALIGN_UP(offset);
  inner.worker_on_notice = (void *)offset;
  offset += capacity * sizeof(lnk_id_t);

  // free list
  offset = SIMD_ALIGN_UP(offset);
  inner.next_free = (void *)offset;
  offset += capacity * sizeof(lnk_id_t);

  inner.buffer_aligned = malloc_aligned(SIMD_ALIGNMENT, offset);
  if (!inner.buffer_aligned)
    return LNK_ERROR_MALLOC;

  offset = (uintptr_t)inner.buffer_aligned;

  inner.flags = (void *)((uintptr_t)inner.flags + offset);

  // shared
  inner.flags = (void *)((uintptr_t)inner.flags + offset);
  inner.liquidity = (void *)((uintptr_t)inner.liquidity + offset);
  inner.current_demand = (void *)((uintptr_t)inner.current_demand + offset);
  inner.world_x = (void *)((uintptr_t)inner.world_x + offset);
  inner.world_y = (void *)((uintptr_t)inner.world_y + offset);
  inner.employer = (void *)((uintptr_t)inner.employer + offset);
  inner.reservation_wage = (void *)((uintptr_t)inner.reservation_wage + offset);
  inner.goods_price = (void *)((uintptr_t)inner.goods_price + offset);
  inner.wage_rate = (void *)((uintptr_t)inner.wage_rate + offset);
  inner.monthly_revenue = (void *)((uintptr_t)inner.monthly_revenue + offset);
  inner.inventory = (void *)((uintptr_t)inner.inventory + offset);
  inner.months_since_hire_failure =
      (void *)((uintptr_t)inner.months_since_hire_failure + offset);
  inner.worker_on_notice = (void *)((uintptr_t)inner.worker_on_notice + offset);
  inner.next_free = (void *)((uintptr_t)inner.next_free + offset);

  // operation was successful - copy inner to output
  *things = inner;
  return LNK_SUCCESS;
}

lnk_result_t lnk_things_populate() {
  // create a new rng
  lnk_prng_t rng;
  lnk_prng_seed(&rng, lnk_config.prng_seed, LNK_PRNG_POPULATE);

  for (int i = 0; i < lnk_config.firms_max; i++) {
    // init firm
  }

  return LNK_SUCCESS;
}

void lnk_things_free() {
  free_aligned(lnk_state.things.buffer_aligned);
  memset(&lnk_state.things, 0, sizeof(lnk_things_t));
}

// NOTE: I copied prng logic from online.  can't say that I understand the
// theory
void lnk_prng_seed(lnk_prng_t *rng, uint64_t seed, uint64_t sequence) {
  // The increment must be odd.
  rng->inc = (sequence << 1u) | 1u;
  rng->state = 0U;

  // Step the generator once to initialize the state
  lnk_prng_next(rng);
  rng->state += seed;
  lnk_prng_next(rng);
}

uint32_t lnk_prng_next(lnk_prng_t *rng) {
  uint64_t old_state = rng->state;

  // advance internal state
  rng->state = old_state * 6364136223846793005ULL + rng->inc;

  // calculate output function (XSH RR)
  uint32_t shifted = ((old_state >> 18u) ^ old_state) >> 27u;
  uint32_t rot = old_state >> 59u;

  // rotate right
  return (shifted >> rot) | (shifted << ((-rot) & 31));
}

lnk_id_t lnk_thing_create() {
  lnk_id_t out = 0;
  if (lnk_state.things.first_free) {
    out = lnk_state.things.first_free;
    lnk_state.things.first_free = lnk_state.things.next_free[out];
  }
}

lnk_result_t lnk_thing_get_handle(lnk_thing_handle_t *handle, lnk_id_t id) {
  lnk_thing_handle_t inner = {0};

  inner.offset = id;

  // shared
  inner.flags = &lnk_state.things.flags[id];
  inner.liquidity = &lnk_state.things.liquidity[id];
  inner.current_demand = &lnk_state.things.current_demand[id];
  inner.world_x = &lnk_state.things.world_x[id];
  inner.world_y = &lnk_state.things.world_y[id];

  // household
  inner.employer = &lnk_state.things.employer[id];
  inner.reservation_wage = &lnk_state.things.reservation_wage[id];

  // firm
  inner.goods_price = &lnk_state.things.goods_price[id];
  inner.wage_rate = &lnk_state.things.wage_rate[id];
  inner.monthly_revenue = &lnk_state.things.monthly_revenue[id];
  inner.inventory = &lnk_state.things.inventory[id];
  inner.months_since_hire_failure = &lnk_state.things.months_since_hire_failure[id];
  inner.worker_on_notice = &lnk_state.things.worker_on_notice[id];

  // free list
  inner.next_free = &lnk_state.things.next_free[id];

  *handle = inner;
  return LNK_SUCCESS;
}

// Allocates memory aligned to the specified power-of-two boundary
void *malloc_aligned(size_t alignment, size_t size) {
  // We need extra space to shift the pointer, plus space to hide
  // the original void* behind the aligned pointer so we can free it.
  size_t offset = alignment - 1 + sizeof(void *);

  void *raw_memory = lnk_alloc(size + offset);
  if (!raw_memory)
    return NULL;

  // Cast to uintptr_t for safe pointer math
  uintptr_t raw_address = (uintptr_t)raw_memory;

  // Shift forward by sizeof(void*) and align up
  uintptr_t aligned_address = ALIGN_UP(raw_address + sizeof(void *), alignment);

  void *aligned_ptr = (void *)aligned_address;

  // Hide the original pointer immediately behind the aligned address
  ((void **)aligned_ptr)[-1] = raw_memory;

  return aligned_ptr;
}

// Frees memory allocated by malloc_aligned
void free_aligned(void *ptr) {
  if (!ptr)
    return;
  // Read the hidden original pointer and free it
  void *raw_memory = ((void **)ptr)[-1];
  free(raw_memory);
}

#endif // __LEGNICK2D_MODEL_H
