###################
# parseDefinition #
###################

"""
    parseDefinition(name, expr, ParserData)
returns the `Rule` object corresponding to the expr in the expression block given to `parseGrammar` (see there for more details). Overloading of this function allows to specify which exprs get turned into which rules.
"""
# FIXME: There is a weird mismatch in the parsers and parseDefinition..
# should they really be different? if not, parseDefinition might need
# to be changed to allow for arrays to be passed in
function parseDefinition(name::AbstractString, expr::Expr, pdata::ParserData)
  rule = EmptyRule()

  # if it's a macro (e.g. r"regex", then we want to expand it first)
  if expr.head === :macrocall
    # FIXME: using an evil eval
    rule = parseDefinition(name, eval(expr), pdata)
  elseif expr.head === :curly
    rule = parseDefinition(name, expr.args[1], pdata)
    rule.action = expand_names(expr.args[2])
  else
    parser = get(pdata.parsers, expr.args[1], nothing)

    if parser !== nothing
      rule = parser(name, pdata, expr.args[2:end])
    end
  end

  return rule
end

function parseDefinition(name::AbstractString, value::Union{AbstractString,Char}, pdata::ParserData)
  return Terminal(name, value)
end

function parseDefinition(name::AbstractString, sym::Symbol, pdata::ParserData)
  fn = get(pdata.parsers, sym, nothing)

  if fn !== nothing
    return fn(name, pdata, [])
  end

  return ReferencedRule(name, sym)
end

function parseDefinition(name::AbstractString, range::UnitRange, pdata::ParserData)
  values = [Terminal(value) for value in range];
  return OrRule(name, values);
end

function parseDefinition(name::AbstractString, regex::Regex, pdata::ParserData)
  # TODO: Need to do this to ensure we always match at the beginning,
  # but there should be a safer way to do this
  modRegex = Regex("^$(regex.pattern)")
  return RegexRule(name, modRegex)
end

# get_children
get_children(rule::Rule) = []
get_children(rule::AndRule) = rule.values
get_children(rule::OrRule) = rule.values

###########
# parsers #
###########
function +(name::AbstractString, pdata::ParserData, args::Array)
  if length(args) > 1
    # Addition can contain multiple entries
    values::Array{Rule} = [parseDefinition("$(name)_$i", arg, pdata) for (i, arg) in enumerate(args)]
    return AndRule(name, values)
  else
    # it's prefix, so it maps to one or more rule
    return OneOrMoreRule(name, parseDefinition("$(name)_values", args[1], pdata))
  end
end

function |(name::AbstractString, pdata::ParserData, args::Array)
  left = parseDefinition("$(name)_1", args[1], pdata)
  right = parseDefinition("$(name)_2", args[2], pdata)
  return OrRule(name, left, right)
end

function *(name::AbstractString, pdata::ParserData, args::Array)
  if length(args) == 1
    # it's a prefix, so it maps to zero or more rule
    return ZeroOrMoreRule(parseDefinition(name, args[1], pdata))
  end
end

function ^(name::AbstractString, pdata::ParserData, args::Array)
  # FIXME: not sure this is correct..
  count = args[2]
  return MultipleRule(args[1], count.args[1], count.args[2])
end

function ?(name::AbstractString, pdata::ParserData, args::Array)
  return OptionalRule(parseDefinition(name, args[1], pdata))
end

function >(name::AbstractString, pData::ParserData, args::Array)
    if length(args) == 1
        return LookAheadRule(name, parseDefinition("$(name)_value", args[1], pData))
    end
end

function -(name::AbstractString, pdata::ParserData, args::Array)
  if length(args) == 1
    return SuppressRule(name, parseDefinition("$(name)_value", args[1], pdata))
  end
end

function list(name::AbstractString, pdata::ParserData, args::Array)
  entry = parseDefinition("$(name)_entry", args[1], pdata)
  delim = parseDefinition("$(name)_delim", args[2], pdata)

  if length(args) > 2
    return ListRule(name, entry, delim, args[3])
  end

  return ListRule(name, entry, delim)
end

function !(name::AbstractString, pdata::ParserData, args::Array)
  entry = parseDefinition("$(name)_entry", args[1], pdata)
  return NotRule(name, entry)
end

function empty(name::AbstractString, pdata::ParserData, args::Array)
  return EmptyRule(name)
end

function eof(name::AbstractString, pdata::ParserData, args::Array)
  return EndOfFileRule(name)
end

function integer(name::AbstractString, pdata::ParserData, args::Array)
  return IntegerRule(name)
end

function float(name::AbstractString, pdata::ParserData, args::Array)
  return FloatRule(name)
end

# TODO: check if actually being used
+(a::Rule, b::Rule) = AndRule([a, b]);
+(a::AndRule, b::AndRule) = AndRule(append!(a.values, b.values));
+(a::AndRule, b::Rule) = AndRule(push!(a.values, b));
+(a::Rule, b::AndRule) = AndRule(push!(b.values, a));
