using PEGParser

@grammar calcgrammar begin
  start = expr
  value = number | expr

  expr = -lparen + op + value + value + -rparen
  op = add | sub | mult | div

  number = (-space + r"[1-9][0-9]*")[1]
  add = (-space + "+")[1]
  sub = (-space + "-")[1]
  mult = (-space + "*")[1]
  div = (-space + "/")[1]
  lparen = space + "("
  rparen = space + ")"
  space = r"[ \n\r\t]*"
end

toexpr(node, cnodes, ::MatchRule{:default}) = cnodes
toexpr(node, cnodes, ::MatchRule{:start}) = cnodes[1]
toexpr(node, cnodes, ::MatchRule{:value}) = cnodes[1]
toexpr(node, cnodes, ::MatchRule{:expr}) = Expr(:call, cnodes...)
toexpr(node, cnodes, ::MatchRule{:number}) = parseint(node.value)
toexpr(node, cnodes, ::MatchRule{:op}) = symbol(node.value)

data = "(+ (/ 4 3) 5)"
(ast, pos, error) = parse(calcgrammar, data)
println(ast)

code = transform(toexpr, ast)
println(eval(code))
