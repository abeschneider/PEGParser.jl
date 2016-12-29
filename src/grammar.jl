import Base.show
import Base.convert
import Base.getindex
#using Compat

abstract Rule

# by default no children
get_children(rule::Rule) = []

type Grammar
  rules::Dict{Symbol, Rule}
end

function show(io::IO,grammar::Grammar)
  println("PEGParser.Grammar(Dict{Symbol,PEGParser.Rule}(")
  for (sym,rule) in grammar.rules 
    print("  ")
    show(rule)
    println(",")
  end
  println(")")
end

# empty rule is also accepted and never consumes
type EmptyRule <: Rule
  name
  action

  function EmptyRule(name::AbstractString="")
    return new(name)
  end
end

"map of parsers to use"
type ParserData
  parsers
end

# general case, just return value
expand_names(value) = value

# if it's a symbol, check that it matches, and if so, convert it
function expand_names(sym::Symbol)
  m = match(r"_(\d+)", string(sym))
  if m !== nothing
    i = parse(Int, m.captures[1])

    return i == 0 ? :(value) : :(children[$i])
  end
  return sym
end

# if it's an expression, recursively go through tree and
# transform all symbols that match '_i'
function expand_names(expr::Expr)
  new_args = [expand_names(arg) for arg in expr.args]
  return Expr(expr.head, new_args...)
end

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

function collect_rules(rule::Rule, lst::Array)
  push!(lst, rule)

  for child in get_children(rule)
    collect_rules(child, lst)
  end

  return lst
end

"""
   parseGrammar(grammar_name::Symbol, expr::CodeBlock, pdata::ParserData)

parses the block of code `expr = begin ... end` as a grammar definition block. The result is a new block of code, which when evaluated defines the grammar `grammar_name` accordingly.
"""
function parseGrammar(grammar_name::Symbol, expr::Expr, pdata::ParserData)
  code = Any[]
  push!(code, :(rules = Dict()))

  all_rules = Rule[]

  for definition in expr.args[2:2:end]
    name = string(definition.args[1])
    ref_by_name = Expr(:ref, :rules, name)

    rule = parseDefinition(name, definition.args[2], pdata)
    push!(code, :(rules[$name] = $rule))
    all_rules = collect_rules(rule, all_rules)
  end

  for rule in all_rules
    if typeof(rule.action) != Function
      dot = Expr(:(.), rule, QuoteNode(:action))
      fn = Expr(:(->),
        Expr(:tuple, :rule, :value, :first, :last, :children),
        Expr(:block, rule.action))
      push!(code, Expr(:escape, Expr(:(=), dot, fn)))
    end
  end

  push!(code, :($(esc(grammar_name)) = Grammar(rules)))

  return Expr(:block, code...)
end
