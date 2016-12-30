module PEGParser
export @grammar
export StandardCache, Node, transform, Grammar, Rule
export no_action, or_default_action
export ParserData
export ?, list, parseGrammar, parseDefinition, integer, float

#using Compat
import Base: show, parse, +, |, *, ^, >, -, !

function no_action(rule, value, first, last, children)
  return Node(rule.name, value, first, last, children, typeof(rule))
end

or_default_action(rule, value, first, last, children) = children[1]

type MatchRule{T} end

include("rules.jl")
include("grammar.jl")
include("grammarparsing.jl")
include("Node.jl")
include("transform.jl")
include("parse.jl")

end
