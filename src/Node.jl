# include("EBNF.jl")

immutable Node
    name::AbstractString
    value::AbstractString
    first::Int
    last::Int
    children::Array #::Array{Node}
    ruleType::Type
    sym::Any

    Node(node::Node) =
        new(node.name, node.value, node.first, node.last, node.children, node.ruleType, node.sym)

    Node(name::AbstractString, value::AbstractString,
         first::Int, last::Int, children::Array, ruleType::Type) =
        new(name, value, first, last, children, ruleType,
            length(name)==0 ? nothing : symbol(name))
end

Node(name::AbstractString, value::AbstractString, first::Int, last::Int, typ) =
    Node(name, value, first, last, [], typ)

show{T}(io::IO, val::T, indent) = println(io, "$val ($(typeof(val)))")

function show(io::IO, node::Node, indent)
  println(io, "node($(node.name)) {$(displayValue(node.value, node.ruleType))$(node.ruleType)}")
  if isa(node.children, Array)
    for (i, child) in enumerate(node.children)
      print(io, "  "^indent)
      print(io, "$i: ")
      show(io, child, indent+1)
    end
  else
    print(io, "  "^(indent+1))
    show(io, node.children, indent+1)
  end
end

show(io::IO, node::Node) = show(io, node, 0)
