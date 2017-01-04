module PEGParser
export @grammar
export StandardCache, Node, transform, Grammar, Rule
export no_action, or_default_action
export ParserData, MatchRule
export ?, list, parseGrammar, parseDefinition

#using Compat
import Base: show, parse
import Base: +, |, *, ^, >, -, !, integer, float # TODO: these should not even conflict with Base

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
include("newgrammar.jl")

end
