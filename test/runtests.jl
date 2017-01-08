using Base.Test
using PEGParser
include("../examples/calc1.jl")
@test transformed == 9
include("../examples/calc2.jl")
@test ast == 9
@test PEGParser.grammargrammar == Grammar(PEGParser.grammargrammar_string)
