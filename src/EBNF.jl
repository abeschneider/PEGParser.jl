import Base.show
import Base.convert
import Base.getindex

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
  action

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

  function OrRule{T <: Rule}(name::String, rules::Array{T})
    return new(name, rules)
  end

  function OrRule(name::String, left::OrRule, right::OrRule)
    return new(name, vcat(left.values, right.values))
  end

  function OrRule(name::String, left::Rule, right::Rule)
    return new(name, [left, right])
  end

  function OrRule(name::String, left::OrRule, right::Rule)
    return new(name, vcat(left.values, right))
  end

  function OrRule(name::String, left::Rule, right::OrRule)
    return new(name, vcat(right.values, left))
  end

  function OrRule(name::String, left::OrRule, right::Terminal)
    return new(name, vcat(left.values, right.value))
  end

  function OrRule(name::String, left::Terminal, right::OrRule)
    return new(name, vcat(right.values, left.value))
  end

  function OrRule{T1, T2}(name::String, left::T1, right::T2)
    return new(name, [left, right])
  end
  # function OrRule(name::String, values::Array{Rule})
  #   return new(name, values)
  # end
  #
  # function OrRule(name::String, left, right)
  #   return new(name, vcat())
  #
  # function OrRule(values::Array{Rule})
  #   return new("", values);
  # end
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

immutable SuppressRule <: Rule
  name::String
  value::Rule

  function SuppressRule(name::String, value::Rule)
    return new(name, value)
  end
end

immutable SemanticActionRule <: Rule
  name::String
  rule::Rule
  action

  function SemanticActionRule(name::String, rule::Rule, action)
    return new(name, rule, action)
  end
end

immutable ListRule <: Rule
  name::String
  entry::Rule
  delim::Rule
  min::Int64

  function ListRule(name::String, entry::Rule, delim::Rule)
    return new(name, entry, delim, 1)
  end

  function ListRule(name::String, entry::Rule, delim::Rule, min::Int64)
    return new(name, entry, delim, min)
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

function parseDefinition(name::String, value::String, parsers)
  return Terminal(name, value);
end

function parseDefinition(name::String, value::Char, parsers)
  return Terminal(name, value);
end

function parseDefinition(name::String, symbol::Symbol, parsers)
  return ReferencedRule(name, symbol)
end

function parseDefinition(name::String, range::UnitRange, parsers)
  values = [Terminal(value) for value in range];
  return OrRule(name, values);
end

function parseDefinition(name::String, regex::Regex, parsers)
  # TODO: Need to do this to ensure we always match at the beginning,
  # but there should be a safer way to do this
  modRegex = Regex("^$(regex.pattern)")
  return RegexRule(name, modRegex)
end

type EmptyRule <: Rule
end

function |(name::String, parsers::Dict{Symbol, Function}, args::Array)
  left = parseDefinition("$name.1", args[1], parsers)
  right = parseDefinition("$name.2", args[2], parsers)
  return OrRule(name, left, right)
end

function +(name::String, parsers::Dict{Symbol, Function}, args::Array)
  if length(args) > 1
    # Addition can contain multiple entries
    values::Array{Rule} = [parseDefinition("$name.$i", arg, parsers) for (i, arg) in enumerate(args)]
    return AndRule(name, values)
  else
    # it's prefix, so it maps to one or more rule
    return OneOrMoreRule(name, parseDefinition("$name.values", args[1], parsers))
  end
end

function -(name::String, parsers::Dict{Symbol, Function}, args::Array)
  if length(args) == 1
    return SuppressRule(name, parseDefinition("$name.value", args[1], args))
  end
end

function ^(name::String, parsers::Dict{Symbol, Function}, args::Array)
  # FIXME: not sure this is correct..
  count = args[2]
  return MultipleRule(args[1], count.args[1], count.args[2])
end

function *(name::String, parsers::Dict{Symbol, Function}, args::Array)
  if length(args) == 1
    # it's a prefix, so it maps to zero or more rule
    return ZeroOrMoreRule(parseDefinition(name, args[1], parsers))
  end
end

function ?(name::String, parsers::Dict{Symbol, Function}, args::Array)
  return OptionalRule(parseDefinition(name, args[1], parsers))
end

function list(name::String, parsers::Dict{Symbol, Function}, args::Array)
  entry = parseDefinition("$name.entry", args[1], parsers)
  delim = parseDefinition("$name.delim", args[2], parsers)

  if length(args) > 2
    return ListRule(name, entry, delim, args[3], parsers)
  end

  return ListRule(name, entry, delim)
end

function parseDefinition(name::String, expr::Expr, parsers)
  # if it's a macro (e.g. r"regex", then we want to expand it first)
  if expr.head === :macrocall
    return parseDefinition(name, eval(expr), parsers)
  end

  # using indexing operation to select result of rule
  if expr.head === :ref
    rule = parseDefinition(name, expr.args[1], parsers)
    # select = eval(expr.args[2])
    action = expr.args[2]
    return SemanticActionRule("$name.sel", rule, action)
  end

  fn = get(parsers, expr.args[1], nothing)

  if fn !== Nothing
    return fn(name, parsers, expr.args[2:end])
  end

  return EmptyRule()
end

function parseGrammar(expr::Expr, parsers)
  rules = Dict()
  for definition in expr.args[2:2:end]
    rule = parseDefinition(string(definition.args[1]), definition.args[2], parsers)
    rules[string(definition.args[1])] = rule
  end

  return Grammar(rules)
end

function map_symbol_to_function(lst)
  m = Dict{Symbol, Function}()
  for sym in lst
    m[sym] = eval(sym)
  end

  return m
end

macro grammar(name::Symbol, args...)
  parsers = [:list, :+, :*, :?, :|, :-, :^]

  if length(args) == 1
    expr = args[1]
  elseif length(args) == 2
    # FIXME: can't eval here .. need to figure out how to add this code to
    # the generated macro code
     append!(parsers, eval(args[1]))
    expr = args[2]
  else
    # FIXME: make an exception
    println("error")
  end

  mapped_parsers = map_symbol_to_function(parsers)
  quote
    $(esc(name)) = $(parseGrammar(expr, mapped_parsers))
  end
end
