abstract Rule

showRule(io::IO,name::AbstractString, def::AbstractString, action::AbstractString) =
  print(io, "$name => $def { $action }")

# Terminal
type Terminal <: Rule
  name::AbstractString
  value::AbstractString
  action
end
Terminal(name::AbstractString, value) = Terminal(name, string(value), no_action)
Terminal(value::AbstractString) = Terminal("",value)

function show(io::IO, t::Terminal)
  showRule(io, t.name, "'$(t.value)')", string(t.action))
end

# References
type ReferencedRule <: Rule
  name::AbstractString
  symbol::Symbol
  action
end
ReferencedRule(name::AbstractString, symbol::Symbol) = ReferencedRule(name, symbol, no_action)
ReferencedRule(symbol::Symbol) = ReferencedRule("",symbol)

function show(io::IO, rule::ReferencedRule)
  showRule(io, rule.name, "$(rule.symbol) (ReferencedRule)", string(rule.action))
end

# And
type AndRule <: Rule
  name::AbstractString
  values::Array{Rule}
  action
end
AndRule(name::AbstractString, values::Array{Rule}) = AndRule(name, values, no_action)
AndRule(values::Array{Rule}) = AndRule("",values)

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
end
OrRule(name::AbstractString, left::OrRule, right::OrRule) = OrRule(name, append!(left.values, right.values), or_default_action)
OrRule(name::AbstractString, left::OrRule, right::Rule) = OrRule(name, push!(left.values, right), or_default_action)
OrRule(name::AbstractString, left::Rule, right::OrRule) = OrRule(name, [left, right], or_default_action)
OrRule(name::AbstractString, left::Rule, right::Rule) = OrRule(name, [left, right], or_default_action)

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
end
OneOrMoreRule(name::AbstractString, value::Rule) = OneOrMoreRule(name, value, no_action)
OneOrMoreRule(value::Rule) = OneOrMoreRule("",value)

function show(io::IO, rule::OneOrMoreRule)
  showRule(io, rule.name, "+($(rule.value.name))", string(rule.action));
end


# ZeroOrMore
type ZeroOrMoreRule <: Rule
  name::AbstractString
  value::Rule
  action
end
ZeroOrMoreRule(name::AbstractString, value::Rule) = ZeroOrMoreRule(name, value, no_action)
ZeroOrMoreRule(value::Rule) = ZeroOrMoreRule("", value)

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
end
MultipleRule(name::AbstractString, value::Rule, minCount::Int, maxCount::Int) = MultipleRule(name, value, minCount, maxCount, no_action)
MultipleRule(value::Rule, minCount::Int, maxCount::Int) = MultipleRule("", value, minCount, maxCount)

function show(io::IO, rule::MultipleRule)
  print(io, "($(rule.value)){$(rule.minCount), $(rule.maxCount)}");
end

# RegEx
type RegexRule <: Rule
  name::AbstractString
  value::Regex
  action
end
RegexRule(name::AbstractString, value::Regex) = RegexRule(name, value, no_action)
RegexRule(value::Regex) = RegexRule("", Regex("^$(value.pattern)"))

function show(io::IO, rule::RegexRule)
  showRule(io, rule.name, "r($(rule.value.pattern))", string(rule.action))
end


# Optional
type OptionalRule <: Rule
  name::AbstractString
  value::Rule
  action
end
OptionalRule(name::AbstractString, value::Rule) = OptionalRule(name, value, or_default_action)
OptionalRule(value::Rule) = OptionalRule("", value)


# Look ahead
type LookAheadRule <: Rule
    name::AbstractString
    value::Rule
    action
end
LookAheadRule(name::AbstractString, value::Rule) = LookAheadRule(name, value, no_action)


# Suppress
type SuppressRule <: Rule
  name::AbstractString
  value::Rule
  action
end
SuppressRule(name::AbstractString, value::Rule) = SuppressRule(name, value, no_action)

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
end
ListRule(name::AbstractString, entry::Rule, delim::Rule, min::Int=1) = ListRule(name, entry, delim, min, no_action)


# Not
type NotRule <: Rule
  name
  entry
  action
end
NotRule(name::AbstractString, entry::Rule) = NotRule(name, entry, no_action)

function show(io::IO, rule::NotRule)
  print(io, "!($(rule.entry))");
end


# EOF
type EndOfFileRule <: Rule
  name::AbstractString
  action
end
EndOfFileRule(name::AbstractString) = new(name, no_action)


# empty rule is also accepted and never consumes
type EmptyRule <: Rule
  name
  action
end
EmptyRule(name::AbstractString="") = EmptyRule(name,no_action)


# common parser rules
type IntegerRule <: Rule
  name::AbstractString
  action
end
IntegerRule(name::AbstractString) = IntegerRule(name, no_action)

type FloatRule <: Rule
  name::AbstractString
  action
end
FloatRule(name::AbstractString) = FloatRule(name, no_action)

