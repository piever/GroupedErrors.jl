using GroupedErrors
using Base.Test
using DataFrames, RDatasets, JLD, IndexedTables

include("build_test_tables.jl")

stored_tables = JLD.load(joinpath(@__DIR__, "tables.jld"))["tables"]

for i in 1:length(tables)
    println(i)
    test_table = tables[i]
    println(test_table)
    stored_table = stored_tables[i]
    println(stored_table)
    atol = i == 8 ? 1e-1 : 1e-6
    for j in 1:length(test_table.index.columns)
        if eltype(columns(test_table.index, j)) == Float64
            @test columns(test_table.index, j) ≈ columns(stored_table.index, j) atol = atol
        else
            @test columns(test_table.index, j) == columns(stored_table.index, j)
        end
    end
    for j in 1:2
        if j ==1 || !isa(test_table.data, Array)
            @test columns(test_table.data, j) ≈ columns(test_table.data, j) atol = atol
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
