using GroupedErrors
using Base.Test
using JuliaDB, IndexedTables
using ShiftedArrays

function check_equality(stored_table, test_table, atol)
    for j in colnames(stored_table)
        if eltype(columns(stored_table, j)) == Float64
            @test columns(stored_table, j) ≈ columns(test_table, j) atol = atol
        else
            @test columns(stored_table, j) == columns(test_table, j)
        end
    end
end

include("build_test_tables.jl")

for i in 1:length(tables)
    println(i)
    test_table = tables[i]
    println(test_table)
    stored_table = loadtable(joinpath(@__DIR__, "tables", "t$i.csv"))
    println(stored_table)
    atol = i == 8 ? 1e-1 : 1e-4
    check_equality(stored_table, test_table, atol)
end

split_vars = [:Minrty, :Sx]

processed_table = @> school begin
    @splitby(Tuple(getfield(_, s) for s in split_vars))
    @x(_.MAch, :continuous)
    @y(_.SSS)
    ProcessedTable
end

processed_table_col = @> GroupedErrors.ColumnSelector(school) begin
    GroupedErrors._splitby(split_vars)
    GroupedErrors._x(:MAch, :continuous)
    GroupedErrors._y(:locreg, :SSS)
    ProcessedTable
end

check_equality(processed_table.table, processed_table_col.table, 1e-6)

processed_table = @> school begin
    @splitby (_.Minrty, _.Sx)
    @across _.School
    @set_attr :linestyle _[1] == "Yes" ? :solid : :dash
    @set_attr :color _[2] == "Male" ? :black : :blue
    @x _.CSES
    @y :density bandwidth = 0.2
    ProcessedTable
end

@test [t[1] for t in processed_table.kw[:plot_kwargs]] == [:linestyle, :color]

na_school_vec = convert(Vector{GroupedErrors.DataValue{Float64}}, columns(school, :MAch))
na_school_vec[1] = GroupedErrors.DataValue{Float64}()

table2process_nafree = @> setcol(school, :MAch, na_school_vec) begin
    @x(_.MAch, :continuous)
    @y(_.SSS)
    GroupedErrors.Table2Process
end

table2process = @> school begin
    @x(_.MAch, :continuous)
    @y(_.SSS)
    GroupedErrors.Table2Process
end

check_equality(table(table2process.table...)[2:end], table(table2process_nafree.table...), 1e-8)

v = [1, 2, 3, 4, 5, 6, 7, 8]

t = table([1, 2], ShiftedArray.((v,), [-3, -7]), names = [:x, :y])

res = @> t begin
    @across _.x
    @x -1:1 :discrete
    @y _.y
    ProcessedTable
end
expected_res = table(@NT(s1 = fill("y1", 3), x = -1:1, y = [4., 5., 6.], err = fill(2., 3)),
    pkey = :s1)

check_equality(expected_res, res.table, 1e-8)
