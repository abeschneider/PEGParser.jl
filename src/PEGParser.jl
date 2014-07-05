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

function parse(grammar::Grammar, text::String)
  rule = grammar.rules[:start]
  (value, pos, error) = parse(grammar, rule, text, 1, Dict{Int64, Node}());

  # TODO: check that the entire string was matched

  return (value, pos, error);
end

function transform(fn::Function, node::Node; ignore=[])
  return transform(fn, node, Set{Symbol}(ignore))
end

# TODO: This code looks ugly. Can it be cleaned up a little?
function transform(fn::Function, node::Node, ignore::Set{Symbol})
  if node.sym !== nothing && node.sym in ignore
    println("ignoring: $(node.name)")
    return nothing
  end

  cvalues = filter(el -> el !== nothing,
    [transform(fn, child, ignore) for child in node.children])

  println("transforming: $(node.name)")
  println("\tcvalues = $cvalues")

  if isempty(cvalues)
    cvalues = nothing
  elseif length(cvalues) == 1
    cvalues = cvalues[1]
  end


  if node.sym !== nothing
    println("\tnode.sym = $(node.sym), fn=$fn, $(method_exists(fn, (Node, Any, MatchRule{node.sym})))")
  end

  if node.sym !== nothing && method_exists(fn, (Node, Any, MatchRule{node.sym}))
    label = MatchRule{node.sym}()
    rvalue = fn(node, cvalues, label)
    println("\treturning(1): $rvalue")
    return rvalue
  else
    #label = MatchRule{:default}()
    println("\treturning(2): $(node.value)")
    return node.value
  end


#   else
#     return cvalues
#   end
end


# function transform(fn::Function, node::Node; ignore=[])
#   return transform(fn, node, Set{Symbol}(ignore))
# end

# # TODO: This code looks ugly. Can it be cleaned up a little?
# function transform(fn::Function, node::Node, ignore::Set{Symbol})
#   if node.sym !== nothing && node.sym in ignore
#     println("ignoring: $node")
#       return nothing
#   end

#   cvalues = filter(el -> el !== nothing,
#     [transform(fn, child, ignore) for child in node.children])

#   println("transforming: $node")
#   println("cvalues = $cvalues")
#   if length(cvalues) == 1
#     cvalues = cvalues[1]
#   end

#   if isempty(cvalues)
#     cvalues = nothing
#   end

#   if node.sym !== nothing
#     println("node.sym = $(node.sym), fn=$fn, $(method_exists(fn, (Node, Any, MatchRule{node.sym})))")
#   end

#   if node.sym !== nothing && method_exists(fn, (Node, Any, MatchRule{node.sym}))
#     label = MatchRule{node.sym}()
#     rvalue = fn(node, cvalues, label)
#     println("returning(1): $rvalue")
#     return rvalue
#   else
#     #label = MatchRule{:default}()
#     println("returning(2): $cvalues")
#     return node.value
#   end


# #   else
# #     return cvalues
# #   end
# end

unref{T <: Rule}(node::Node, ::Type{T}) = node
unref(node::Node, ::Type{ReferencedRule}) = node.children[1]
unref(node::Node) = unref(node, node.ruleType)


function parse(grammar::Grammar, rule::Rule, text::String, pos::Int64, cache::Dict{Int64, Node})
  cacheKey::Int64 = pos

  if haskey(cache, cacheKey)
    # return the derivative rule
    cachedresult = cache[cacheKey]

    return (cachedresult, cachedresult.last, nothing)
  else
    # it's not cached, so compute results
    (node, pos, error) = uncached_parse(grammar, rule, text, pos, cache)

    # store in cache if we got back a match
    if error === nothing && node !== nothing
      cache[cacheKey] = node
    end

    return (node, pos, error)
  end
end

function uncached_parse(grammar::Grammar, ref::ReferencedRule, text::String, pos::Int64, cache::Dict{Int64, Node})
  rule = grammar.rules[ref.symbol]

  firstPos = pos
  (childNode, pos, error) = parse(grammar, rule, text, pos, cache)

  if childNode !== nothing
    node = Node(ref.name, text[firstPos:pos-1], firstPos, pos, [childNode], typeof(ref))
    return (node, pos, error)
  else
    return (nothing, pos, error)
  end
end

function uncached_parse(grammar::Grammar, rule::OrRule, text::String, pos::Int64, cache::Dict{Int64, Node})
  # Try branches in order (left to right). The first branch to match will be marked
  # as a success. If no branches match, then return an error.
  firstPos = pos;
  for branch in rule.values
    (child, pos, error) = parse(grammar, branch, text, pos, cache)

    if child !== nothing
      node = Node(rule.name, text[firstPos:pos-1], firstPos, pos, [unref(child)], typeof(rule))
      return (node, pos, error)
    end

#     if error !== nothing
#       return (nothing, pos, error)
#     else
#       println("branch did not match")
#     end
  end

  # give error
  return (nothing, pos, ParseError("No matching branches", pos))
end

function uncached_parse(grammar::Grammar, rule::AndRule, text::String, pos::Int64, cache::Dict{Int64, Node})
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

function uncached_parse(grammar::Grammar, rule::Terminal, text::String, pos::Int64, cache::Dict{Int64, Node})
  local size::Int64 = length(rule.value)

  if string_matches(rule.value, text, pos, pos+size)
    size = length(rule.value)
    node = Node(rule.name, text[pos:pos+size-1], pos, pos+size, [], typeof(rule));
    return (unref(node), pos+size, nothing)
  end

  return (nothing, pos, ParseError("'$(text[pos:(pos+length(rule.value)-1)])' does not match '$(rule.value)'.", pos))
end

# TODO: look into making this more streamlined
function uncached_parse(grammar::Grammar, rule::OneOrMoreRule, text::String, pos::Int64, cache::Dict{Int64, Node})
  firstPos = pos
  (child, pos, error) = parse(grammar, rule.value, text, pos, cache)

  # make sure there is at least one
  if child === nothing
    return (nothing, pos, ParseError("No match (OneOrMoreRule)", pos))
  end

  # and continue making matches for as long as we can
  children = {unref(child)}
  while error == nothing
    (child, pos, error) = parse(grammar, rule.value, text, pos, cache)

    if error === nothing && child !== nothing
      push!(children, unref(child))
    end
  end

  node = Node(rule.name, text[firstPos:pos-1], firstPos, pos, children, typeof(rule))
  return (node, pos, nothing)
end

function uncached_parse(grammar::Grammar, rule::ZeroOrMoreRule, text::String, pos::Int64, cache::Dict{Int64, Node})
  firstPos::Int64 = pos
  children::Array{Node} = {}

  error = nothing
  while error == nothing
    (child, pos, error) = parse(grammar, rule.value, text, pos::Int64, cache::Dict{Int64, Node})

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

function uncached_parse(grammar::Grammar, rule::RegexRule, text::String, pos::Int64, cache::Dict{Int64, Node})
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
    error = ParseError("Could not match RegEx", pos)
    return (nothing, firstPos, error)
  end
end

function uncached_parse(grammar::Grammar, rule::OptionalRule, text::String, pos::Int64, cache::Dict{Int64, Node})
  firstPos = pos
  (child, pos, error) = parse(grammar, rule.value, text, pos, cache)

  if child !== nothing
    node = Node(rule.name, text[firstPos:pos-1], firstPos, pos, [unref(child)], typeof(rule))
    return (node, pos, error)
  end

  # no error, but we also don't move the position or return a valid node
  return (nothing, firstPos, nothing)
end

function uncached_parse(grammar::Grammar, rule::ListRule, text::String, pos::Int64, cache::Dict{Int64, Node})
  firstPos = pos
  (child, pos, error) = parse(grammar, rule.entry, text, pos, cache)

  # make sure there is at least one
  if error !== nothing || child === nothing
    return (nothing, pos, ParseError("No match (ListRule)", pos))
  end

  # check if there is a delim
  (dchild, pos, error) = parse(grammar, rule.delim, text, pos, cache)

  # and continue making matches for as long as we can
  children = {unref(child)}
  while error === nothing && child !== nothing
    (child, pos, error) = parse(grammar, rule.entry, text, pos, cache)

    if child !== nothing
      push!(children, unref(child))
      (dchild, pos, error) = parse(grammar, rule.delim, text, pos, cache)
    end
  end

  node = Node(rule.name, text[firstPos:pos-1], firstPos, pos, children, typeof(rule))
  return (node, pos, nothing)
end

end
