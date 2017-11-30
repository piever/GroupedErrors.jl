# GroupedErrors Release Notes

## v.0.1.1

### Bugfixes

- `:locreg` now correctly uses the provided `estimator` function

## New features

- Added `@xlims` and `@ylims` functions to limit the data to plot.

## v0.1.0

### Breaking changes

- The (unexported) analysis functions `_cumulative!`, `_density!`, `_locreg!` and `_hazard!` are no longer modifying and have been renamed to `_cumulative`, `_density`, `_locreg` and `_hazard`

### Bugfixes

- `@compare` now works in combination with error bars
- `_hazard` now handles the discrete and binned case correctly
