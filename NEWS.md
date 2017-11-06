# GroupedErrors v0.1.0 Release Notes

## Breaking changes

- The (unexported) analysis functions `_cumulative!`, `_density!`, `_locreg!` and `_hazard!` are no longer modifying and have been renamed to `_cumulative`, `_density`, `_locreg` and `_hazard`


## Bugfixes

- `@compare` now works in combination with error bars
- `_hazard` now handles the discrete and binned case correctly
