module PEGParser
#using Compat

import Base: show, parse, +, |, *, ^, >, -, !

include("grammar.jl")
include("Node.jl")
include("rules.jl")

export StandardCache, Node, transform, Grammar, Rule
export @grammar, @set_parsers
export no_action, or_default_action
export ParserData, IntegerRule, FloatRule
export map_symbol_to_function
export ?, list, parseGrammar, parseDefinition, integer, float

type MatchRule{T} end



# default transform is to do nothing
transform{T}(fn::Function, value::T) = value

function transform(fn::Function, node::Node)
  if isa(node.children, Array)
    transformed = [transform(fn, child) for child in node.children]
  else
    transformed = transform(fn, node.children)
  end

  if method_exists(fn, (Node, Any, MatchRule{node.sym}))
    label = MatchRule{node.sym}()
  else
    label = MatchRule{:default}()
  end

  return fn(node, transformed, label)
end

unref{T <: Any}(value::T) = [value]
unref{T <: Rule}(node::Node, ::Type{T}) = [node]
unref(node::Node, ::Type{ReferencedRule}) = node.children
unref(node::Node) = unref(node, node.ruleType)

function make_node(rule, value, first, last, children::Array)
  # println("rule.action = ", rule.action, rule, value)
  result = rule.action(rule, value, first, last, children)
  return result
end

include("parse.jl")

end
