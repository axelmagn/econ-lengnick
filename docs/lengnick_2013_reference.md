# Lengnick (2013) — Implementation Reference

Source: M. Lengnick, "Agent-based macroeconomics: A baseline model",
*Journal of Economic Behavior & Organization* 86 (2013) 102–120.
Page numbers below are journal page numbers.

Where the paper is silent we adopt the choices of the
[newwayland/baseline-economy](https://github.com/newwayland/baseline-economy)
Python/Mesa replication (AGPL-3.0). Those decisions are tagged
**Resolved (NW: …)**, with the file and function or note number they come
from. **The paper is the source of truth:** where NW's code departs from
something the paper states explicitly, we follow the paper (§8).

## 1. Global Parameters

Parameters that belong to the model or simulation as a whole, not to an
individual household or firm.

### 1.1 Population

| Symbol | Meaning                 | Value | Source |
|--------|-------------------------|-------|--------|
| `H`    | Number of households    | 1000  | p.105 (§2.1, indexing `h = 1..H`), p.110 (§3) |
| `F`    | Number of firms         | 100   | p.105 (§2.1, indexing `f = 1..F`), p.110 (§3) |

Both are constant: there is no entry or exit, and agents live forever (p.105).

### 1.2 Time structure

| Symbol / name    | Meaning                        | Value       | Source |
|------------------|--------------------------------|-------------|--------|
| `num_days`       | Working days per month         | 21          | p.105 (§2.1, Fig. 1, fn. 15: weekends and holidays excluded); used as the divisor in daily demand `c_h^r / 21`, p.108 |
| `MONTHS_PER_YEAR`| Months per year                | 12 (implied)| p.110: "500 years (6000 months)" |

Day indexing runs continuously across months (Fig. 1: month 1 = days 1–21,
month 2 = days 22–42).

Order of events (the full logic comes later):
1. Start of month (§2.2): firms set wages, hire/fire, set prices; households
   search the network and plan consumption.
2. Each of the 21 days (§2.3): goods transactions, then production.
3. End of month (§2.4): wages, liquidity buffer, profit distribution,
   reservation-wage update.

### 1.3 Simulation run length

| Name             | Meaning                                  | Value                  | Source |
|------------------|------------------------------------------|------------------------|--------|
| `BURN_IN_MONTHS` | Discarded warm-up period                 | 1000 months            | p.110 (§3) |
| `RUN_MONTHS`     | Recorded simulation length               | 6000 months (500 yrs)  | p.110 (§3) |

### 1.4 Monetary / financial environment

| Name            | Meaning                                  | Value                  | Source |
|-----------------|------------------------------------------|------------------------|--------|
| Interest rate on savings | Return on held liquidity        | 0 (normalized)         | p.108 (§2.2) |
| Total money stock `M = Σ m_h + Σ m_f` | Exogenous, conserved quantity | **Not specified** | p.110 (§2.5) |

There is no government and no central bank (p.105). Money is only created or
destroyed by exogenous interventions in the experiments (§4).

### 1.5 Not specified in the paper

The paper gives no values for these:

- Initial money stock and how it is split between households and firms
  (p.110 says only "arbitrary starting conditions"). **Resolved (NW:
  `batch_run.py`):** see §4.
- Initial wages, prices, inventories, reservation wages, and the initial
  trading network. **Resolved (NW):** see §4.
- Random number generator and seeding. The impulse-response method in §4
  needs runs that can be replayed with identical random draws up to the
  shock period (p.114). NW uses one seeded RNG per model run.
- **Numeric types. Resolved (NW: note 10, note 19):** money (liquidity, wages,
  prices) and goods (inventory, purchases) are **integers**, and only whole
  units are transferred. Intermediate calculations are floating point.
  Rounding rules:
  - wage raise: round up, minimum 1
  - wage cut: round down (a wage may reach 0)
  - price raise: round up
  - price cut: round down, minimum 1
  - buffer: round up
  - purchases and dividends: round down

### 1.6 Experiment-only settings (not part of the baseline model)

These come from the experiments in §§4–6. They are listed here so they can be
offered as experiment configuration later.

| Experiment | Setting | Value | Source |
|---|---|---|---|
| Long-run neutrality (§4) | Number of runs | 50 | p.113 |
| | Money multiplier (scales every agent's liquidity) | `U[1, 2]` | p.113 |
| | Horizon after shock | 50 years | p.113 |
| Short-run impulse response (§4) | Money increase in one period | +5% | p.114 |
| | Repetitions (different seeds after the shock) | 2500 | p.114 |
| Micro shock (§5) | Cut in one household's demand on one day mid-month | 5% | p.114 |
| | Population variants | `H` × 0.5, × 2 | p.116 |
| Robustness (§6) | Repetitions per parameterization | 2500 | p.116, fn. 41 |

## 2. Firms

Indexed `f = 1..F`. The number of firms is fixed. Firms never enter or exit and
never go bankrupt (p.109).

### 2.1 Firm config parameters (shared by all firms, constant)

Calibrated values are from Table 1, "Firms" column (p.110).

| Symbol | Code name (suggested) | Meaning | Value | Used in |
|---|---|---|---|---|
| `γ` (gamma) | `wage_cut_months` | Number of months in a row with all positions filled before the wage is cut | 24 | §2.2, p.106–107, Fig. 3 |
| `δ` (delta) | `wage_step_max` | Upper bound of the wage growth rate: `μ ~ U(0, δ)` | 0.019 | Eq. 5, p.107 |
| `φ̄` (phi upper) | `inv_upper_ratio` | Upper inventory bound, as a fraction of last month's demand: `ī_f = φ̄ · d_f^old` | 1 | Eq. 6, p.107 |
| `φ̲` (phi lower) | `inv_lower_ratio` | Lower inventory bound: `i̲_f = φ̲ · d_f^old` | 0.25 | Eq. 7, p.107 |
| `ϕ̄` (varphi upper) | `price_upper_markup` | Upper price bound, as a markup on marginal cost: `p̄_f = ϕ̄ · mc_f` | 1.15 | Eq. 8, p.107 |
| `ϕ̲` (varphi lower) | `price_lower_markup` | Lower price bound: `p̲_f = ϕ̲ · mc_f` | 1.025 | Eq. 9, p.107 |
| `ϑ` (vartheta) | `price_step_max` | Upper bound of the price growth rate: `ν ~ U(0, ϑ)` | 0.02 | Eq. 10, p.107 |
| `θ` (theta) | `price_change_prob` | Probability of actually changing the price when the conditions call for it (Calvo pricing) | 0.75 | p.107, Fig. 3 |
| `λ` (lambda) | `productivity` | Goods produced per worker per **day**: `f(l_f) = λ · l_f` | 3 | Eqs. 13–14, p.109 |
| `χ` (chi) | `buffer_ratio` | Liquidity buffer kept back from profits, as a fraction of the wage bill: `m_f^buffer = χ · w_f · l_f` | 0.1 | Eq. 15, p.109 |

Required orderings: `0 < φ̲ < φ̄` (p.107) and `1 < ϕ̲ < ϕ̄` (p.107).

Notation: an overbar marks an upper bound and an underbar marks a lower bound.
Plain `i_f` and `p_f` are the firm's actual inventory and price.

Constants written into the text rather than listed in Table 1:

| Rule | Value | Source |
|---|---|---|
| Most workers a firm can hire per month | 1 (one new open position) | p.107, fn. 18 |
| Most workers a firm can fire per month | 1 (one randomly chosen worker) | p.107, fn. 18 |
| Delay between deciding to fire and the firing | 1 month (hiring has no delay) | p.107 |
| Labor supplied per worker | `l_h = 1`, so `l_f` is a headcount | p.106, Table 2 |

### 2.2 Firm state variables

#### Persistent state (carried from step to step)

| Symbol | Code name (suggested) | Meaning | Updated when | Source |
|---|---|---|---|---|
| `m_f` | `liquidity` | Money the firm holds | Daily: + revenue from each sale. End of month: − wages, − profit paid out | p.106, p.108, p.109 |
| `i_f` | `inventory` | Finished goods in stock | Daily: − units sold, + `λ · l_f` produced | p.106, Eq. 14 |
| `p_f` | `price` | Price of the good | Start of month (Eq. 10) | p.106–107 |
| `w_f` | `wage` | Wage paid to every employee (one rate per firm) | Start of month (Eq. 5). End of month: forced cut if wages can't be paid | p.106–107, p.109 |
| `{employees}` | `employees` | The firm's type-B connections. `l_f = \|employees\|` | Hiring, firing, households quitting for better pay | p.105, p.107 |
| `d_f^req` | `demand_requested` | Units **requested** from this firm this month (accumulator), whether or not it had the stock. See §6.3 #3 | Daily: + amount requested at each visit. Reset to 0 at the start of the month, after the price decision | p.107 |
| `d_f^sold` | `units_sold` | Units **sold** by this firm this month (accumulator). This is NW's measure (`firm.sell_goods`) | Daily: + units sold. Reset to 0 at the start of the month, after the price decision | p.107 |
| — | `open_position` | Whether the firm offers a vacancy. Boolean: at most one at a time. **Persists across months until filled or cancelled (NW note 8)** | Set at month start when `i_f < i̲_f`. Cleared when a household is hired, or when `i_f > ī_f` | p.107 |
| — | `months_since_hire_failure` | Months in a row that ended with **no** unfilled open position. A wage cut happens when it reaches `γ`. **Resolved (NW: `firm.check_for_hire_failure`)** | End of month: reset to 0 if `open_position` is still set, otherwise +1 | p.106–107, Fig. 3 |
| — | `worker_on_notice` | The worker marked for firing. They keep working and are paid until fired at the **start of the next month**. **Resolved (NW: `firm.manage_workforce`)** | Set at month start when `i_f > ī_f`. Cleared on firing, on quitting, or when inventory falls too low | p.107 |

**`d_f` in Eqs. 6–7:** the paper's `d_f^old` ("the demand for consumption
goods of the most recent month") is last month's total of **either**
`d_f^req` or `d_f^sold`. Both are tracked, and either can be used.
**Current choice: `d_f^req` (requested demand)** (§6.3 #3). Elsewhere in this
document, `d_f` means the selected measure.

Type-A (customer) connections are owned and rewired by households. Firms do
not store them; they are covered in the household section.

#### Derived per-month values (recomputed, not carried)

| Symbol | Meaning | Formula | Source |
|---|---|---|---|
| `ī_f`, `i̲_f` | Upper and lower inventory bounds | `φ̄·d_f^old`, `φ̲·d_f^old` | Eqs. 6–7 |
| `mc_f` | Marginal cost per unit of output | `w_f / (num_days · λ)`. The paper doesn't define it; this is our choice (see §2.3 #1) | p.107 |
| `p̄_f`, `p̲_f` | Upper and lower price bounds | `ϕ̄·mc_f`, `ϕ̲·mc_f` | Eqs. 8–9 |
| `μ`, `ν` | Random wage and price steps | `U(0,δ)`, `U(0,ϑ)`, drawn fresh by each firm | Eqs. 5, 10 |
| `m_f^buffer` | Liquidity kept back at month end | `χ·w_f·l_f` | Eq. 15 |
| profit | Paid out to households, in proportion to their liquidity | `max(0, m_f − m_f^buffer)`, measured **after** wages have been paid | p.109 |
| size | Firm size used in households' price-search weights | `l_f` (number of employees). The search weight is `l_f + 1` (§5.6 #11) | p.107 |

### 2.3 Ambiguities and gaps (firm side)

1. **Marginal cost `mc_f`. RESOLVED:** `mc_f = w_f / (num_days · λ)`.
   The paper never defines `mc_f`. We chose this definition because it is the
   one that makes economic sense in the model:
   - Units: `w_f` is paid once a month (p.109), but production `λ · l_f` runs
     every day (§2.3, Eq. 14). An extra worker therefore costs `w_f` and adds
     `num_days · λ` units a month.
   - The figures support λ being a daily rate: Fig. 6 firm demand is in the
     hundreds of units per month, and an average firm of 10 workers makes
     about 630.
   - In steady state the labor share of revenue is `1/ϕ` ≈ 87–98%. The band
     `ϕ̲..ϕ̄ = 1.025..1.15` then works as the 2.5–15% markup the paper
     describes.
   - Rejected alternative `w_f / λ`: it gives a labor share of about 4–5%, a
     real markup of about 2000%, and makes profit distributed by wealth the
     main source of household income.
2. **Whether an open position persists.** **Resolved (NW note 8):** it
   persists month to month until filled or cancelled. A firm has at most one
   open position.
3. **Timing of firing.** **Resolved (NW notes 6–7, `firm.manage_workforce`):**
   a worker is given notice at the start of month *t*, works and is paid for
   month *t*, and is fired at the start of month *t+1*. At each month start,
   in this order:
   1. If `i_f < i̲_f`: if a worker is on notice, cancel the notice and do
      **not** open a position. Otherwise open a position.
   2. If a worker is still on notice, fire them.
   3. If `i_f > ī_f`: cancel any open position and give notice to a random
      worker.
4. **What counts as "all positions filled" for γ.** **Resolved (NW:
   `firm.check_for_hire_failure`):** any month that ends without an unfilled
   open position counts toward the streak, including months with no vacancy
   at all. Once the streak reaches `γ`, the wage is cut **every** month until
   a hire fails.
5. **Profit when the buffer can't be covered.** **Resolved (NW:
   `firm.pay_wages`, `firm.distribute_profits`):**
   - Wages are paid first, out of all of the firm's liquidity.
   - Profit is `m_f − buffer`, and only if positive.
   - If `m_f < w_f · l_f`, the wage is cut **permanently** to
     `w_f ← ⌊m_f / l_f⌋` and paid.
   - If `m_f < l_f` (less than one money unit per worker), the wage is set to
     0 and nobody is paid that month.
6. **Wage and price step direction.** Eqs. 5 and 10 use `(1 ± μ)` and
   `(1 ± ν)`. The sign comes from the decision rule in Fig. 3:
   - **Wage. Resolved (NW: `firm.set_wage_rate`):** raise if `open_position`
     is still set from last month. Otherwise cut if
     `months_since_hire_failure ≥ γ`. A raise takes precedence.
   - **Price:** raise only when `i_f < i̲_f` **and** `p_f < p̄_f`, and cut only
     when `i_f > ī_f` **and** `p_f > p̲_f`, in both cases with probability `θ`.
7. **Initial values.** **Resolved (NW):** see §4.

## 3. Households

Indexed `h = 1..H`. The number of households is fixed and they live forever
(p.105). Each one supplies one unit of labor inelastically (`l_h = 1`, p.106).

### 3.1 Household config parameters (shared by all households, constant)

Calibrated values are from Table 1, "Households" column (p.110).

| Symbol | Code name (suggested) | Meaning | Value | Used in |
|---|---|---|---|---|
| `n` | `num_goods_links` | Number of type-A (supplier) connections per household. Also the most firms visited per day when the first one can't supply enough (see §3.3) | 7 | p.105, p.109, Fig. 14 |
| `ψ_Price` | `price_search_prob` | Monthly probability that a household looks for a cheaper supplier | 0.25 | p.107 |
| `ξ` (xi) | `price_switch_threshold` | Relative price gap needed to switch: switch if the new price is more than `ξ·100`% below the old firm's | 0.01 | p.107 |
| `ψ_Quant` | `quant_search_prob` | Monthly probability of replacing a supplier that couldn't meet demand | 0.25 | p.107 |
| `β` (beta) | `unemployed_search_visits` | Most firms an unemployed household visits per month looking for a job | 5 | p.107 |
| `π` (pi) | `satisfied_search_prob` | Monthly probability that a satisfied employee (`w_f ≥ ω_h`) checks one random firm for a better job | 0.1 | p.107 |
| `α` (alpha) | `consumption_exponent` | Exponent of the planned-consumption rule `c_h^r = min{(m_h/P_h^l)^α, m_h/P_h^l}`. Requires `0 < α < 1` | 0.9 | Eqs. 11–12, p.108 |
| `φ` (phi) | — | **Unexplained.** Listed in Table 1 but used by no household rule in the text (see §3.3) | 0.25 | Table 1 only |

Constants written into the text rather than listed in Table 1:

| Rule | Value | Source |
|---|---|---|
| Labor supply | `l_h = 1` | p.106, Table 2 |
| Most employers per household | 1 (at most one type-B connection) | p.105 |
| Job-search probability for a dissatisfied employee (`w_f < ω_h`) | 1 (one random firm per month) | p.107–108 |
| Fraction of planned demand that ends the day's search | 95% | p.109 |
| Reservation-wage cut after a month of unemployment | 10% (`ω_h ← 0.9·ω_h`) | p.109 |
| Interest on savings | 0 (global, §1.4) | p.108 |
| How planned monthly demand is split into daily demand | Evenly: `c_h^r / num_days` | p.108 |

### 3.2 Household state variables

#### Persistent state (carried from step to step)

| Symbol | Code name (suggested) | Meaning | Updated when | Source |
|---|---|---|---|---|
| `m_h` | `liquidity` | Money the household holds. Never negative (Eq. 4) | Daily: − spending on goods. End of month: + wage, + share of profits | Eqs. 1–4, p.106, p.109 |
| `ω_h` | `reservation_wage` | The household's wage aspiration. It sets job-search intensity and the minimum wage an **unemployed** household will accept (NW note 4) | End of month: if employed, `ω_h ← max(ω_h, w_employer)`. If unemployed at month end, `ω_h ← 0.9·ω_h` | p.106, p.109 |
| — | `employer` | The type-B connection: one firm, or none (unemployed) | Hiring, firing, quitting for a better job | p.105, p.107 |
| — | `suppliers` | The `n` type-A connections. These are the only firms whose prices the household knows | Start of month: price and quantity searches replace a link | p.105, p.107 |
| `c_h^r` | `planned_consumption` | Real consumption planned for the month. It sets the daily demand target | Start of month (Eq. 12) | p.108 |
| — | `shortfalls` | List of `(firm, shortfall)` records from this month's purchases. One record is added each time a supplier's **stock** (not the household's money) stops a purchase, with `shortfall = remaining demand − i_f`. A firm can appear more than once. **Resolved (NW: `household.check_vendor_stock`, `household.blackmark`)** | Daily, during purchases. Read by the ψ_Quant search, then cleared at the start of the month | p.107, p.109 |
| — | `daily_demand` | Integer units to buy each day this month: `⌊c_h^r / num_days⌋`. **Resolved (NW note 2)** | Start of month | p.108 |

#### Derived values (recomputed, not carried)

| Symbol | Meaning | Formula | Source |
|---|---|---|---|
| `P_h^l` | Average price across the household's suppliers | Simple unweighted mean of `p_f` over `suppliers`. **Resolved (NW note 11)** | p.108 |
| satisfied | Whether the household is happy with its job | `w_employer ≥ ω_h` | p.107 |
| labor income | This month's wage | `w_employer`, or 0 if unemployed | p.109 |
| affordable amount | Most units affordable at firm `f` | `⌊m_h / p_f⌋` | p.108–109 |
| profit share | The household's cut of a firm's distributed profit | `m_h / Σ m_h` (pro rata to liquidity) | p.109, fn. 22 |

The household doesn't store wages or prices of other firms. It learns them
only by visiting firms during a search (p.106).

### 3.3 Ambiguities and gaps (household side, parameters and state only)

1. **Table 1 lists `φ = 0.25` for households, but no household rule uses it.**
   The firm column already has `φ̲ = 0.25` (lower inventory bound), so this is
   most likely a typesetting duplicate. **Resolved (NW):** unused. NW's
   `HouseholdConfig` doesn't include it.
2. **`n` plays two roles.** It is the number of type-A links (p.105) and the
   number of firms a household tries per day. **Resolved (NW:
   `household.buy_goods`):** one parameter. Each day the household shuffles
   its `n` suppliers and visits each at most once.
3. **The 95% threshold and the 10% reservation-wage cut** are hard-coded in
   the paper. We expose them as config, as NW does (`satisfaction_fraction`,
   `wage_decay_rate`). §6 of the paper varies the 10% cut from 0 to 50%.
4. **"Unemployed during the last month."** **Resolved (NW:
   `household.adjust_reservation_wage`):** the household is unemployed at the
   moment of the end-of-month update.
5. **Initial values.** **Resolved (NW):** see §4.

## 4. Initialization

**Not defined in the paper.** The 2013 paper says only "set all properties to
initial values" (p.109) and runs a 1000-month burn-in "to get rid of the
influence of arbitrary starting conditions" (p.110). The 2011 working paper
says the same.

**Resolved (NW: `batch_run.py`, `firm.py` `FirmConfig`, `household.py`
`HouseholdConfig`, NW notes "Bootstrap Issues"):**

| Entity | Variable | Initial value | Note |
|---|---|---|---|
| Household | `m_h` | 3100 | `batch_run.py`. The interactive server's default is 3200 |
| Household | `ω_h` | 0 | |
| Household | `employer` | none | Everyone starts unemployed |
| Household | `suppliers` | `n` distinct firms, sampled uniformly | Full set of type-A links |
| Household | `shortfalls` | empty | No initial demand constraint |
| Firm | `m_f` | 0 | |
| Firm | `p_f` | 25 | `batch_run.py`. The server's default is 27 |
| Firm | `w_f` | 68 × `num_days` = 1428 per month | Given as a daily rate of 68. The server's default is 70. Implies `p_f / mc_f ≈ 1.10`, inside the markup band |
| Firm | `i_f` | 0 | |
| Firm | `d_f^req`, `d_f^sold` | 1 | Must be > 0, or Eqs. 6–7 give zero bounds and the firm never hires |
| Firm | `employees` | none | |
| Firm | `open_position` | false | |
| Firm | `months_since_hire_failure` | 0 | |
| Firm | `worker_on_notice` | none | |

Total money stock: `M = 1000 × 3100 = 3,100,000`.

Constraints (NW notes): `w_f` and `p_f` must start above 0 (Eqs. 5, 10 are
multiplicative), and `d_f` must start above 0.

The simulation starts on day 1, which is the start of month 1.

## 5. Start of Month (§2.2, pp.106–108, Fig. 3)

Steps are listed in the order the paper presents them. The paper states the
ordering between phases explicitly: firms decide first, and households search
"after all firms have formed decisions" (p.107).

### 5.1 Firms: wage decision (p.106–107, Eq. 5)

- **Raise** `w_f` if "a free position was offered during the last month, but
  no worker was found to accept it."
- **Lower** `w_f` if "all positions have been filled with workers throughout
  the last γ months."
- Otherwise leave it unchanged.
- Update rule: `w_f ← w_f · (1 ± μ)`, with `μ ~ U(0, δ)` drawn
  independently by each firm.

### 5.2 Firms: hiring and firing decision (p.107, Eqs. 6–7)

- Compute `ī_f = φ̄ · d_f^old` and `i̲_f = φ̲ · d_f^old`, where `d_f^old` is
  "the demand for consumption goods of the most recent month."
- If `i_f < i̲_f`, **create a new open position**. Hiring takes effect
  immediately: the position is offered at once.
- If `i_f > ī_f`, **fire a randomly chosen worker**, which cuts that
  type-B connection. Firing is "implemented with a lag of one month."
- Otherwise nothing changes.
- Fn. 18: a firm hires or fires at most one worker per month.

### 5.3 Firms: price decision (p.107, Eqs. 8–10, Fig. 3)

- A price change is considered only when inventories are outside the band:
  - `i_f < i̲_f`: consider a **raise**, which happens only if `p_f < p̄_f`.
  - `i_f > ī_f`: consider a **cut**, which happens only if `p_f > p̲_f`.
- Bounds: `p̄_f = ϕ̄ · mc_f` and `p̲_f = ϕ̲ · mc_f`, with
  `mc_f = w_f / (num_days · λ)` (§2.3 #1).
- When a change is called for, it happens with probability `θ` (Calvo).
- Update rule: `p_f ← p_f · (1 ± ν)`, with `ν ~ U(0, ϑ)`.
- Ordering: the paper presents the price decision after the wage decision
  ("Next the decision on changing the goods price…"). Because `mc_f` depends
  on `w_f`, this order affects the result. NW uses wage, then workforce, then
  price, then resets the demand counters to 0.

### 5.4 Households: network search (p.107–108)

"Households are picked in a random order." For each household, the paper
describes the following steps in this order.

**(a) Price search for goods.** With probability `ψ_Price`:
- Pick one type-A firm uniformly at random from the household's suppliers.
- Pick one firm it is *not* connected to, "with probability proportional to
  the firm's size, measured in employees." **Decided:** the weight is
  `l_f + 1`, so every firm has some chance of being picked (§5.6 #11).
- If the new firm's price is more than `ξ·100` percent below the old firm's,
  drop the old link and add the new one.

**(b) Quantity search for goods.** Applies only if the household was
demand-constrained last month (one or more suppliers couldn't fully satisfy
its demand). With probability `ψ_Quant`:
- Pick one of the constraining firms "with a probability proportional to the
  extent of the restriction."
- Cut that link and "replace it with a connection to a new one."

**(c) Job search.**
- **Unemployed:** visit a randomly chosen firm. If it has an open position
  and "pays a wage that is higher than the household's currently received
  wage," accept: a new type-B connection forms. Otherwise repeat, up to a
  total of `β` firms visited.
- **Employed and dissatisfied** (`w_f < ω_h`): with probability 1, visit one
  randomly chosen firm. Accept if it has an open position and "the offered
  wage payment exceeds that of their current position."
- **Employed and satisfied** (`w_f ≥ ω_h`): the same, but with
  probability `π`.

### 5.5 Households: consumption planning (p.108, Eqs. 11–12)

- `P_h^l` is the average price of the household's type-A firms.
- Planned real consumption for the month:
  `c_h^r = min{ (m_h / P_h^l)^α , m_h / P_h^l }`.
- The paper says this decision is "also performed monthly." It is described
  after the network search, but no explicit ordering is given.

### 5.6 Not defined in the paper (start of month)

1. **Whether open positions carry over, and how many a firm can have.**
   **Resolved:** they persist, and a firm has at most one (§2.3 #2).
2. **The firing lag.** **Resolved:** fired at the next month start, and paid
   for the notice month (§2.3 #3).
3. **The γ streak.** **Resolved:** months with no vacancy count (§2.3 #4).
4. **Raise vs. cut precedence.** **Resolved:** the raise is checked first
   (§2.3 #6).
5. **Order of processing across firms.** **Resolved (NW: `schedule.py`):** a
   fixed order, never shuffled. Firm decisions are independent of each other
   at month start.
6. **Replacement firm in the quantity search (b).** **Resolved (NW:
   `household.select_new_firm`):** uniformly at random among firms that are
   not already suppliers. The constraining firm is drawn from the `shortfalls`
   records, weighted by shortfall. If that firm was already swapped out by
   the price search this month, nothing happens (NW note 3).
7. **Price search picking the employer.** **Resolved (NW):** allowed. The only
   exclusion is firms that are already suppliers.
8. **Distinct firms in the job search.** **Resolved (NW:
   `household.select_new_employer`):** firms are drawn with replacement,
   excluding the current employer. Visits stop at the first acceptance.
9. **What the unemployed accept.** **Resolved (NW notes 4–5,
   `household.is_acceptable_job_offer`):** the unemployed accept an open
   position only if `w_f > ω_h`. The employed follow the paper: accept only
   if the offer exceeds their current wage (§8 #3).
10. **Supplier set used for consumption planning.** **Resolved (NW:
    `household.month_start`):** the set **after** this month's searches.
11. **Zero-employee firms in the size-weighted pick.** Weighting literally by
    `l_f` gives these firms probability 0. The paper doesn't say what happens
    when every candidate has `l_f = 0`. This happens in month 1 under the §4
    initialization: everyone starts unemployed, and the price search runs
    before the job search. **Decided (2026-10-09):** weight each candidate by
    `l_f + 1`.
    - Every firm always has a non-zero chance of being picked.
    - When every candidate has `l_f = 0`, the pick is uniform.
    - For large firms the weight is close to the paper's `l_f`.
12. **Sequencing of the searches.** **Resolved (NW: `household.month_start`):**
    each household runs, in order:
    1. price search (prob. `ψ_Price`)
    2. quantity search (prob. `ψ_Quant`)
    3. clear `shortfalls`
    4. job search
    5. consumption planning

    Then the next household starts. The job search runs if the household is
    unemployed (up to `β` visits), or paid below `ω_h` (1 visit), or otherwise
    with probability `π` (1 visit).
13. **Household order.** **Resolved (NW note 16, `schedule.py`):** shuffled
    once per day. At month start, the same order is used for the start-of-month
    step and for that day's buying.
14. **Eq. 12's cap.** NW uses Eq. 11 only (NW note 1). With integer daily
    demand `⌊c/num_days⌋` the cap never binds, because it applies only when
    `m_h/P_h^l < 1`, and that gives 0 units either way. Keeping Eq. 12 as
    written makes no difference.

## 6. Each Day (§2.3, pp.108–109)

Repeated for each of the `num_days` days of the month. Households trade
first, then all firms produce. "After all households and firms have performed
their daily actions, the next day starts" (p.109).

### 6.1 Households: buying goods (p.108–109)

"Households are picked in a random order to execute their goods demand."
For each household:

1. **Daily demand.** Planned demand is spread evenly over the month:
   `c_h^r / num_days`. This is the paper's literal `c_h^r / 21`.
2. **Visit a supplier.** "Each household visits one randomly determined firm
   of those he has a type A connection with."
3. **Normal case.** If the firm's inventory covers the demand and the
   household can afford it (`m_h ≥ p_f · c_h^r/num_days`), the transaction
   happens:
   - `m_h ← m_h − p_f · c_h^r/num_days`
   - `m_f ← m_f + p_f · c_h^r/num_days`
   - `i_f ← i_f − c_h^r/num_days`
4. **Liquidity limit.** If `m_h < p_f · c_h^r/num_days`, demand "is reduced to
   the highest possible amount (`m_h / p_f`)."
5. **Inventory limit.** If `i_f` is below the household's demand, the
   transaction "is performed at the highest possible amount of `i_f`."
   Inventories can never go negative.
   - **Demand recording (§6.3 #3):** at every visit, the firm adds the
     amount requested, `min(remaining demand, ⌊m_h/p_f⌋)`, to `d_f^req`, and
     the amount actually sold to `d_f^sold`.
6. **Try another firm.** The household tries to cover the rest of its demand
   "by repeating the buying process with another firm." It stops once
   `n` firms have been asked **or** at least 95% of planned demand has been
   met. Any demand still left "vanishes."

### 6.2 Firms: production (p.109, Eqs. 13–14)

After all households have bought, each firm produces:
- `f(l_f) = λ · l_f`
- `i_f ← i_f + λ · l_f`

### 6.3 Not defined in the paper (daily)

1. **Choosing the next firm.** **Resolved (NW: `household.buy_goods`):** the
   supplier list is shuffled each day, and suppliers are visited in that
   order, each at most once.
2. **What "95 percent" refers to.** **Resolved (NW note 14):** the **daily**
   demand. The household stops once the remaining demand is at most
   `⌊daily_demand · (1 − 0.95)⌋`. Anything left above that amount is recorded
   as unsatisfied demand.
3. **What `d_f` counts.** **Decided: track both. Either can feed Eqs. 6–7. Current choice: `d_f^req`** (2026-10-09).
   - **`d_f^sold`:** units actually sold. This is NW's measure
     (`firm.sell_goods`). A firm that sells out can't see its excess demand.
     A firm with zero sales gets `d_f = 0`, can never hire, and effectively
     exits (NW note 12).
   - **`d_f^req`:** units requested, `min(remaining demand, ⌊m_h/p_f⌋)` per
     visit. The affordability cut is part of demand, because the paper says
     that when the household can't afford its plan "his demand is reduced to
     the highest possible amount (`m_h/p_f`)" (p.109). Stock is **not**
     applied, so a firm that sells out still registers its excess demand.
     Unmet demand passed on to the next supplier is counted again there, so
     `Σ d_f^req` can exceed total household demand. Use it as a per-firm
     signal, not an aggregate.
   - Always `d_f^sold ≤ d_f^req`. They are equal unless the firm ran out of
     stock.
4. **How "demand constrained" is recorded.** **Resolved (NW:
   `household.check_vendor_stock`):** a record is added only when the firm's
   stock was the binding limit (`i_f < remaining` **and** `i_f < affordable`).
   Running out of money doesn't count. See `shortfalls` in §3.2.
5. **Divisibility.** **Resolved:** goods and money are integers (§1.5). Each
   purchase is `min(remaining demand, ⌊m_h/p_f⌋, i_f)` units.
6. **Order of firm production.** Doesn't matter; NW uses a fixed order.
7. **Whether a worker on notice produces.** **Resolved (NW):** yes. They stay
   in `employees` until fired.

## 7. End of Month (§2.4, p.109)

After all `num_days` days. Steps are listed in the order the paper presents
them.

### 7.1 Firms: wages, buffer, profits (p.109, Eq. 15)

"Firms use the liquidity they own at the end of a month for three different
purposes":

1. **Pay wages.** Every employee of firm `f` receives `w_f`:
   - `m_f ← m_f − w_f · l_f`
   - `m_h ← m_h + w_f` for each employee `h`
2. **Build a buffer.** From whatever liquidity is left, the firm keeps
   `m_{f,t}^buffer = χ · w_f · l_f` against future losses.
3. **Pay profits.** "All remaining liquidity of the firm is distributed as
   profit among all households." Each household receives "a share of
   aggregate profits that is proportional to his current liquidity"
   (fn. 22: a household with twice the money gets twice the share). Profits
   are pooled across firms and paid to **all** households, not only
   employees.

**Losses** (p.109):
- First, the firm pays no profit and draws down its buffer, keeping wages
  unchanged.
- If losses are so large that wages can't be paid even with the buffer at 0,
  "the firm's employees accept an immediate wage cut that is sufficient to
  keep the firm operating."
- Fn. 24: a wage cut of 5% (10%) or more occurs only with probability 0.01
  (0.006). This is reported as an outcome, not a parameter.
- This rule keeps the number of firms constant: there is no entry or exit.

### 7.2 Households: reservation wage (p.109)

- Labor income above `ω_h`: raise `ω_h` to the received labor income.
- Labor income below `ω_h`: leave `ω_h` unchanged. The household instead
  searches harder for a job (§5.4(c)).
- "If a household has been unemployed during the last month, his reservation
  wage for the next month is reduced by 10 percent": `ω_h ← 0.9 · ω_h`.

"The month ends and the next one begins."

### 7.3 Not defined in the paper (end of month)

NW end-of-month order (`schedule.py`):
1. Every firm pays wages and updates `months_since_hire_failure`.
2. Household liquidity is captured once as the profit-share weights.
3. Every firm pays out profit above its buffer.
4. Every household updates `ω_h`.

1. **Wage-cut size and persistence.** **Resolved:** a permanent cut to
   `⌊m_f/l_f⌋`, or to 0 if `m_f < l_f` (§2.3 #5).
2. **"Current liquidity" for profit shares.** **Resolved (NW note 15):** taken
   after **all** wages are paid and before any profit is paid. One weighting
   is used for every firm.
3. **Order across firms.** **Resolved:** a fixed order. Order doesn't matter
   given #2.
4. **When `d_f` becomes `d_f^old`.** **Resolved:** there is no separate
   "old" copy. Each counter (`d_f^req`, `d_f^sold`) holds last month's total
   until it is reset at the start of the month, after the price decision
   (§2.2).
5. **When the firing lag ends.** **Resolved:** at the next month start
   (§2.3 #3).
6. **Vacancy bookkeeping.** **Resolved:** at month end, after wages, via
   `months_since_hire_failure` (§2.2).
7. **"Unemployed during the last month."** **Resolved:** unemployed at the
   moment of the month-end update (§3.3 #4).
8. **Labor income after a wage cut.** **Resolved (NW):** the reservation-wage
   update uses the employer's current (post-cut) `w_f`.
9. **Fractional money.** **Resolved:** integers (§1.5).

## 8. NW Departures From the Paper (decided: follow the paper)

In these places the NW code contradicts the paper's explicit text, or has a
bug. **Decision (2026-10-08): the paper's rule is used in every case.**

1. **Price-search candidate firm.** Paper: chosen "with probability
   proportional to the firm's size, measured in employees" (p.107), among
   firms that aren't suppliers. NW picks uniformly
   (`household.select_new_firm`). **Use the paper,** with weight `l_f + 1`
   (§5.6 #11).
2. **Price-search target supplier.** Paper: chosen uniformly from **all**
   type-A firms. NW's `range(0, len(suppliers) - 1)` never picks the last
   supplier (`household.find_cheaper_vendor`). **Use the paper.**
3. **Employed job-switch rule.** Paper: accept only if the offered wage
   "exceeds that of their current position" (p.107). NW also accepts any
   offer with `w_new > ω_h` (`household.is_acceptable_job_offer`).
   **Use the paper:** an employed household accepts only if
   `w_new > w_current`.
4. **Price-raise bound.** Paper: raise only if `p_f < p̄_f`. NW uses `≤`.
   **Use the paper.**

## 9. Validation

Part A checks that the code implements this reference. Part B checks whether
the implementation reproduces the paper's results. Part A can run in CI.
Part B consists of long batch experiments.

### 9.A Automated correctness tests

These follow from the rules in §§2–8. Each should hold for every seed. Run
them as unit tests on small hand-built economies (for example 2 firms and 5
households), and as invariant checks asserted after every step of a short
full-size run (for example 50 months).

#### Conservation and bounds (assert every day)

| # | Invariant | Basis |
|---|---|---|
| A1 | Total money `Σ m_h + Σ m_f` is unchanged by every step. Daily trades move money between agents. Month-end wages and profits are transfers, and dividend rounding leaves the remainder with the firm | §1.4, §7.1 |
| A2 | `m_h ≥ 0`, `m_f ≥ 0`, `i_f ≥ 0` | Eq. 4, p.109 |
| A3 | Goods balance per firm per day: `Δi_f = λ · l_f − units sold` | Eqs. 13–14 |
| A4 | Goods balance in aggregate: units bought by households = `Σ` units sold by firms | §6.1 |
| A5 | `p_f ≥ 1`, `w_f ≥ 0`. Money and goods are integers | §1.5 |
| A6 | `d_f^sold ≤ d_f^req` | §6.3 #3 |

#### Network consistency (assert after every phase)

| # | Invariant | Basis |
|---|---|---|
| A7 | Every household has exactly `n` **distinct** suppliers | p.105, §5.4 |
| A8 | Every household has at most one employer | p.105 |
| A9 | Two-way consistency: `h ∈ employees(f)` ⇔ `employer(h) = f` | §2.2, §3.2 |
| A10 | `worker_on_notice`, if set, is a current employee | §2.3 #3 |
| A11 | A firm with an open position has `open_position = true`, and at most one exists | §2.3 #2 |

#### Firm rules (unit tests at month start)

| # | Test | Basis |
|---|---|---|
| A12 | A wage change satisfies `\|w_new/w_old − 1\| ≤ δ`, before rounding. Direction: raise iff the open position was still unfilled from last month, else cut iff `months_since_hire_failure ≥ γ` | Eq. 5, §2.3 #4, #6 |
| A13 | A firm hires at most one worker and fires at most one per month. Firing happens only to the worker given notice the month before | fn. 18, §2.3 #3 |
| A14 | `i_f < i̲_f` opens a position, or cancels an existing notice instead. `i_f > ī_f` cancels the position and gives notice. Inside the band, nothing changes | §2.3 #3 |
| A15 | A price changes only if inventory is outside the band **and** the price bound allows it (`p < p̄` to raise, `p > p̲` to cut, strict). The change satisfies `\|p_new/p_old − 1\| ≤ ϑ`, before rounding | Eqs. 8–10, §8 #4 |
| A16 | Calvo frequency: over many eligible firm-months, the fraction that change price ≈ `θ` | p.107 |
| A17 | `mc_f = w_f / (num_days · λ)`, and the price bounds use the **post-adjustment** wage | §2.3 #1, §5.3 |

#### Household rules (unit tests)

| # | Test | Basis |
|---|---|---|
| A18 | Planned consumption equals `min{(m/P)^α, m/P}`, with `P` the simple mean of the supplier prices after the search | Eq. 12, §5.6 #10 |
| A19 | Price search: switch only if `p_new < (1 − ξ) · p_old`. The candidate firm is never a current supplier. Candidates are drawn in proportion to `l_f + 1` (a statistical test over many draws). A zero-employee firm is still picked sometimes | p.107, §8 #1–2 |
| A20 | The quantity search replaces only a firm in `shortfalls`, drawn in proportion to its recorded shortfall (statistical test) | p.107, §5.6 #6 |
| A21 | Job search: the unemployed visit at most `β` firms and accept only if `w > ω_h`. The employed visit at most 1 firm and accept only if `w > w_current`. The visit probability is 1 if `w < ω_h` and `π` otherwise (statistical test) | §5.6 #9, §8 #3 |
| A22 | Daily buying: at most `n` suppliers are visited, each at most once. The household stops once the remaining demand is ≤ `⌊0.05 · daily_demand⌋`. No purchase exceeds `⌊m_h/p_f⌋` or `i_f` | §6.1, §6.3 |
| A23 | A shortfall record is added only when stock, not money, was the binding limit | §6.3 #4 |
| A24 | Reservation wage at month end: employed → `max(ω, w)`. Unemployed → `0.9 · ω` | §7.2 |

#### Month-end accounting (unit tests)

| # | Test | Basis |
|---|---|---|
| A25 | Each employee receives exactly `w_f`. If `m_f < w_f · l_f`, the wage becomes `⌊m_f/l_f⌋`, permanently. If `m_f < l_f`, it becomes 0 | §2.3 #5 |
| A26 | After profits are paid, `m_f = min(m_f, ⌈χ · w_f · l_f⌉)`, plus any rounding remainder | Eq. 15 |
| A27 | Each household's dividend is proportional to its liquidity measured after **all** wages are paid (within floor rounding) | §7.3 #2 |

#### Reproducibility and scheduling

| # | Test | Basis |
|---|---|---|
| A28 | Same seed ⇒ bit-identical trajectory. This is required for the §4 impulse-response method | p.114 |
| A29 | Two runs that share a seed up to a shock day must be identical up to that day, and differ only afterward | p.114 |
| A30 | Phase order per month: firms decide (wage, then workforce, then price), then households search and plan (one random order). Then each day: households buy, then firms produce. Then at month end: wages, then profit weights, then profits, then reservation wages | §§5–7 |

### 9.B Reproducing the paper's results

#### Protocol

- **Baseline run.** Table 1 calibration, `H = 1000`, `F = 100`, §4 initial
  values, a 1000-month burn-in (discarded), then 6000 recorded months
  (p.110).
- **Multiple seeds.** The paper's statistics come from single runs, except
  in §§4–6. Run several seeds to check that the result is not a one-seed
  artifact.
- **Demand measure.** The baseline uses `d_f^req`. Repeat with `d_f^sold`
  (§6.3 #3) to see whether the results depend on the choice.

#### Measurement definitions the paper does not give

These must be fixed before comparing. **Not defined in the paper:**
- the price index `P`: mean of `p_f`, sales-weighted, or other
- GDP / production: the paper says production is linear in employment
  (p.111), so `λ · num_days · Σ l_f` per month is implied
- the time aggregation for Figs. 5–6. Fig. 7 uses quarterly data
- the HP-filter smoothing parameter (fn. 33)
- how "recession" and "boom" shock dates are chosen (Fig. 9)
- which demand measure Fig. 6's "firm size (in demand)" uses
- when the §4 money shock is applied

#### Targets

| Fig. | Experiment | Target from the paper | Page |
|---|---|---|---|
| 4 (left) | Baseline | Unsatisfied demand ÷ planned demand < **0.03%** in 95% of periods. The 2011 working paper says < 0.65% | p.111 |
| 4 (right) | Baseline | Employment in a 50-year window ranges over **957–1000** (unemployment 0–4.3%), with endogenous cycles and **no** shocks. The troughs are below full employment, with no peaks above it | p.111 |
| 5 | Baseline | **Phillips curve:** negative relation between unemployment and inflation `ΔP` (range about −4…+6 × 10⁻³). **Beveridge curve:** negative relation between unemployment and vacancies (range about 20–85). The paper's plots add `U[−0.5, 0.5]` jitter (fn. 31) | p.112 |
| 6 (left) | Baseline | Firm size (in demand) is right-skewed, with sample skewness about **1.88** and no fat tails | p.112 |
| 6 (right) | Baseline | Share of firms changing price per period is right-skewed, with skewness about **0.47** and median about **9%** (empirical 9–12%) | p.112 |
| 7 (left) | Baseline, quarterly, HP-filtered | Correlation of GDP with the price index at lags −8…+8 quarters: **negative** for negative lags, **positive** for lags ≥ 2. Mostly within the US-data 95% bootstrap band, but too strong for lags < −3 | p.112–113 |
| 7 (right) | Baseline, monthly | Sawtooth aggregate liquidity: household money falls through each month and jumps at month end. Firm money rises through the month and drops at month end | p.113 |
| 8 | 50 runs, all liquidity × `U[1, 2]` | After 50 years, `ΔP/P ≈ ΔM/M` (points on the 45° line) and `ΔY ≈ 0`: long-run neutrality | p.113 |
| 9 | +5% money, 2500 reps, identical RNG up to the shock | **Recession:** output impact peaks at about **+2.5% after ~3 years**, and neutrality can't be rejected from **6½ years**. **Boom:** no significant effect for 3 years, a peak of about **+1.4% after ~4 years**, and neutrality from **14 years**. After about 5 years the mean impact oscillates with amplitude ≤ about 4.5% | p.114 |
| 10 | One household's demand −5% on one mid-month day, 2500 reps | Mean difference ≈ 0 for prices and production. Mean **absolute** difference grows concavely over 120 years, with production at about **508** after 120 years versus a decoupled benchmark of about **559** (569 excluding zero-effect runs) | p.114–115, fn. 37 |
| 11 | Same | Cycle amplitude, duration and level are unchanged, but the phase shifts and grows over time: the trajectories are about identical early and fully decoupled after about 100 years | p.115 |
| 12 | Same, with `H` × 0.5 and × 2 (per 1000 households) | Smaller populations decouple faster. All three converge after about 180 years | p.116 |
| 13 | `ω_h` cut 0–50%, 2500 reps each | Unemployment falls monotonically up to a cut of about 20%. Unsatisfied demand rises for cuts > 10%. At a cut of 0, unsatisfied demand > 10% and unemployment > 50%. Variant (cut applied before search): lower unemployment, higher unsatisfied demand | p.116–117 |
| 14 (top) | `θ` ∈ [0, 1] | For `θ > 0.25`: unemployment about **8**, unsatisfied demand about **0.0002**. Breakdown below 0.25. Slightly worse labor market as `θ` rises | p.117 |
| 14 (bottom) | `n` ∈ [1, 50] | For `n ≥ 5`: quasi-equilibrium. Breakdown below 5. Unemployment rises slightly for `n > 15` | p.117 |

#### Known risks

- The paper reports some numbers that look inconsistent:
  - Fig. 4's employment floor (957, so about 43 unemployed) is far from
    Fig. 14's "about 8" unemployed. Fig. 14 likely reports a mean.
  - The 2011 and 2013 versions give different unsatisfied-demand figures
    (0.65% vs 0.03%).
  - The 2011 Table 1 has no `χ`.
- A third-party study using the NW replication reports that it could not
  reproduce the Beveridge curve (arXiv 2603.00113). Treat Fig. 5 as the
  target most likely to fail.
- Our implementation deliberately differs from NW in §6.3 #3 and §8, so
  NW's outputs are a reference point, not ground truth.
