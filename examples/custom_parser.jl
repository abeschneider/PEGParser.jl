using PEGParser
import PEGParser.uncached_parse
using Compat

type RepeatedRule <: Rule
  name::String
  rule
  action

  RepeatedRule(name::String, rule) = new(name, rule, no_action)
end

function repeated(name::String, pdata::ParserData, args::Array)
  rule = parseDefinition("$(name)_rule", args[1], pdata)
  return RepeatedRule(name, rule)
end

function uncached_parse(grammar::Grammar, rule::RepeatedRule, text::String, pos::Int64, cache)
  (ast, pos, error) = parse(grammar, rule.rule, text, pos, cache)
  if error !== nothing
    return (nothing, pos, ParseError("No match (RepeatedRule)", pos))
  end

  count = 1
  while error === nothing
    (ast, npos, error) = parse(grammar, rule.rule, text, pos, cache)
    if error === nothing
      count += 1
      pos = npos
    end
  end

  return (count, pos, nothing)
end

macro grammar(name, definitions)
  parsers = [:+, :*, :?, :|, :-, :^, :list, :integer, :float, :repeated]

  mapped_parsers = Dict{Symbol, Function}()
  for sym in parsers
    mapped_parsers[sym] = eval(sym)
  end

  return parseGrammar(name, definitions, ParserData(mapped_parsers))
end

@grammar custom begin
  start = repeated("abc") + -SPACE + integer
  SPACE = r"[ \t\n]+"
end

data = "abcabcabc 3"
(ast, pos, error) = parse(custom, data)

# value of our new rule should evaluate to the number of times we
# saw a repeat of the given text
@assert parse(Int, ast.children[1]) == parse(Int, ast.children[2].value)
