import Base.show
import Base.convert
import Base.getindex

abstract Rule

type Grammar
  rules::Dict{Symbol, Rule}
end





# function convert{T}(::Type{Rule}, n::T)
#   return Terminal(n);
# end
#
# function convert{T<:Rule}(::Type{Rule}, n::T)
#   return n;
# end
#
# function convert{T}(::Type{Rule}, n::UnitRange{T})
#   terminals = [Terminal(i) for i=(n.start):(n.stop)];
#   return OrRule(terminals);
# end

type EmptyRule <: Rule
end

type ParserData
  # map of parsers to use
  parsers

  # built up list of actions to resolve
  resolution_list
end

function parseDefinition(name::String, expr::Expr, pdata::ParserData)
  # if it's a macro (e.g. r"regex", then we want to expand it first)
  if expr.head === :macrocall
    return parseDefinition(name, eval(expr), pdata)
  end

  # using indexing operation to select result of rule
  if expr.head === :ref
    rule = parseDefinition(name, expr.args[1], pdata)
    # select = eval(expr.args[2])
    # rule.action = eval(expr.args[2])
    # println("fn = $(expr.args)")
    # rule.action = expr.args[2] #Expr(:escape, expr.args[2])
    rule.action = expr.args[2]
    #return SemanticActionRule("$name.sel", rule, action)
    return rule
  end

  fn = get(pdata.parsers, expr.args[1], nothing)

  if fn !== Nothing
    return fn(name, pdata, expr.args[2:end])
  end

  return (EmptyRule(), nothing)
end

function parseGrammar_old(expr::Expr, parsers)
  rules = Dict()
  for definition in expr.args[2:2:end]
    rule = parseDefinition(string(definition.args[1]), definition.args[2], parsers)

    rules[string(definition.args[1])] = rule
  end

  return Grammar(rules)
end

function parseGrammar(grammar_name::Symbol, expr::Expr, pdata::ParserData)
  code = {}
  push!(code, :(rules = Dict()))
  for definition in expr.args[2:2:end]
    # name = Expr(:call, :string, Expr(:quote, definition.args[1]))
    name = string(definition.args[1])
    # ex = Expr(:quote, definition.args[2])

    # rules[name] = parseDefinition(name, ex, nothing)
    ref_by_name = Expr(:ref, :rules, name)

    # maybe call this function directly, but encode the rule? this way
    # the action may be captured..
    # parse_call = Expr(:call, :parseDefinition, name, ex, pdata)
    # rule = parseDefinition(name, definition.args[2], pdata)

    # println("name = $name")
    # println("ex = $ex")
    # push!(code, Expr(:(=), :rule, parse_call))
    # Expr(:ref, :rules, name)

    # act = Expr(:(.), :rule, :(:action))
    # push!(code, Expr(:call, :println, act)) #Expr(:call, act, nothing)))
    # push!(code, Expr(:call, :println, Expr(:call, :eval, Expr(:quote, act))))
    # push!(code, Expr(:call, :println, Expr(:call, :names, Main)))
    # push!(code, esc(Expr(:call, :println, Expr(:call, :eval, act))))
    # push!(code, Expr(:(=),
    #               Expr(:(.), :rule, :(:action)),
    #               esc(Expr(:call, :eval, Expr(:(.), :rule, :(:action))))))

    # push!(code, :(action = rule.action))
    # push!(code, :(rule.action = eval($(esc(action)))))
    # push!(code, Expr(:(=), Expr(:ref, :rules, name), :rule))

    rule = parseDefinition(name, definition.args[2], pdata)
    rcode = quote
      # rule =
      # rule.action = eval(rule.action)
      rules[$name] = $(esc(rule))
      # tmp = $(esc(rules[name].action))
      # ex = rules[$name].action
      rules[$name].action = eval($(esc(rule.action)))
      # println("action = $(rules[$name].action)")
    end

    push!(code, rcode)

    # println(rcode)

    # something like..?
    # push!(code, Expr(:(=), :tmp, rule))
    # push!(rule.action = eval(rule.action))?
    # push!(code, :(rule = parseDefinition($name, :($(definition.args[2])), $pdata)))
    # push!(code, :(rule.action = eval(rule)))
    # push!(code, :(rules[$name] = rule))

    # println("rule.action = $(rule.action)")
    # println(quote
    #   rule.action = eval(rule.action)
    # end)

    # push!(code, Expr(:(=), ref_by_name, rule))
  end

  # grammar_name = Grammar(rules)
  # push!(code, :($(esc(grammar_name)) = Grammar(rules)))
  push!(code, :($(esc(grammar_name)) = Grammar(rules)))

  # group all code into a single block
  return Expr(:block, code...)
end
