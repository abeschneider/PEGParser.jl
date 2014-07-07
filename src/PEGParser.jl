module PEGParser

import Base: show, parse
using EBNF

include("Node.jl")

export parse, ParseError, MatchRule, Node, transform

immutable ParseError
  msg::String
  pos::Int64
end

type MatchRule{T} end

function parse(grammar::Grammar, text::String; cache=true, start=:start)
  rule = grammar.rules[start]

  (ast, pos, error) = parse(grammar, rule, text, 1, cache, Dict{Int64, Node}())

  if pos < length(text) + 1
    error = ParseError("Entire string did not match", pos)
  end

  return (ast, pos, error);
end

function transform(fn::Function, node::Node; ignore=[])
  return transform(fn, node, Set{Symbol}(ignore))
end

isleaf(node::Node) = isempty(node.children)

function transform(fn::Function, node::Node, ignore::Set{Symbol})
  if node.sym !== nothing && node.sym in ignore
    return nothing
  end

  if isleaf(node)
    return node.value
  end

  cvalues = filter(el -> el !== nothing,
    [transform(fn, child, ignore) for child in node.children])

  if node.sym !== nothing && method_exists(fn, (Node, Any, MatchRule{node.sym}))
    label = MatchRule{node.sym}()
  else
    label = MatchRule{:default}()
  end

    rvalue = fn(node, cvalues, label)
    return rvalue
end

unref{T <: Rule}(node::Node, ::Type{T}) = node
unref(node::Node, ::Type{ReferencedRule}) = node.children[1]
unref(node::Node) = unref(node, node.ruleType)

function parse(grammar::Grammar, rule::Rule, text::String, pos::Int64, usecache::Bool, cache::Dict{Int64, Node})
  cachekey::Int64 = pos

  if usecache && haskey(cache, cachekey)
    # return the derivative rule
    cachedresult = cache[cachekey]
    return (cachedresult, cachedresult.last, nothing)
  else
    # it's not cached, so compute results
    (node, pos, error) = uncached_parse(grammar, rule, text, pos, usecache, cache)

    # TODO; This seems sub-optimal, look into a better method of doing this.
    # store in cache if we got back a match
    if usecache
      if node !== nothing
        cache[cachekey] = node
      else
        delete!(cache, cachekey)
      end
    end

    return (node, pos, error)
  end
end

function uncached_parse(grammar::Grammar, ref::ReferencedRule, text::String, pos::Int64, usecache::Bool, cache::Dict{Int64, Node})
  rule = grammar.rules[ref.symbol]

  firstPos = pos
  (childNode, pos, error) = parse(grammar, rule, text, pos, usecache, cache)

  if childNode !== nothing
    node = Node(ref.name, text[firstPos:pos-1], firstPos, pos, [childNode], typeof(ref))
    return (node, pos, error)
  else
    return (nothing, pos, error)
  end
end

function uncached_parse(grammar::Grammar, rule::OrRule, text::String, pos::Int64, usecache::Bool, cache::Dict{Int64, Node})
  # Try branches in order (left to right). The first branch to match will be marked
  # as a success. If no branches match, then return an error.
  firstPos = pos;
  for branch in rule.values
    (child, pos, error) = parse(grammar, branch, text, pos, usecache, cache)

    if child !== nothing
      node = Node(rule.name, text[firstPos:pos-1], firstPos, pos, [unref(child)], typeof(rule))
      return (node, pos, error)
    end
  end

  # give error
  return (nothing, pos, ParseError("No matching branches", pos))
end

function uncached_parse(grammar::Grammar, rule::AndRule, text::String, pos::Int64, usecache::Bool, cache::Dict{Int64, Node})
  firstPos = pos;

  # All items in sequence must match, otherwise give an error
  value = {}
  for item in rule.values
    (child, pos, error) = parse(grammar, item, text, pos, usecache, cache)

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
function string_matches(expected::Char, actual::String, first::Int64, last::Int64)
  if first > length(actual)
    return false
  end

  return char(actual[first]) == expected;
end

function string_matches(expected::String, actual::String, first::Int64, last::Int64)
  if last - 1 > length(actual)
    return false;
  end

  return expected == actual[first:last-1];
end

function uncached_parse(grammar::Grammar, rule::Terminal, text::String, pos::Int64, usecache::Bool, cache::Dict{Int64, Node})
  local size::Int64 = length(rule.value)

  if string_matches(rule.value, text, pos, pos+size)
    size = length(rule.value)
    node = Node(rule.name, text[pos:pos+size-1], pos, pos+size, [], typeof(rule));
    return (unref(node), pos+size, nothing)
  end

  len = min(pos+length(rule.value)-1, length(text))
  return (nothing, pos, ParseError("'$(text[pos:len])' does not match '$(rule.value)'.", pos))
end

# TODO: look into making this more streamlined
function uncached_parse(grammar::Grammar, rule::OneOrMoreRule, text::String, pos::Int64, usecache::Bool, cache::Dict{Int64, Node})
  firstPos = pos
  (child, pos, error) = parse(grammar, rule.value, text, pos, usecache, cache)

  # make sure there is at least one
  if child === nothing
    return (nothing, pos, ParseError("No match (OneOrMoreRule)", pos))
  end

  # and continue making matches for as long as we can
  children = {unref(child)}
  while error == nothing
    (child, pos, error) = parse(grammar, rule.value, text, pos, usecache, cache)

    if error === nothing && child !== nothing
      push!(children, unref(child))
    end
  end

  node = Node(rule.name, text[firstPos:pos-1], firstPos, pos, children, typeof(rule))
  return (node, pos, nothing)
end

function uncached_parse(grammar::Grammar, rule::ZeroOrMoreRule, text::String, pos::Int64, usecache::Bool, cache::Dict{Int64, Node})
  firstPos::Int64 = pos
  children::Array{Node} = {}

  error = nothing
  while error == nothing
    (child, pos, error) = parse(grammar, rule.value, text, pos::Int64, usecache, cache::Dict{Int64, Node})

    if error === nothing && child !== nothing
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

function uncached_parse(grammar::Grammar, rule::RegexRule, text::String, pos::Int64, usecache::Bool, cache::Dict{Int64, Node})
  firstPos = pos;

  # use regex match
  if ismatch(rule.value, text[firstPos:end])
    value = match(rule.value, text[firstPos:end])

    if length(value.match) == 0
      # this means that we didn't match, but the regex was optional, so we don't want to give an
      # error
      return (nothing, firstPos, nothing)
    else
      pos += length(value.match)
      node = unref(Node(rule.name, text[firstPos:pos-1], firstPos, pos, [], typeof(rule)))

      return (node, pos, nothing)
    end
  else
    return (nothing, firstPos, ParseError("Could not match RegEx", pos))
  end
end

function uncached_parse(grammar::Grammar, rule::OptionalRule, text::String, pos::Int64, usecache::Bool, cache::Dict{Int64, Node})
  firstPos = pos
  (child, pos, error) = parse(grammar, rule.value, text, pos, usecache, cache)

  if child !== nothing
    node = Node(rule.name, text[firstPos:pos-1], firstPos, pos, [unref(child)], typeof(rule))
    return (node, pos, error)
  end

  # no error, but we also don't move the position or return a valid node
  return (nothing, firstPos, nothing)
end

function uncached_parse(grammar::Grammar, rule::ListRule, text::String, pos::Int64, usecache::Bool, cache::Dict{Int64, Node})
  firstPos = pos
  (child, pos, error) = parse(grammar, rule.entry, text, pos, usecache, cache)

  # make sure there is at least one
  if error !== nothing || child === nothing
    return (nothing, pos, ParseError("No match (ListRule)", pos))
  end

  # check if there is a delim
  (dchild, pos, error) = parse(grammar, rule.delim, text, pos, usecache, cache)

  # and continue making matches for as long as we can
  children = {unref(child)}
  while error === nothing && child !== nothing
    (child, pos, error) = parse(grammar, rule.entry, text, pos, usecache, cache)

    if child !== nothing
      push!(children, unref(child))
      (dchild, pos, error) = parse(grammar, rule.delim, text, pos, usecache, cache)
    end
  end

  node = Node(rule.name, text[firstPos:pos-1], firstPos, pos, children, typeof(rule))
  return (node, pos, nothing)
end

end
