module PEGParser
import Base: show, parse

using EBNF

include("Node.jl")

export parse, ParseError, transform, MatchRule, Node

type ParseError
  msg::String
  pos::Int64
end

type MatchRule{T} end

function parse(grammar::Grammar, text::String)
  rule = grammar.rules[:start]
  (value, pos, error) = parse(grammar, rule, text, 1, Dict{Any, Node}());

  # TODO: check that the entire string was matched

  return (value, pos, error);
end

# TODO: This code looks ugly. Can it be cleaned up a little?
function transform(fn::Function, node::Node)
  cvalues = filter(el -> el !== nothing,
    [transform(fn, child) for child in node.children])

  if length(cvalues) == 1
    cvalues = cvalues[1]
  end

  if isempty(cvalues)
    cvalues = nothing
  end

  if node.sym !== nothing
    label = MatchRule{node.sym}()
  else
    label = MatchRule{:default}()
  end

  return fn(node, cvalues, label)
end

unref{T <: Rule}(node::Node, ::Type{T}) = node
unref(node::Node, ::Type{ReferencedRule}) = node.children[1]
unref(node::Node) = unref(node, node.ruleType)


function parse(grammar::Grammar, rule::Rule, text::String, pos::Int64, cache::Dict{Any, Node})
  cacheKey = pos

  if haskey(cache, cacheKey) #&& cache[cacheKey] !== nothing
    # return the derivative rule
    cachedresult = cache[cacheKey]

    if cachedresult !== nothing
      return (cachedresult, cachedresult.last, nothing)
    else
      return (nothing, pos, nothing)
    end
  else
    # it's not cached, so compute results
    (node, pos, error) = uncached_parse(grammar, rule, text, pos, cache)

    # store in cache
    if error === nothing && node !== nothing
      cache[cacheKey] = node
    end

    return (node, pos, error)
  end
end

function uncached_parse(grammar::Grammar, ref::ReferencedRule, text::String, pos::Int64, cache::Dict{Any, Node})
  rule = grammar.rules[ref.symbol]

  firstPos = pos
  (childNode, pos, error) = parse(grammar, rule, text, pos, cache)

  if error === nothing && childNode !== nothing
    node = Node(ref.name, text[firstPos:pos-1], firstPos, pos, [childNode], typeof(ref))
    return (node, pos, error)
  else
    return (nothing, pos, error)
  end
end

function uncached_parse(grammar::Grammar, rule::OrRule, text::String, pos::Int64, cache::Dict{Any, Node})
  # Try branches in order (left to right). The first branch to match will be marked
  # as a success. If no branches match, then return an error.

  firstPos = pos;
  for branch in rule.values
    (child, pos, error) = parse(grammar, branch, text, pos, cache)

    if child !== nothing
      node = Node(rule.name, text[firstPos:pos-1], firstPos, pos, [unref(child)], typeof(rule))
      return (node, pos, error)
    end
  end

  # give error
  return (nothing, pos, ParseError("No matching branches", pos))
end

function uncached_parse(grammar::Grammar, rule::AndRule, text::String, pos::Int64, cache::Dict{Any, Node})
  firstPos = pos;

  # All items in sequence must match, otherwise give an error
  value = {}
  for item in rule.values
    (child, pos, error) = parse(grammar, item, text, pos, cache)

    # check for error
    if error !== nothing
      return (nothing, firstPos, error)
    end

    if child !== nothing
      push!(value, unref(child))
    end
  end

  node = Node(rule.name, text[firstPos:pos-1], firstPos, pos, value, typeof(rule))
  return (node, pos, nothing)
end

# TODO: there should be string functions that already do this
function string_matches(expected::Char, actual::String, first, last)
  if first > length(actual)
    return false
  end

  return char(actual[first]) == expected;
end

function string_matches(expected::String, actual::String, first, last)
  if last - 1 > length(actual)
    return false;
  end

  return expected == actual[first:last-1];
end

function uncached_parse(grammar::Grammar, rule::Terminal, text::String, pos::Int64, cache::Dict{Any, Node})
  size = length(rule.value)
  if string_matches(rule.value, text, pos, pos+size)
    node = Node(rule.name, text[pos:pos+size-1], pos, pos+size, [], typeof(rule));
    return (unref(node), pos+size, nothing)
  end

  return (nothing, pos, ParseError("'$text' does not match '$(rule.value)'.", pos))
end

# TODO: look into making this more streamlined
function uncached_parse(grammar::Grammar, rule::OneOrMoreRule, text::String, pos::Int64, cache::Dict{Any, Node})
  firstPos = pos
  (child, pos, error) = parse(grammar, rule.value, text, pos, cache)

  # make sure there is at least one
  if error != nothing
    return (nothing, pos, ParseError("No match", pos))
  end

  # and continue making matches for as long as we can
  children = {unref(child)}
  while error == nothing
    (child, pos, error) = parse(grammar, rule.value, text, pos, cache)

    if error == nothing && child !== nothing
      push!(children, unref(child))
    end
  end

  node = Node(rule.name, text[firstPos:pos-1], firstPos, pos, children, typeof(rule))
  return (node, pos, nothing)
end

function uncached_parse(grammar::Grammar, rule::ZeroOrMoreRule, text::String, pos::Int64, cache::Dict{Any, Node})
  firstPos = pos
  children = {}

  error = nothing
  while error == nothing
    (child, pos, error) = parse(grammar, rule.value, text, pos::Int64, cache::Dict{Any, Node})

    if error == nothing && child !== nothing
      push!(children, unref(child))
    end
  end

  if length(children) > 0
    node = Node(rule.name, text[firstPos:pos-1], firstPos, pos, children, typeof(rule))
  else
    node = nothing
  end

  return (node, pos, nothing)
end

function uncached_parse(grammar::Grammar, rule::RegexRule, text::String, pos::Int64, cache::Dict{Any, Node})
  firstPos = pos;

  # use regex match
  value = match(rule.value, text[firstPos:end])
  if value !== nothing
    pos += length(value.match)
    node = unref(Node(rule.name, text[firstPos:pos-1], firstPos, pos, [], typeof(rule)))
    error = nothing
  else
    node = nothing
    error = ParseError("Could not match RegEx", pos)
  end

  return (node, pos, error)
end

function uncached_parse(grammar::Grammar, rule::OptionalRule, text::String, pos::Int64, cache::Dict{Any, Node})
  firstPos = pos
  (child, pos, error) = parse(grammar, rule.value, text, pos, cache)

  if error === nothing
    node = Node(rule.name, text[firstPos:pos-1], firstPos, pos, [unref(child)], typeof(rule))
    return (node, pos, error)
  end

  # no error, but we also don't move the position or return a valid node
  return (nothing, firstPos, nothing)
end

end
