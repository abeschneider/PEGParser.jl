type Node
  name::String
  value::String
  first::Uint64
  last::Uint64
  children::Array{Node}
  ruleType
end

function show(io::IO, node::Node, indent)
  print(io, "  "^indent)
  println(io, "node($(node.name)) {$(node.value), $(node.ruleType)}")
  for child in node.children
    show(io, child, indent+1)
  end
end

function show(io::IO, node::Node)
    show(io, node, 0)
end
