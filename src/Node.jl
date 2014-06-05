type Node
  name::String
  value::String
  first::Uint64
  last::Uint64
  children::Array{Node}
  ruleType::Type
end

# macro getType(grammarname, rulename)
# #   :(Type{$(esc(symbol("grammar_$(grammarname)_$(rulename)")))})
#   quote
#     local name = $(grammarname);

#     symbol(name)
#   end
# end

macro atot(s)
  quote
    Type{$(esc(symbol(s)))}
  end
end

macro getType(grammarname, rulename)
#   local value = "grammar_$(grammarname)_$(rulename)"
#   println("converting: ", value)
# #   return @atot(value)
#   return Type
  local value = "grammar_$(grammarname)_$(rulename)"
  quote
    Type{$(esc(symbol(value)))}
  end
end

function Node(name::String, value::String, first::Int64, last::Int64, typ)
  return Node(name, value, first, last, [], typ)
end

# function Node{T <: Rule}(name::String, value::String, first::Int64, last::Int64, children::Array{Node}, grammar::Grammar, typ::Type{T})
#   return Node{T}(name, value, first, last, children, getType(grammar, typ))
# end

# getType(node::Node) = node.ruleType
# getType{T <: Type{Rule}}(grammar::Grammar, typ::T) = getType(grammar.name, string(typ))

function show(io::IO, node::Node, indent)
  println(io, "node($(node.name)) {$(node.value), $(node.ruleType)}")
  for (i, child) in enumerate(node.children)
    print(io, "  "^indent)
    print(io, "$i: ")
    show(io, child, indent+1)
  end
end

function show(io::IO, node::Node)
    show(io, node, 0)
end
