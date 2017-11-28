using GroupedErrors
using Base.Test
using DataFrames, RDatasets, JuliaDB, IndexedTables

include("build_test_tables.jl")

for i in 1:length(tables)
    println(i)
    test_table = tables[i]
    println(test_table)
    stored_table = collect(Dagger.load(joinpath(@__DIR__, "tables", "t$i")))
    println(stored_table)
    atol = i == 8 ? 1e-1 : 1e-6
    for j in colnames(stored_table)
        if eltype(columns(stored_table, j)) == Float64
            @test columns(stored_table, j) ≈ columns(test_table, j) atol = atol
        else
            @test columns(stored_table, j) == columns(test_table, j)
        end
    end
end


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
