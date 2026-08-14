# Modified Lengnick Economy

This is my own variation on the Lengnick ACE model, wherein firms and houses
interact on a 2D map.

The notion is to generally follow the Lengnick model, but rather than randomly
sampling firm / house relations, it is derived by a visibility radius on a map.
Households can only interact with firms within their visibility, and if they
become dissatisfied with their circumstances, their recourse is to wander
randomly to another point on the map.

## Data Design

### Model

### Firms

#### State

| Variable          | Identifier        | Description                          |
|-------------------|-------------------|--------------------------------------|
| $\phi_t$    | Phi               | Phi                                  |

### Houses
