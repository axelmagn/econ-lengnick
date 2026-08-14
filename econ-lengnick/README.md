# Lengnick 2D Model

This project attempts to extend the Lengnick economic model with custom rules
suitable for a 2D world space.  Firms remain fixed, whereas households will
choose to wander the map when they are dissatisfied.

## Design

### Lengnick Rules

From Lengnick 2013:

- months are 21 days
- consumption goods bought daily
- labor bought monthly

### 2D Extension Rules

- firms and households have 2D integer coordinates
- only one entity may occupy a coordinate
- firms never move
- households *may* move along a random walk (wandering)

### Households

Properties:

- liquidity
- position
- reservation wage

Actions:

- Buy goods


### Firms

Properties:

- liquidity
- position
- inventory
- wage rate

Actions:

- Raise / Lower Wages
- Raise / Lower Prices
- Hire a worker (immediately open a position)
- Fire a worker (in a month)

Beginning of month

- if a free position was offered last month but no worker accepted it, raise
  wages
- if all positions have been filled with workers through the last N months,
  lower wages
- inventory upper and lower limits are determined in relation to last month's
demand
- if inventories are above the upper limit, a random worker is fired
- if inventories are below the lower limit, a new position is created
- price upper and lower limits are determined in relation to marginal cost
- if price is above upper limit, lower prices
- if price is below upper limit, raise prices

### Relations

Relations are constrained by proximity.

- Trading (household buys from firm)
    - household trades with any visible firms
- Employment (firm buys household's labor)
    - firm must be visible by household to employ them
