using DataFrames, RDatasets, IndexedTables, IterableTables, StatPlots
using GroupedErrors
school = RDatasets.dataset("mlmRev","Hsb82")

@> school begin
    #@where (_.Minrty == "No")
    @splitby (_.Minrty,)
    @across _.School
    @xy _.SSS
    @compare _.Sx
    #ProcessedTable
    #@compare _.Sx
    @plot scatter(layout = 2, axis_ratio = :equal, legend = false)
end

@> school begin
    @splitby _.Sx
    @across _.School
    @x _.MAch
    @y :cumulative
    @plot plot(legend = :topleft)
end
grp_error = groupapply(:cumulative, school, :MAch; compute_error = (:across,:School), group = :Sx)
plot(grp_error, line = :path, legend = :topleft)

@> school begin
    @splitby _.Minrty
    @across _.School
    @x _.CSES
    @y :density bandwidth = 0.2
    @plot plot()
end

pool!(school, :Sx)
grp_error = groupapply(school, :Sx, :MAch; compute_error = :across, group = :Minrty)
plot(grp_error, line = :bar)

@> school begin
    @splitby _.Minrty
    @across :all
    @x _.Sx :discrete
    @y _.MAch
    @plot groupedbar()
end

grp_error = groupapply(:density, school, :MAch; axis_type = :binned, nbins = 40, group = :Minrty)
plot(grp_error, line = :bar, color = ["orange" "turquoise"], legend = :topleft)

grp_error = groupapply(:density, school, :MAch; axis_type = :continuous, group = :Minrty)
plot!(grp_error, line = :path, color = ["orange" "turquoise"], label = "")

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
    @plot plot!(color = ["orange" "turquoise"], legend = :topleft)
end

using Query
@> school begin
    #@where _.SSS > 0.5
    @splitby _.Minrty
    @x _.SSS
    @y :density
    @plot plot(color = ["orange" "turquoise"], legend = :topleft)
end

s = @from i in school begin
    @where i.Minrty == "Yes"
    @groupby i by i.Sx into j
    @select {j..MAch, j..School, } into k
    @let shared_axis = compute_axis(k..MAch)
    @group k.MAch by k.School into l
    @select {axis = compute_axis(l), density = compute_density(l, axis) } into m
    @group m by m.axis into n
    @select {mean(m..density), sem(m..density)}
    @collect DataFrame
end

using IndexedTables

s = IndexedTable(rand(Bool,100), fill(true,100), rand(100))
mapslices(t->IndexedTable([1, 2], [1, 2]) , s, [])

s = IndexedTable(rand(Bool,100), rand(Bool,100),  rand(100))
mapslices(t->IndexedTable([1, 2], [1, 2]) , s,  [])
IndexedTables.mapslices(println, s, [1])

IndexedTables.mapslices(t -> IndexedTable(rand(2), rand(2)), s, [1])
# TO DO: kws for plot call + locreg bug
s = IndexedTable(rand(Bool,10), rand(10))


using Query, DataFrames


x = @from i in df begin
    @where i.age>40
    @select (i.name,)#merge(i, @NT(b=2))
    @collect
end

using Query, DataFrames

df = DataFrame(a=[1,1,2,3], b=[4,5,6,8])

df2 = df |>
    @groupby({a = (_.a, _.a)} ) |>
    @select({a = _.key, b=_}) |>
    DataFrame


using IndexedTables

df = Columns(x = ["a", "b"], y = [1, 2])

columns(df,:x)

for i in df
    println(i)
end
