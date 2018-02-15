# GroupedErrors

[![Build Status](https://travis-ci.org/piever/GroupedErrors.jl.svg?branch=master)](https://travis-ci.org/piever/GroupedErrors.jl)
[![codecov.io](http://codecov.io/github/piever/GroupedErrors.jl/coverage.svg?branch=master)](http://codecov.io/github/piever/GroupedErrors.jl?branch=master)

This package provides some macros to simplify the analysis and visualization of grouped data.
It is based on the [IterableTables](https://github.com/davidanthoff/IterableTables.jl) framework (but uses [IndexedTables](https://github.com/JuliaComputing/IndexedTables.jl) internally) and can interface with [Plots.jl](https://github.com/JuliaPlots/Plots.jl) for easy plotting.

## Installation

To install this package simply run:

```julia
Pkg.add("GroupedErrors")
```

at the Julia REPL.

## Example use

### Scatter plots

Let's start with an example, plotting one column against another in an example database. Here `school` is a DataFrame, but any [IterableTable](https://github.com/davidanthoff/IterableTables.jl) is supported. The data operations are concatenated using the `@>` macro which GroupedErrors reexports from [Lazy.jl](https://github.com/MikeInnes/Lazy.jl).

```julia
using GroupedErrors
using DataFrames, RDatasets, Plots
school = RDatasets.dataset("mlmRev","Hsb82")
@> school begin
    @splitby _.Sx
    @x _.MAch
    @y _.SSS
    @plot scatter()
end
```

This will simply extract two columns (namely `school[:MAch]` and `school[:SSS]`) and plot them one against the other splitting by the variable `school[:Sx]`, meaning it will actually produce two plots (one for males, one for females) and superimpose them with different colors.  The `@plot` macro takes care of passing the outcome of the the analysis to the plot command. If not plot command is given, it defaults to `plot()`. However it is often useful to give a plot command to specify that we want a scatter plot or to customize the plot with any Plots.jl attribute. For example, our two traces can be displayed side by side using `@plot scatter(layout = 2)`.

Now we have a dot per data point, which creates an overcrowded plot. Another option would be to plot across schools, namely each for each school we would compute the mean of `:MAch` and `:SSS` (always for males and females) and then plot with only one point per school. This can be achieved with:

```julia
@> school begin
    @splitby _.Sx
    @across _.School
    @x _.MAch
    @y _.SSS
    @plot scatter()
end
```

![scatter](https://user-images.githubusercontent.com/6333339/30869875-2fea86da-a2da-11e7-8d2f-3e57a5a5ce39.png)


`mean` is the default estimator, but any other function transforming a vector to a scalar would work, for example `median`:

```julia
@> school begin
    @splitby _.Sx
    @across _.School
    @x _.MAch median
    @y _.SSS median
    @plot scatter()
end
```

One can also give a tuple of 2 functions where the second should represent the error:

```julia
using StatsBase
@> school begin
    @splitby _.Sx
    @across _.School
    @x _.MAch (mean, sem)
    @y _.SSS (mean, sem)
    @plot scatter()
end
```

![scatter](https://user-images.githubusercontent.com/6333339/30869898-41fc9a5c-a2da-11e7-88b5-3642d76c2792.png)


Though admittedly these data are very noisy and error bars come out huge. This analysis would look cleaner in a dataset with less groups (i.e. schools) but with more data per group.

Finally, we may want to represent this information differently. For example we may want to plot the same variable (e.g. `:MAch`) on the `x` and `y` axis where one axis is the value corresponding to males and the other axis to females. This is achieved with:

```julia
@> school begin
    @across _.School
    @xy _.MAch
    @compare _.Sx
    @plot scatter(axis_ratio = :equal, xlabel = "Female", ylabel = "Male",
        legend = :topleft, size = (400,450))
end
```

![scatter](https://user-images.githubusercontent.com/6333339/30870031-a7908950-a2da-11e7-95f9-dd58dcb35e00.png)


### Analyzing variability across groups
It is also possible to get average value and variability of a given analysis (density, cumulative, hazard rate and local regression are supported so far, but one can also add their own function) across groups.

As above, the data is first split according to `@splitby`, then according to `@across` (for example across schools, as in the examples in this README). The analysis is performed for each element of the "across" variable and then summarized. Default summary is `(mean, sem)` but it can be changed with `@summarize` to any pair of functions.

The local regression uses [Loess.jl](https://github.com/JuliaStats/Loess.jl) and the density plot uses [KernelDensity.jl](https://github.com/JuliaStats/KernelDensity.jl). In case of discrete (i.e. non numerical) x variable, these function are computed by splitting the data across the x variable and then computing the density/average per bin. The choice of continuous or discrete axis can be forced as a second argument (the "axis type") to the `@x` macro. Acceptable values are `:continuous`, `:discrete` or `:binned`. This last option will bin the x axis in equally spaced bins (number given by an optional third argument to `@x`, e.g. `@x _.MAch :binned 40`, the default is `30`), and continue the analysis with the binned data, treating it as discrete.

Specifying an axis type is mandatory for local regression, to distinguish it from the scatter plots discussed above.

Example use:

```julia
@> school begin
    @splitby _.Sx
    @across _.School
    @x _.MAch
    @y :cumulative
    @plot plot(legend = :topleft)
end
```
<img width="494" alt="screenshot 2016-12-19 12 28 27" src="https://user-images.githubusercontent.com/6333339/29280675-1a8df192-8114-11e7-878e-754ecdd9184d.png">

Keywords for loess or kerneldensity can be given to groupapply:

```julia
@> school begin
    @splitby _.Minrty
    @across _.School
    @x _.CSES
    @y :density bandwidth = 0.2
    @plot #if no more customization is needed one can also just type @plot
end
```

The bar plot (here we use `@across :all` to compute the standard error across all observations):

```julia
using StatPlots
@> school begin
    @splitby _.Minrty
    @across :all
    @x _.Sx :discrete
    @y _.MAch
    @plot groupedbar()
end
```
<img width="489" alt="screenshot 2017-01-10 18 20 51" src="https://user-images.githubusercontent.com/6333339/29280710-3998b310-8114-11e7-9a24-a93d5727cc52.png">

Density bar plot of binned data versus continuous estimation:

```julia
@> school begin
    @splitby _.Minrty
    @x _.MAch :binned 40
    @y :density
    @plot groupedbar(color = ["orange" "turquoise"], legend = :topleft)
end

@> school begin
    @splitby _.Minrty
    @x _.MAch
    @y :density
    @plot plot!(color = ["orange" "turquoise"], label = "")
end
```

![density](https://user-images.githubusercontent.com/6333339/29373096-06317b50-82a5-11e7-900f-d6c183977ab8.png)

### Analysis of time varying signals

GroupedErrors allows (experimentally! use at your own risk!) aligning time varying signal using [ShiftedArrays](https://github.com/piever/ShiftedArrays.jl) (at the moment ShiftedArray unreleased version is required, will try to release as soon as possible). You need to build a column of ShiftedArrays as follows. Let's say that `v` is your vector of signals and indices `inds = [13, 456, 607]` are those where meaningful event happens (assuming your dataset only have 3 rows, of course in practice `inds` will be much longer). You can create a column of `ShiftedArrays` with:

```julia
[ShiftedArray(v, -i) for i in [13, 456, 607]]
```

and add it to your data. GroupedErrors will then be able to leverage reducing functions from ShiftedArrays to run analysis. In this example dataset we take the column `:signal` to be the vector of `ShiftedArrays`, `:subject` is our grouping variable and `:treatment` is some variable we will use to split the data:

```julia
df = JuliaDB.load(joinpath(Pkg.dir("GroupedErrors", "test", "tables"), "test_signal"))
@> df begin
    @splitby _.treatment
    @across _.subject
    @x -100:100 :discrete
    @y _.signal
    @plot plot() :ribbon
end
```

![signal](https://user-images.githubusercontent.com/6333339/36281283-0cb52924-1295-11e8-87aa-b01160e3aa5e.png)

### Non-parametric bootstrap error computation

Rather than computing the variability across groups, it is also possible to compute the overall variability using non-parametric [bootstrap](https://en.wikipedia.org/wiki/Bootstrapping_(statistics)#Case_resampling) using the `@bootstrap` macro. The analysis will be run as many times as the specified number (defaults to 1000) on a fake dataset sampled with replacement from the actual data. Estimate and error are computed as mean and std of the different outcomes. Example:

```julia
@> school begin
    @splitby _.Minrty
    @bootstrap 500
    @x _.CSES
    @y :density bandwidth = 0.2
    @plot
end
```

![bootstrap](https://user-images.githubusercontent.com/6333339/30870390-a785d568-a2db-11e7-974a-c5319b9d4154.png)

### Advanced feature (for the brave user): customized analysis function

If the set of preimplemented analysis functions turns out to be insufficient, it is possible to implement new ones as a user (should they be of sufficient generality, they could then be added to the package).

For example, let's say we want to study the survival function, which is `1-cdf`. Then we should define:

```julia
function survival(T, xaxis, t)
    data = StatsBase.ecdf(columns(t, :x))(xaxis)
    GroupedErrors.tablify(xaxis, 1 .- data)
end
@> school begin
    @splitby _.Sx
    @across _.School
    @x _.MAch
    @y :custom survival
    @plot
end
```

![surv](https://user-images.githubusercontent.com/6333339/30870065-baa34f14-a2da-11e7-9170-81dccb796236.png)


For the moment there isn't good documentation on how to create your own analysis functions but as a start you can look at [this code](https://github.com/piever/GroupedErrors.jl/blob/master/src/analysisfunctions.jl) and try and follow the same pattern as those that are implemented already.

## Experimental: set plot attributes according to groups

As an experimental features, it is possible to pass attributes to plot that depend on the value of the group that each trace belong to. For example:

```julia
@> school begin
    @splitby (_.Minrty, _.Sx)
    @across _.School
    @set_attr :linestyle _[1] == "Yes" ? :solid : :dash
    @set_attr :color _[2] == "Male" ? :black : :blue
    @x _.CSES
    @y :density bandwidth = 0.2
    @plot
end
```

![set_attr](https://user-images.githubusercontent.com/6333339/30820980-8e16cc60-a21b-11e7-9b2d-4f55f37696d6.png)


Here, the "label" of each trace we are plotting is a tuple, whose first element corresponds to the `:Minrty` and second element to the `:Sx`. With the following code, we decide to represent males in black, females in blue, minority with solid line and no-minority with dashed line. It is a bit inconvenient to use index rather than name to refer to the group but this may change when there will be support for NamedTuples in base Julia.

## Saving the result of the statistical analysis

Sometimes it is useful to save the result of an analysis rather than just plotting it. This can be achieved as follows:

```julia
processed_data = @> school begin
    @splitby _.Minrty
    @x _.MAch :binned 40
    @y :density
    ProcessedTable
end
```

Now plotting can be done as usual with our plotting macro:

```julia
@plot processed_data groupedbar(color = ["orange" "turquoise"], legend = :topleft)
```

without repeating the statistical analysis (especially useful when the analysis is computationally expensive).

## Query compatibility

Of course the amount of data preprocessing in this package is very limited and misses important features (for example data selection). To address this issue, this package is compatible with the excellent querying package [Query.jl](https://github.com/davidanthoff/Query.jl). If you are using Query.jl version 0.8 or above, the Query standalone macros (such as `@filter`, `@map` etc.) can be combined with a GroupedErrors.jl pipeline as follows:

```julia
using Query
@> school begin
    @filter _.SSS > 0.5
    @splitby _.Minrty
    @x _.MAch
    @y :density
    @plot plot(color = ["orange" "turquoise"], legend = :topleft)
end
```

## Missing data support

This package supports missing data. In case of missing data, all rows with missing data in a column that is being used in the analysis will be discarded.
