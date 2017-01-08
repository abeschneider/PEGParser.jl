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

function Grammar(definition::AbstractString) 
  (ast,pos,err) = parse(grammargrammar,definition)
  if err!=nothing
    throw(err)
  end
  transform(togrammar,ast)
end

function Grammar(definition::AbstractString, refgrammar::Grammar) 
  newgrammar = Grammar(definition)
  return Grammar(merge(refgrammar.rules,newgrammar.rules))
end
