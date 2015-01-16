using PEGParser

# @grammar calc begin
#   start = expr
#   number = r"([0-9]+)"
#   expr = (term + op1 + expr) | term
#   term = (factor + op2 + term) | factor
#   factor = number | pfactor
#   pfactor = lparen + expr + rparen
#   op1 = '+' | '-'
#   op2 = '*' | '/'
#   lparen = "("
#   rparen = ")"
# end


@grammar calcgrammar begin
  start = expr
  # value = number | expr

  # expr = -lparen + op + value + value + -rparen
  expr = ((term + op1 + expr) | term)[1]
  term = (factor + op2 + term) | factor
  factor = (number | pfactor)[1]
  pfactor = (-lparen + expr + -rparen)[(ast) -> ast.children[1]]

  op1 = (add | sub)[1]
  op2 = (mult | div)[1]

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
toexpr(node, cnodes, ::MatchRule{:expr}) = Expr(:call, cnodes[2], cnodes[1], cnodes[3])
toexpr(node, cnodes, ::MatchRule{:number}) = parseint(node.value)
toexpr(node, cnodes, ::MatchRule{:op1}) = symbol(node.value)
toexpr(node, cnodes, ::MatchRule{:op2}) = symbol(node.value)


data = "4+(3/4)"
(ast, pos, error) = parse(calcgrammar, data)
println(ast)

code = transform(toexpr, ast)
println(code)
# println(eval(code))
