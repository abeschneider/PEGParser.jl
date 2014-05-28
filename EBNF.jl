module EBNF

import Base.show
import Base.convert
import Base.getindex

export Grammar, @grammar, Rule, Terminal, OrRule, AndRule, ReferencedRule, OneOrMoreRule, ZeroOrMoreRule, MultipleRule, RegexRule, OptionalRule, show, convert, *, ?

abstract Rule

type Grammar
  rules::Dict{Symbol, Rule}
end

generateRuleName() = randstring(10)

type Terminal <: Rule
  name
  value

  function Terminal(value)
    return new(generateRuleName(), value);
  end
end

type ReferencedRule <: Rule
  name
  symbol

  function ReferencedRule(symbol)
    return new(generateRuleName(), symbol)
  end
end

type AndRule <: Rule
  name
  values

  function AndRule(value)
    return new(generateRuleName(), value);
  end
end

type OrRule <: Rule
  name
  values

  function OrRule(values)
    return new(generateRuleName(), values);
  end
end

type OneOrMoreRule <: Rule
  name
  value

  function OneOrMoreRule(value)
    return new(generateRuleName(), value);
  end
end

type ZeroOrMoreRule <: Rule
  name
  value

  function ZeroOrMoreRule(value)
    return new (generateRuleName(), value);
  end
end

type MultipleRule <: Rule
  name
  value
  minCount
  maxCount

  function MultipleRule(value, minCount, maxCount)
    return new(generateRuleName(), value, minCount, maxCount);
  end
end

type RegexRule <: Rule
  name
  value

  function RegexRule(value)
    return new(generateRuleName(), Regex("^$(value.pattern)"))
  end
end

type OptionalRule <: Rule
  name
  value

  function OptionalRule(value)
    return new(generateRuleName(), value)
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
  print(io, "r(rule.value.pattern)")
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

function parseDefinition(value::String)
  return Terminal(value);
end

function parseDefinition(value::Char)
  return Terminal(value);
end

function parseDefinition(symbol::Symbol)
  return ReferencedRule(symbol)
end

function parseDefinition(range::UnitRange)
  values = [Terminal(value) for value in range];
  return OrRule(values);
end

function parseDefinition(regex::Regex)
  return RegexRule(regex)
end

function parseDefinition(expr::Expr)
  # if it's a macro (e.g. r"regex", then we want to expand it first)
  if expr.head === :macrocall
    return parseDefinition(eval(expr))
  end

  if expr.args[1] === :|
    first = parseDefinition(expr.args[2]);
    second = parseDefinition(expr.args[3]);

    # Or is always handled in a binary manner
    return first | second;
  elseif expr.args[1] === :+
    # check if this is infix or prefix
    if length(expr.args) > 2
      # Addition can contain multiple entries
      values = [parseDefinition(arg) for arg in expr.args[2:end]]
      return reduce(+, values)
    else
      # it's prefix, so it maps to one or more rule
      return OneOrMoreRule(parseDefinition(expr.args[2]))
    end
  elseif expr.args[1] === :^
    # an entry can appear N:M times
    count = expr.args[3]
    return MultipleRule(expr.args[2], count.args[1], count.args[2]);
  elseif expr.args[1] === :* && length(expr.args) == 2
    # it's a prefix, so it maps to zero or more rule
    return ZeroOrMoreRule(parseDefinition(expr.args[2]))
  elseif expr.args[1] == :?
    return OptionalRule(parseDefinition(expr.args[2]))
  end
end

function parseGrammar(expr::Expr)
  rules = Dict()

  for definition in expr.args[2:2:end]
    rule = parseDefinition(definition.args[2])
    rule.name = string(definition.args[1])
    rules[string(definition.args[1])] = rule
  end

  return Grammar(rules)
end

macro grammar(name, expr)
  quote
    $(esc(name)) = $(parseGrammar(expr))
  end
end

function *(rule::Rule) end
function ?(rule::Rule) end

end
