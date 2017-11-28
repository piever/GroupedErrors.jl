school = RDatasets.dataset("mlmRev","Hsb82")
tables = []

#Test scatter plot
processed_table = @> school begin
    @splitby _.Sx
    @across _.School
    @x _.MAch
    @y _.SSS
    ProcessedTable
end

push!(tables, processed_table.table)
#Dagger.save(table(processed_table.table, chunks = 1), joinpath(@__DIR__, "tables", "t1"))

#Test different estimator
processed_table = @> school begin
    @splitby _.Sx
    @across _.School
    @x _.MAch median
    @y _.SSS median
    ProcessedTable
end

push!(tables, processed_table.table)
#Dagger.save(table(processed_table.table, chunks = 1), joinpath(@__DIR__, "tables", "t2"))

#Test xy comparison
processed_table = @> school begin
    @splitby _.Minrty
    @across _.School
    @xy _.SSS
    @compare _.Sx
    ProcessedTable
end

push!(tables, processed_table.table)
#Dagger.save(table(processed_table.table, chunks = 1), joinpath(@__DIR__, "tables", "t3"))

#Test cumulative
processed_table = @> school begin
    @splitby _.Sx
    @across _.School
    @x _.MAch
    @y :cumulative
    ProcessedTable
end

push!(tables, processed_table.table)
#Dagger.save(table(processed_table.table, chunks = 1), joinpath(@__DIR__, "tables", "t4"))

#Test density
processed_table = @> school begin
    @splitby _.Minrty
    @across _.School
    @x _.CSES
    @y :density bandwidth = 0.2
    ProcessedTable
end

push!(tables, processed_table.table)
#Dagger.save(table(processed_table.table, chunks = 1), joinpath(@__DIR__, "tables", "t5"))

#Test locreg
processed_table = @> school begin
    @splitby _.Minrty
    @across :all
    @x _.Sx :discrete
    @y _.MAch
    ProcessedTable
end

push!(tables, processed_table.table)
#Dagger.save(table(processed_table.table, chunks = 1), joinpath(@__DIR__, "tables", "t6"))

#Test binning
processed_table = @> school begin
    @splitby _.Minrty
    @x _.MAch :binned 40
    @y :density
    ProcessedTable
end

push!(tables, processed_table.table)
#Dagger.save(table(processed_table.table, chunks = 1), joinpath(@__DIR__, "tables", "t7"))

#test bootstrap
processed_table = @> school begin
    @splitby _.Minrty
    @bootstrap 500
    @x _.CSES
    @y :density bandwidth = 0.2
    ProcessedTable
end

push!(tables, processed_table.table)
#Dagger.save(table(processed_table.table, chunks = 1), joinpath(@__DIR__, "tables", "t8"))

#test continuous locreg
processed_table = @> school begin
    @splitby _.Minrty
    @x _.MAch :continuous
    @y _.SSS
    ProcessedTable
end

push!(tables, processed_table.table)
#Dagger.save(table(processed_table.table, chunks = 1), joinpath(@__DIR__, "tables", "t9"))
