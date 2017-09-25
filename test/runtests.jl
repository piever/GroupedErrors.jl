using GroupedErrors
using Base.Test
using DataFrames, RDatasets, JLD, IndexedTables

include("build_test_tables.jl")

stored_tables = JLD.load(joinpath(@__DIR__, "tables.jld"))["tables"]

for i in 1:length(tables)
    test_table = tables[i]
    stored_table = stored_tables[i]
    for j in 1:length(test_table.index.columns)
        if eltype(columns(test_table.index, j)) == Float64
            @test columns(test_table.index, j) ≈ columns(stored_table.index, j) atol = 1e-6
        else
            @test columns(test_table.index, j) == columns(stored_table.index, j)
        end
    end
    for j in 1:2
        if j ==1 || !isa(test_table.data, Array)
            @test columns(test_table.data, j) ≈ columns(test_table.data, j) atol = 1e-6
        end
    end
end
