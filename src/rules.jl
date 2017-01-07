#########
# Rules #
#########

abstract Rule


type Terminal <: Rule
  name::AbstractString
  value::AbstractString
  action
end
Terminal(name::AbstractString, value) = Terminal(name, string(value), no_action)


type ReferencedRule <: Rule
  name::AbstractString
  symbol::Symbol
  action
end
ReferencedRule(name::AbstractString, symbol::Symbol) = ReferencedRule(name, symbol, no_action)


type AndRule <: Rule
  name::AbstractString
  values::Array{Rule}
  action
end
AndRule(name::AbstractString, values::Array{Rule}) = AndRule(name, values, no_action)
AndRule(name::AbstractString, left::Rule, right::Rule) = AndRule(name, [left, right], no_action)


type OrRule <: Rule
  name::AbstractString
  values::Array{Rule}
  action
end
OrRule(name::AbstractString, rules::Array) = OrRule(name,rules,liftchild)
OrRule(name::AbstractString, left::OrRule, right::OrRule) = OrRule(name, append!(left.values, right.values), liftchild)
OrRule(name::AbstractString, left::OrRule, right::Rule) = OrRule(name, push!(left.values, right), liftchild)
OrRule(name::AbstractString, left::Rule, right::OrRule) = OrRule(name, [left, right], liftchild)
OrRule(name::AbstractString, left::Rule, right::Rule) = OrRule(name, [left, right], liftchild)


type OneOrMoreRule <: Rule
  name::AbstractString
  value::Rule
  action
end


type ZeroOrMoreRule <: Rule
  name::AbstractString
  value::Rule
  action
end


type MultipleRule <: Rule
  name::AbstractString
  value::Rule
  minCount::Int
  maxCount::Int
  action
end
MultipleRule(name::AbstractString, value::Rule, minCount::Int, maxCount::Int) = MultipleRule(name, value, minCount, maxCount, no_action)


type RegexRule <: Rule
  name::AbstractString
  value::Regex
  action
end
RegexRule(name::AbstractString, value::Regex) = RegexRule(name, value, no_action)


type OptionalRule <: Rule
  name::AbstractString
  value::Rule
  action
end


type LookAheadRule <: Rule
    name::AbstractString
    value::Rule
    action
end


type SuppressRule <: Rule
  name::AbstractString
  value::Rule
  action
end


type ListRule <: Rule
  name::AbstractString
  entry::Rule
  delim::Rule
  min::Int
  action
end
ListRule(name::AbstractString, entry::Rule, delim::Rule, min::Int=1) = ListRule(name, entry, delim, min, no_action)


type NotRule <: Rule
  name
  entry
  action
end
NotRule(name::AbstractString, entry::Rule) = NotRule(name, entry, no_action)


type EndOfFileRule <: Rule
  name::AbstractString
  action
end


"""
    EmptyRule(name,action)
is a rule that never consumes
"""
type EmptyRule <: Rule
  name
  action
end


type IntegerRule <: Rule
  name::AbstractString
  action
end


type FloatRule <: Rule
  name::AbstractString
  action
end


################
# Constructors #
################

for rule in [FloatRule, IntegerRule, EmptyRule, EndOfFileRule]
  eval(parse("$rule(name::AbstractString) = $rule(name, no_action)"))
end

for rule in [SuppressRule, LookAheadRule, OptionalRule, ZeroOrMoreRule, OneOrMoreRule]
  eval(parse("$rule(name::AbstractString, value::Rule) = $rule(name, value, no_action)"))
end

for rule in subtypes(Rule)
  eval(parse("$rule(args...) = $rule(\"\", args...)"))
end


########
# show #
########

function showRule(io::IO,name::AbstractString, def::AbstractString, action::AbstractString) 
  namestring = ""
  if name != ""
    namestring = "$name: "
  end
  actionstring = ""
  if action != string(no_action)
    actionstring = " { $action }"
  end
  print(io, "$namestring$def$actionstring")
end
function showRuleDouble(io::IO,name::AbstractString, def::AbstractString, action::AbstractString) 
  namestring = ""
  if name != ""
    namestring = "$name: "
  end
  actionstring = ""
  parenth = ""
  if action != string(no_action)
    parenth = "("
    actionstring = ") { $action }"
  end
  print(io, "$namestring$parenth$def$actionstring")
end

show(io::IO, t::Terminal) = showRule(io, t.name, "'$(t.value)'", string(t.action))
show(io::IO, rule::ReferencedRule) = showRule(io, rule.name, "$(rule.symbol)", string(rule.action))
show(io::IO, rule::OneOrMoreRule) = showRule(io, rule.name, "+($(string(rule.value)))", string(rule.action));
show(io::IO, rule::OptionalRule) = showRule(io, rule.name, "?($(string(rule.value)))", string(rule.action));
show(io::IO, rule::ZeroOrMoreRule) = showRule(io, rule.name, "*($(string(rule.value)))", string(rule.action));
show(io::IO, rule::MultipleRule) = showRule(io, rule.name, "($(rule.value)){$(rule.minCount), $(rule.maxCount)}", string(rule.value));
show(io::IO, rule::RegexRule) = showRule(io, rule.name, "r($(rule.value.pattern))", string(rule.action))
show(io::IO, rule::SuppressRule) = showRule(io, rule.name, "-($(string(rule.value)))", string(rule.action))
show(io::IO, rule::NotRule) = showRule(io, rule.name, "!($(rule.entry))", string(rule.action))
function show(io::IO, rule::AndRule)
  values = [string(r) for r in rule.values]
  joinedValues = join(values, " & ")
  showRuleDouble(io, rule.name, joinedValues, string(rule.action))
end
function show(io::IO, rule::OrRule)
  values = [string(r) for r in rule.values]
  joinedValues = join(values, " | ")
  showRuleDouble(io,rule.name, joinedValues, string(rule.action))
end
