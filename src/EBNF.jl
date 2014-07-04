module EBNF

import Base.show
import Base.convert
import Base.getindex

export Grammar, @grammar, @rule, Rule, Terminal, OrRule, AndRule, ReferencedRule, ListRule
export OneOrMoreRule, ZeroOrMoreRule, MultipleRule, RegexRule, OptionalRule, show, convert, *, ?, list
export addRuleType, displayRuleTypes

abstract Rule

type Grammar
  rules::Dict{Symbol, Rule}
end

immutable Terminal <: Rule
  name::String
  value::String

  function Terminal(name::String, value::String)
    return new(name, SubString(value, 1));
  end

  function Terminal(name::String, value::Char)
    return new(name, "$value");
  end

  function Terminal(value::String)
    return new("", SubString(value, 1));
  end
end

immutable ReferencedRule <: Rule
  name::String
  symbol::Symbol

  function ReferencedRule(name::String, symbol::Symbol)
    return new(name, symbol)
  end

  function ReferencedRule(symbol::Symbol)
    return new("", symbol)
  end
end

immutable AndRule <: Rule
  name::String
  values::Array{Rule}

  function AndRule(name::String, values::Array{Rule})
    return new(name, values)
  end

  function AndRule(values::Array{Rule})
    return new("", values);
  end
end

immutable OrRule <: Rule
  name::String
  values::Array{Rule}

  function OrRule(name::String, values::Array{Rule})
    return new(name, values)
  end

  function OrRule(values::Array{Rule})
    return new("", values);
  end
end

immutable OneOrMoreRule <: Rule
  name::String
  value::Rule

  function OneOrMoreRule(name::String, value::Rule)
    return new(name, value)
  end

  function OneOrMoreRule(value::Rule)
    return new("", value);
  end
end

immutable ZeroOrMoreRule <: Rule
  name::String
  value::Rule

  function ZeroOrMoreRule(name::String, value::Rule)
    return new(name, value)
  end

  function ZeroOrMoreRule(value::Rule)
    return new ("", value);
  end
end

immutable MultipleRule <: Rule
  name::String
  value::Rule
  minCount::Int64
  maxCount::Int64

  function MultipleRule(name::String, value::Rule, minCount::Int64, maxCount::Int64)
    return new(name, value, minCount, maxCount)
  end

  function MultipleRule(value::Rule, minCount::Int64, maxCount::Int64)
    return new("", value, minCount, maxCount);
  end
end

immutable RegexRule <: Rule
  name::String
  value::Regex

  function RegexRule(name::String, value::Regex)
    return new(name, value)
  end

  function RegexRule(value::Regex)
    return new("", Regex("^$(value.pattern)"))
  end
end

immutable OptionalRule <: Rule
  name::String
  value::Rule

  function OptionalRule(name::String, value::Rule)
    return new(name, value)
  end

  function OptionalRule(value::Rule)
    return new("", value)
  end
end

immutable ListRule <: Rule
  name::String
  entry::Rule
  delim::Rule

  function ListRule(name::String, entry::Rule, delim::Rule)
    return new(name, entry, delim)
  end
end

+(a::Rule, b::Rule) = AndRule([a, b]);
+(a::AndRule, b::AndRule) = AndRule(append!(a.values, b.values));
+(a::AndRule, b::Rule) = AndRule(push!(a.values, b));
+(a::Rule, b::AndRule) = AndRule(push!(b.values, a));

|(a::Rule, b::Rule) = OrRule([a, b]);
|(a::OrRule, b::OrRule) = OrRule(append!(a.values, b.values));
|(a::OrRule, b::Rule) = OrRule(push!(a.values, b));
|(a::Rule, b::OrRule) = OrRule(push!(b.values, a));

function show(io::IO, t::Terminal)
  print(io, "$(t.value)");
end

function show(io::IO, rule::AndRule)
  values = [string(r) for r in rule.values];
  joinedValues = join(values, " ");
  print(io, "($joinedValues)");
end

function show(io::IO, rule::OrRule)
  values = [string(r) for r in rule.values];
  joinedValues = join(values, "|");
  print(io, "($joinedValues)");
end

function show(io::IO, rule::OneOrMoreRule)
  print(io, "+($(rule.value))");
end

function show(io::IO, rule::ZeroOrMoreRule)
  print(io, "*($(rule.value))");
end

function show(io::IO, rule::MultipleRule)
  print(io, "($(rule.value)){$(rule.minCount), $(rule.maxCount)}");
end

function show(io::IO, rule::RegexRule)
  print(io, "r($(rule.value.pattern))")
end

function convert{T}(::Type{Rule}, n::T)
  return Terminal(n);
end

function convert{T<:Rule}(::Type{Rule}, n::T)
  return n;
end

function convert{T}(::Type{Rule}, n::UnitRange{T})
  terminals = [Terminal(i) for i=(n.start):(n.stop)];
  return OrRule(terminals);
end

function parseDefinition(name::String, value::String)
  return Terminal(name, value);
end

function parseDefinition(name::String, value::Char)
  return Terminal(name, value);
end

function parseDefinition(name::String, symbol::Symbol)
  return ReferencedRule(name, symbol)
end

function parseDefinition(name::String, range::UnitRange)
  values = [Terminal(value) for value in range];
  return OrRule(name, values);
end

function parseDefinition(name::String, regex::Regex)
  # TODO: Need to do this to ensure we always match at the beginning,
  # but there should be a safer way to do this
  modRegex = Regex("^$(regex.pattern)")
  return RegexRule(name, modRegex)
end

type EmptyRule <: Rule
end

function parseDefinition(name::String, expr::Expr)
  # if it's a macro (e.g. r"regex", then we want to expand it first)
  if expr.head === :macrocall
    return parseDefinition(name, eval(expr))
  end

  if expr.args[1] === :|
    left = parseDefinition("$name.1", expr.args[2])
    right = parseDefinition("$name.2", expr.args[3])
    rules::Array{Rule} = [left, right]
    return OrRule(name, rules)
  elseif expr.args[1] === :+
    # check if this is infix or prefix
    if length(expr.args) > 2
      # Addition can contain multiple entries
      values::Array{Rule} = [parseDefinition("$name.$i", arg) for (i, arg) in enumerate(expr.args[2:end])]
      return AndRule(name, values)
    else
      # it's prefix, so it maps to one or more rule
      return OneOrMoreRule(parseDefinition(name, expr.args[2]))
    end
  elseif expr.args[1] === :^
    # an entry can appear N:M times
    count = expr.args[3]
    return MultipleRule(expr.args[2], count.args[1], count.args[2]);
  elseif expr.args[1] === :* && length(expr.args) == 2
    # it's a prefix, so it maps to zero or more rule
    return ZeroOrMoreRule(parseDefinition(name, expr.args[2]))
  elseif expr.args[1] == :?
    return OptionalRule(parseDefinition(name, expr.args[2]))
  elseif expr.args[1] == :list
    entry = parseDefinition("$name.entry", expr.args[2])
    delim = parseDefinition("$name.delim", expr.args[3])
    return ListRule(name, entry, delim)
  end

  return EmptyRule()
end

function parseGrammar(expr::Expr)
  rules = Dict()

  for definition in expr.args[2:2:end]
    rule = parseDefinition(string(definition.args[1]), definition.args[2])
    rules[string(definition.args[1])] = rule
  end

  return Grammar(rules)
end

function parseTransform(expr::Expr)
  transform = Transform()

  for definition in expr.args[2:2:end]
    println("def = $definition")
  end
end

macro grammar(name::Symbol, expr)
  quote
    $(esc(name)) = $(parseGrammar(expr))
  end
end

function *(rule::Rule) end
function ?(rule::Rule) end
function list(entry::Rule, delim::Rule) end

end
