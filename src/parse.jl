###########
# Helpers #
###########

unref{T <: Any}(value::T) = [value]
unref{T <: Rule}(node::Node, ::Type{T}) = [node]
unref(node::Node, ::Type{ReferencedRule}) = node.children
unref(node::Node) = unref(node, node.ruleType)

function make_node(rule, value, first, last, children::Array)
  #println("make_node: $(rule.action)($rule, $value, first=$first, last=$last, children=$children)")
  return rule.action(rule, value, first, last, children)
end

###############
# ParserCache #
###############

abstract ParserCache

type StandardCache <: ParserCache
  values::Dict{AbstractString, Node}

  function StandardCache()
    return new(Dict{AbstractString, Any}())
  end
end



###################
# parse (generic) #
###################

"""
    parse(grammar, text; cache::ParserCache=nothing, start=:start)
parses `text` according to `grammar` to yield a tuple consisting of Abstract Syntax Tree, final matched position and error (ast, pos, error) depending on outcome.
`start` specifies the symbol associated to the rule at the top of the AST. Specifying a `cache` different than `nothing` allows to reuse previous work, whenever the same rule is evaluated at the same position again.
"""
function parse(grammar::Grammar, text::AbstractString; cache=nothing, start=:start)
  rule = grammar.rules[start]
  (ast, pos, error) = parse(grammar, rule, text, 1, cache)

  if pos < length(text) + 1
    error = ParseError("Entire string did not match at pos: $pos")
  end

  return (ast, pos, error)
end

"""
    parse(grammar, rule, text, pos, cache)
parses `text` according to `rule` within `grammar` starting with position `pos`. Specifying a `cache` different than `nothing` allows to reuse previous work, whenever the same rule has been matched at the same position before. If no `cache` is specified or no match in `cache` is found `parse` resorts to `parse_newcachekey`, because in an non-existent cache every cachekey is new.
"""
function parse(grammar::Grammar, rule::Rule, text::AbstractString, pos::Int, cache::Void)
  return parse_newcachekey(grammar, rule, text, pos, cache)
end

function parse(grammar::Grammar, rule::Rule, text::AbstractString, pos::Int, cache::StandardCache)
  cachekey::AbstractString = "$(object_id(rule))$pos"
  if haskey(cache.values, cachekey)
    # lookup cachekey
    cachedresult = cache.values[cachekey]
    (node, pos, error) = (cachedresult, cachedresult.last, nothing)
  else
    # parse new cachekey
    (node, pos, error) = parse_newcachekey(grammar, rule, text, pos, cache)

    # store new cachekey
    if node !== nothing
      cache.values[cachekey] = node
    end
  end

  return (node, pos, error)
end




##############################################
# parse_newcachekey (specific for each rule) #
##############################################

"""
    parse_newcachekey(grammar, rule, text, pos, cacheforsubnodes)
parses `text` according to `rule` within `grammar` starting with position `pos` without trying to lookup the complete match in the specified `cache`. Matches of children of the current `rule` along the `text` to parse will however be looked-up in `cache`.
"""
function parse_newcachekey(grammar::Grammar, rule::ReferencedRule, text::AbstractString, pos::Int, cache)
  refrule = grammar.rules[rule.symbol]

  firstPos = pos
  (childNode, pos, error) = parse(grammar, refrule, text, pos, cache)

  if childNode !== nothing
    node = make_node(rule, text[firstPos:pos-1], firstPos, pos, [childNode])
    return (node, pos, error)
  else
    return (nothing, pos, error)
  end
end

function parse_newcachekey(grammar::Grammar, rule::OrRule, text::AbstractString, pos::Int, cache)
  # Try branches in order (left to right). The first branch to match will be marked
  # as a success. If no branches match, then return an error.
  firstPos = pos
  for branch in rule.values
    (child, pos, error) = parse(grammar, branch, text, pos, cache)

    if child !== nothing
      node = make_node(rule, text[firstPos:pos-1], firstPos, pos, unref(child))
      return (node, pos, error)
    end
  end

  # give error
  return (nothing, pos, ParseError("No matching branches at pos: $pos"))
end

function parse_newcachekey(grammar::Grammar, rule::AndRule, text::AbstractString, pos::Int, cache)
  firstPos = pos;

  # All items in sequence must match, otherwise give an error
  value = Any[]
  for item in rule.values
    (child, pos, error) = parse(grammar, item, text, pos, cache)

    # check for error
    if error !== nothing
      return (nothing, firstPos, error)
    end

    if child !== nothing
      append!(value, unref(child))
    end
  end

  node = make_node(rule, text[firstPos:pos-1], firstPos, pos, value)
  return (node, pos, nothing)
end

function parse_newcachekey(grammar::Grammar, rule::Terminal, text::AbstractString, pos::Int, cache)
  local size::Int = length(rule.value)

  if ismatch(Regex("\^$(rule.value)"),text[pos:end])
    node = make_node(rule, text[pos:pos+size-1], pos, pos+size, [])
    return (node, pos+size, nothing)
  end

  len = min(pos+size-1, length(text))
  return (nothing, pos, ParseError("'$(text[pos:len])' does not match '$(rule.value)'. At pos: $pos"))
end

# TODO: look into making this more streamlined
function parse_newcachekey(grammar::Grammar, rule::OneOrMoreRule, text::AbstractString, pos::Int, cache)
  firstPos = pos
  (child, pos, error) = parse(grammar, rule.value, text, pos, cache)

  # make sure there is at least one
  if child === nothing
    return (nothing, pos, ParseError("No match (OneOrMoreRule) at pos: $pos"))
  end

  # and continue making matches for as long as we can
  children = unref(child)
  while error == nothing
    (child, pos, error) = parse(grammar, rule.value, text, pos, cache)

    if error === nothing && child !== nothing
      children = [children;collect(unref(child))]
    end
  end

  node = make_node(rule, text[firstPos:pos-1], firstPos, pos, children)
  return (node, pos, nothing)
end

function parse_newcachekey(grammar::Grammar, rule::ZeroOrMoreRule, text::AbstractString, pos::Int, cache)
  firstPos::Int = pos
  children::Array = Any[]

  error = nothing
  while error == nothing
    # FIXME: this was an error and now untested
    (child, pos, error) = parse(grammar, rule.value, text, pos, cache)

    if error === nothing && child !== nothing
      append!(children, unref(child))
    end
  end

  if length(children) > 0
    node = make_node(rule, text[firstPos:pos-1], firstPos, pos, children)
  else
    node = nothing
  end

  return (node, pos, nothing)
end

function parse_newcachekey(grammar::Grammar, rule::RegexRule, text::AbstractString, pos::Int, cache)
  firstPos = pos

  # use regex match
  if ismatch(rule.value, text[firstPos:end])
    value = match(rule.value, text[firstPos:end])

    if length(value.match) == 0
      # this means that we didn't match, but the regex was optional, so we don't want to give an
      # error
      return (nothing, firstPos, nothing)
    else
      pos += length(value.match)
      node = make_node(rule, text[firstPos:pos-1], firstPos, pos, [])

      return (node, pos, nothing)
    end
  else
    return (nothing, firstPos, ParseError("Could not match RegEx at pos: $pos"))
  end
end

function parse_newcachekey(grammar::Grammar, rule::OptionalRule, text::AbstractString, pos::Int, cache)
  (child, pos, error) = parse(grammar, rule.value, text, pos, cache)
  firstPos = pos

  if child !== nothing
    node = make_node(rule, text[firstPos:pos-1], firstPos, pos, unref(child))
    return (node, pos, error)
  end

  # no error, but we also don't move the position or return a valid node
  return (nothing, firstPos, nothing)
end

function parse_newcachekey(grammar::Grammar, rule::ListRule, text::AbstractString, pos::Int, cache)
  firstPos = pos

  # number of occurances
  count = 0

  error = nothing
  children = Any[]

  # continue making matches for as long as we can
  while error === nothing
    (child, pos, error) = parse(grammar, rule.entry, text, pos, cache)

    if child !== nothing
      append!(children, unref(child))
      (dchild, pos, error) = parse(grammar, rule.delim, text, pos, cache)
    else
      break
    end

    count += 1
  end

  if count < rule.min
    return (nothing, pos, ParseError("No match (ListRule) at pos: $pos"))
  end

  node = make_node(rule, text[firstPos:pos-1], firstPos, pos, children)
  return (node, pos, nothing)
end

function parse_newcachekey(grammar::Grammar, rule::SuppressRule, text::AbstractString, pos::Int, cache)
  # use rule contained in the SuppressRule to parse, but don't return anything
  (_, pos, error) = parse_newcachekey(grammar, rule.value, text, pos, cache)
  return (nothing, pos, error)
end

function parse_newcachekey(grammar::Grammar, rule::LookAheadRule, text::AbstractString, pos::Int, cache)
    (_, newPos, error) = parse_newcachekey(grammar, rule.value, text, pos, cache)
    if error !== nothing
        return (nothing, newPos, error)
    else
        return (nothing, pos, nothing)
    end
end

function parse_newcachekey(grammar::Grammar, rule::NotRule, text::AbstractString, pos::Int, cache)
  # try to parse rule
  (child, newpos, error) = parse(grammar, rule.entry, text, pos, cache)

  # if we match, it's an error
  if error == nothing
    error = ParseError("No match (NotRule) at pos: $pos")
  else
    # otherwise, return a success
    error = nothing
  end

  return (nothing, pos, error)
end

function parse_newcachekey(grammar::Grammar, rule::EmptyRule, text::AbstractString, pos::Int, cache)
  # need to explicitely call rule's action because nothing is consumed
  if rule.action != nothing
    rule.action(rule, "", pos, pos, [])
  end

  return (nothing, pos, nothing)
end

function parse_newcachekey(grammar::Grammar, rule::EndOfFileRule, text::AbstractString, pos::Int, cache)
  # need to explicitely call rule's action because nothing is consumed
  if pos == length(text)
    #rule.action(rule, value, first, last, children)
    rule.action(rule, "", length(text), length(text), [])
  end

  return (nothing, pos, nothing)
end

function parse_newcachekey(grammar::Grammar, rule::IntegerRule, text::AbstractString, pos::Int, cache)
  #rexpr = r"^[-+]?[0-9]+([eE][-+]?[0-9]+)?"
  # Julia treats anything with 'e' to be a float, so for now follow suit
  rexpr = r"^[-+]?[0-9]+"
  firstPos = pos

  # use regex match
  if ismatch(rexpr, text[firstPos:end])
    value = match(rexpr, text[firstPos:end])

    if length(value.match) != 0
      pos += length(value.match)
      node = make_node(rule, text[firstPos:pos-1], firstPos, pos, [])

      return (node, pos, nothing)
    end
  else
    return (nothing, firstPos, ParseError("Could not match IntegerRule at pos: $pos"))
  end
end

function parse_newcachekey(grammar::Grammar, rule::FloatRule, text::AbstractString, pos::Int, cache)
  rexpr = r"^[-+]?[0-9]*\.[0-9]+([eE][-+]?[0-9]+)?"
  firstPos = pos

  # use regex match
  if ismatch(rexpr, text[firstPos:end])
    value = match(rexpr, text[firstPos:end])

    if length(value.match) != 0
      pos += length(value.match)
      node = make_node(rule, text[firstPos:pos-1], firstPos, pos, [])

      return (node, pos, nothing)
    end
  else
    return (nothing, firstPos, ParseError("Could not match FloatRule at pos: $pos"))
  end
end
