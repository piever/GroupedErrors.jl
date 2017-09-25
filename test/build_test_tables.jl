tables = []

school = RDatasets.dataset("mlmRev","Hsb82")

#Test scatter plot
processed_table = @> school begin
    @splitby _.Sx
    @across _.School
    @x _.MAch
    @y _.SSS
    ProcessedTable
end

push!(tables, processed_table.table)

#Test different estimator
processed_table = @> school begin
    @splitby _.Sx
    @across _.School
    @x _.MAch median
    @y _.SSS median
    ProcessedTable
end

push!(tables, processed_table.table)

#Test xy comparison
processed_table = @> school begin
    @splitby _.Minrty
    @across _.School
    @xy _.SSS
    @compare _.Sx
    ProcessedTable
end

push!(tables, processed_table.table)

#Test cumulative
processed_table = @> school begin
    @splitby _.Sx
    @across _.School
    @x _.MAch
    @y :cumulative
    ProcessedTable
end

push!(tables, processed_table.table)

#Test density
processed_table = @> school begin
    @splitby _.Minrty
    @across _.School
    @x _.CSES
    @y :density bandwidth = 0.2
    ProcessedTable
end

push!(tables, processed_table.table)

#Test locreg
processed_table = @> school begin
    @splitby _.Minrty
    @across :all
    @x _.Sx :discrete
    @y _.MAch
    ProcessedTable
end

push!(tables, processed_table.table)

#Test binning
processed_table = @> school begin
    @splitby _.Minrty
    @x _.MAch :binned 40
    @y :density
    ProcessedTable
end

push!(tables, processed_table.table)
