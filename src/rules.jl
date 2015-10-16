include("grammar.jl")
include("Node.jl")

function no_action(rule, value, first, last, children)
  return Node(rule.name, value, first, last, children, typeof(rule))
end

or_default_action(rule, value, first, last, children) = children[1]

# Terminal
type Terminal <: Rule
  name::AbstractString
  value::AbstractString
  action

  function Terminal(name::AbstractString, value::AbstractString)
    return new(name, SubString(value, 1), no_action);
  end

  function Terminal(name::AbstractString, value::Char)
    return new(name, "$value", no_action);
  end

  function Terminal(value::AbstractString)
    return new("", SubString(value, 1), no_action)
  end
end

function show(io::IO, t::Terminal)
  print(io, "$(t.value)");
end

function parseDefinition(name::AbstractString, value::AbstractString, pdata::ParserData)
  return Terminal(name, value)
end

function parseDefinition(name::AbstractString, value::Char, pdata::ParserData)
  return Terminal(name, value)
end

# References
type ReferencedRule <: Rule
  name::AbstractString
  symbol::Symbol
  action

  function ReferencedRule(name::AbstractString, symbol::Symbol)
    return new(name, symbol, no_action)
  end

  function ReferencedRule(symbol::Symbol)
    return new("", symbol, no_action)
  end
end

function parseDefinition(name::AbstractString, sym::Symbol, pdata::ParserData)
  fn = get(pdata.parsers, sym, nothing)

  if fn !== nothing
    return fn(name, pdata, [])
  end

  return ReferencedRule(name, sym)
end


# And
type AndRule <: Rule
  name::AbstractString
  values::Array{Rule}
  action

  function AndRule(name::AbstractString, values::Array{Rule})
    return new(name, values, no_action)
  end

  function AndRule(values::Array{Rule})
    return new("", values, no_action);
  end
end

get_children(rule::AndRule) = rule.values

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

function show(io::IO, rule::AndRule)
  values = [string(r) for r in rule.values]
  joinedValues = join(values, " ")
  print(io, "($(rule.name),$joinedValues,$(rule.action))");
end

# TODO: check if actually being used
+(a::Rule, b::Rule) = AndRule([a, b]);
+(a::AndRule, b::AndRule) = AndRule(append!(a.values, b.values));
+(a::AndRule, b::Rule) = AndRule(push!(a.values, b));
+(a::Rule, b::AndRule) = AndRule(push!(b.values, a));


# Or
type OrRule <: Rule
  name::AbstractString
  values::Array{Rule}
  action


  function OrRule(name::AbstractString, left::OrRule, right::OrRule)
    return new(name, append!(left.values, right.values), or_default_action)
  end

  function OrRule(name::AbstractString, left::OrRule, right::Rule)
    return new(name, push!(left.values, right), or_default_action)
  end

  function OrRule(name::AbstractString, left::Rule, right::OrRule)
    return new(name, [left, right], or_default_action)
  end

  function OrRule(name::AbstractString, left::Rule, right::Rule)
    return new(name, [left, right], or_default_action)
  end
end

get_children(rule::OrRule) = rule.values

function show(io::IO, rule::OrRule)
  values = [string(r) for r in rule.values]
  joinedValues = join(values, "|")
  print(io, "($(rule.name),$joinedValues,$(rule.action))")
end

function |(name::AbstractString, pdata::ParserData, args::Array)
  left = parseDefinition("$(name)_1", args[1], pdata)
  right = parseDefinition("$(name)_2", args[2], pdata)
  return OrRule(name, left, right)
end

function parseDefinition(name::AbstractString, range::UnitRange, pdata::ParserData)
  values = [Terminal(value) for value in range];
  return OrRule(name, values);
end

# OneOrMore
type OneOrMoreRule <: Rule
  name::AbstractString
  value::Rule
  action

  function OneOrMoreRule(name::AbstractString, value::Rule)
    return new(name, value, no_action)
  end

  function OneOrMoreRule(value::Rule)
    return new("", value, no_action);
  end
end

function show(io::IO, rule::OneOrMoreRule)
  print(io, "+($(rule.value))");
end


# ZeroOrMore
type ZeroOrMoreRule <: Rule
  name::AbstractString
  value::Rule
  action

  function ZeroOrMoreRule(name::AbstractString, value::Rule)
    return new(name, value, no_action)
  end

  function ZeroOrMoreRule(value::Rule)
    return new("", value, no_action);
  end
end

function show(io::IO, rule::ZeroOrMoreRule)
  print(io, "*($(rule.value))");
end

function *(name::AbstractString, pdata::ParserData, args::Array)
  if length(args) == 1
    # it's a prefix, so it maps to zero or more rule
    return ZeroOrMoreRule(parseDefinition(name, args[1], pdata))
  end
end


# Multiple
type MultipleRule <: Rule
  name::AbstractString
  value::Rule
  minCount::Int
  maxCount::Int
  action

  function MultipleRule(name::AbstractString, value::Rule, minCount::Int, maxCount::Int)
    return new(name, value, minCount, maxCount, no_action)
  end

  function MultipleRule(value::Rule, minCount::Int, maxCount::Int)
    return new("", value, minCount, maxCount, no_action)
  end
end

function show(io::IO, rule::MultipleRule)
  print(io, "($(rule.value)){$(rule.minCount), $(rule.maxCount)}");
end

function ^(name::AbstractString, pdata::ParserData, args::Array)
  # FIXME: not sure this is correct..
  count = args[2]
  return MultipleRule(args[1], count.args[1], count.args[2])
end


# RegEx
type RegexRule <: Rule
  name::AbstractString
  value::Regex
  action

  function RegexRule(name::AbstractString, value::Regex)
    return new(name, value, no_action)
  end

  function RegexRule(value::Regex)
    return new("", Regex("^$(value.pattern)"), no_action)
  end
end

function show(io::IO, rule::RegexRule)
  print(io, "r($(rule.value.pattern))")
end

function parseDefinition(name::AbstractString, regex::Regex, pdata::ParserData)
  # TODO: Need to do this to ensure we always match at the beginning,
  # but there should be a safer way to do this
  modRegex = Regex("^$(regex.pattern)")
  return RegexRule(name, modRegex)
end


# Optional
type OptionalRule <: Rule
  name::AbstractString
  value::Rule
  action

  function OptionalRule(name::AbstractString, value::Rule)
    return new(name, value, or_default_action)
  end

  function OptionalRule(value::Rule)
    return new("", value, or_default_action)
  end
end

function ?(name::AbstractString, pdata::ParserData, args::Array)
  return OptionalRule(parseDefinition(name, args[1], pdata))
end


# Look ahead
type LookAheadRule <: Rule
    name::AbstractString
    value::Rule
    action

    function LookAheadRule(name::AbstractString, value::Rule)
        return new(name, value, no_action)
    end
end

function >(name::AbstractString, pData::ParserData, args::Array)
    if length(args) == 1
        return LookAheadRule(name, parseDefinition("$(name)_value", args[1], pData))
    end
end

# Suppress
type SuppressRule <: Rule
  name::AbstractString
  value::Rule
  action

  function SuppressRule(name::AbstractString, value::Rule)
    return new(name, value, no_action)
  end
end

function -(name::AbstractString, pdata::ParserData, args::Array)
  if length(args) == 1
    return SuppressRule(name, parseDefinition("$(name)_value", args[1], pdata))
  end
end


# List
type ListRule <: Rule
  name::AbstractString
  entry::Rule
  delim::Rule
  min::Int
  action

  function ListRule(name::AbstractString, entry::Rule, delim::Rule)
    return new(name, entry, delim, 1, no_action)
  end

  function ListRule(name::AbstractString, entry::Rule, delim::Rule, min::Int)
    return new(name, entry, delim, min, no_action)
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

# Not
type NotRule <: Rule
  name
  entry
  action

  function NotRule(name::AbstractString, entry::Rule)
    return new(name, entry, no_action)
  end
end

function !(name::AbstractString, pdata::ParserData, args::Array)
  entry = parseDefinition("$(name)_entry", args[1], pdata)
  return NotRule(name, entry)
end

function show(io::IO, rule::NotRule)
  print(io, "!($(rule.entry))");
end

function empty(name::AbstractString, pdata::ParserData, args::Array)
  return EmptyRule(name)
end

type EndOfFileRule <: Rule
  name::AbstractString
  action

  EndOfFileRule(name::AbstractString) = new(name, no_action)
end

function eof(name::AbstractString, pdata::ParserData, args::Array)
  return EndOfFileRule(name)
end

# common parsers
type IntegerRule <: Rule
  name::AbstractString
  action

  IntegerRule(name::AbstractString) = new(name, no_action)
end

type FloatRule <: Rule
  name::AbstractString
  action

  FloatRule(name::AbstractString) = new(name, no_action)
end

function integer(name::AbstractString, pdata::ParserData, args::Array)
  return IntegerRule(name)
end

function float(name::AbstractString, pdata::ParserData, args::Array)
  return FloatRule(name)
end

macro grammar(name, definitions)
  parsers = [:+, :*, :?, :|, :-, :^, :!, :>, :list, :empty, :eof, :integer, :float]
  mapped_parsers = map_symbol_to_function(parsers)
  return parseGrammar(name, definitions, ParserData(mapped_parsers))
end

# by default don't show anything
displayValue{T <: Rule}(value, ::Type{T}) = ""

# except for terminals and regex
displayValue(value, ::Type{Terminal}) = "'$value',"
displayValue(value, ::Type{RegexRule}) = "'$value',"
displayValue(value, ::Type{IntegerRule}) = "$value,"
displayValue(value, ::Type{FloatRule}) = "$value,"


function map_symbol_to_function(lst)
  m = Dict{Symbol, Function}()
  for sym in lst
    m[sym] = eval(sym)
  end

  return m
end
