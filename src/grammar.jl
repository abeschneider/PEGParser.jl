type Grammar
  rules::Dict{Symbol, Rule}
end

function show(io::IO,grammar::Grammar)
  println("PEGParser.Grammar(Dict{Symbol,PEGParser.Rule}(")
  for (sym,rule) in grammar.rules 
    println("  $sym => $(string(rule)),")
  end
  println(")")
end

Grammar(definition::AbstractString) = transform(togrammar,parse(grammargrammar,definition)[1])
