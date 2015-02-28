import Base.show
import Base.convert
import Base.getindex

abstract Rule

type Grammar
  rules::Dict{Symbol, Rule}
end

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

  if expr.head === :curly
    rule = parseDefinition(name, expr.args[1], pdata)
    rule.action = expr.args[2]
    return rule
  end

  fn = get(pdata.parsers, expr.args[1], nothing)

  if fn !== Nothing
    return fn(name, pdata, expr.args[2:end])
  end

  return (EmptyRule(), nothing)
end

function parseGrammar(grammar_name::Symbol, expr::Expr, pdata::ParserData)
  code = {}
  push!(code, :(rules = Dict()))

  for definition in expr.args[2:2:end]
    name = string(definition.args[1])
    ref_by_name = Expr(:ref, :rules, name)

    rule = parseDefinition(name, definition.args[2], pdata)
    rule_action = rule.action
    action_type = typeof(rule_action)

    rcode = quote
      rules[$name] = $(esc(rule))
      if $(esc(action_type)) !== Function
        rules[$name].action = (rule, value, first, last, children) -> begin
          if isa(children, Array)
            for (i, child) in enumerate(children)
              eval(Expr(:(=), symbol("_$i"), child))
            end
          end

          return $(rule_action)
        end
      else
        rules[$name].action = (rule, value, first, last, children) -> begin
          $(rule_action)(rule, value, first, last, children)
        end
      end
    end

    push!(code, rcode)
  end

  push!(code, :($(esc(grammar_name)) = Grammar(rules)))
  return Expr(:block, code...)
end
