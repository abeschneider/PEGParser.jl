abstract Rule

showRule(io::IO,name::AbstractString, def::AbstractString, action::AbstractString) =
  print(io, "$name => $def { $action }")

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
  showRule(io, t.name, "'$(t.value)')", string(t.action))
end

# References
type ReferencedRule <: Rule
  name::AbstractString
  symbol::Symbol
  action

  ReferencedRule(symbol::Symbol) = ReferencedRule("",symbol)
  function ReferencedRule(name::AbstractString, symbol::Symbol)
    return new(name, symbol, no_action)
  end
end

function show(io::IO, rule::ReferencedRule)
  showRule(io, rule.name, "$(rule.symbol) (ReferencedRule)", string(rule.action))
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


function show(io::IO, rule::AndRule)
  values = [r.name for r in rule.values]
  joinedValues = join(values, " & ")
  showRule(io, rule.name, joinedValues, string(rule.action))
end

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

function show(io::IO, rule::OrRule)
  values = [r.name for r in rule.values]
  joinedValues = join(values, " | ")
  showRule(io,rule.name, joinedValues, string(rule.action))
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
  showRule(io, rule.name, "+($(rule.value.name))", string(rule.action));
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
  showRule(io, rule.name, "r($(rule.value.pattern))", string(rule.action))
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


# Look ahead
type LookAheadRule <: Rule
    name::AbstractString
    value::Rule
    action

    function LookAheadRule(name::AbstractString, value::Rule)
        return new(name, value, no_action)
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

function show(io::IO, rule::SuppressRule)
  showRule(io, rule.name, "-($(rule.value))", string(rule.action))
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


# Not
type NotRule <: Rule
  name
  entry
  action

  function NotRule(name::AbstractString, entry::Rule)
    return new(name, entry, no_action)
  end
end

function show(io::IO, rule::NotRule)
  print(io, "!($(rule.entry))");
end


# EOF
type EndOfFileRule <: Rule
  name::AbstractString
  action

  EndOfFileRule(name::AbstractString) = new(name, no_action)
end


# empty rule is also accepted and never consumes
type EmptyRule <: Rule
  name
  action

  function EmptyRule(name::AbstractString="")
    return new(name)
  end
end


# common parser rules
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

function map_symbol_to_function(lst)
  m = Dict{Symbol, Function}()
  for sym in lst
    m[sym] = eval(sym)
  end

  return m
end
