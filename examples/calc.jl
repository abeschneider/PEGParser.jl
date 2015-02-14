using PEGParser

function abduct(i::Int64)
  return (node) -> Node(node.name, node.children[i].value, node.children[i].first, node.children[i].last, node.children[i].children, node.children[i].ruleType)
end

@grammar calcgrammar begin
  # start = (expr)[(ast) -> ast.children[1]]
  start = expr

  expr_op = term + op1 + expr
  # expr = (exprop | term)[(ast) -> ast.children[1]]
  expr = expr_op | term
  term_op = factor + op2 + term
  # term = (termop | factor)[(ast) -> ast.children[1]]
  term = term_op | factor
  # factor = (number | pfactor)[(ast) -> ast.children[1]]
  factor = number | pfactor
  # pfactor = (-lparen + expr + -rparen)[(ast) -> ast.children[1]]
  pfactor = -lparen + expr + -rparen

  # op1 = (add | sub)[1]
  op1 = add | sub
  # op2 = (mult | div)[1]
  op2 = mult | div

  # number = (-space + r"[1-9][0-9]*")[1]
  # add = (-space + "+")[1]
  # sub = (-space + "-")[1]
  # mult = (-space + "*")[1]
  # div = (-space + "/")[1]
  #   Node(name, value, first, last, children, typ)
  number = (-space + r"[1-9][0-9]*")[abduct(1)]
  add = (-space + "+")[abduct(1)]
  sub = (-space + "-")[abduct(1)]
  mult = (-space + "*")[abduct(1)]
  div = (-space + "/")[abduct(1)]

  lparen = space + "("
  rparen = space + ")"
  space = r"[ \n\r\t]*"
end

toexpr(node, cnodes, ::MatchRule{:default}) = cnodes
toexpr(node, cnodes, ::MatchRule{:termop}) = Expr(:call, cnodes[2], cnodes[1], cnodes[3])
toexpr(node, cnodes, ::MatchRule{:exprop}) = Expr(:call, cnodes[2], cnodes[1], cnodes[3])
toexpr(node, cnodes, ::MatchRule{:number}) = parseint(node.value)
toexpr(node, cnodes, ::MatchRule{:op1}) = symbol(node.value)
toexpr(node, cnodes, ::MatchRule{:op2}) = symbol(node.value)

data = "4+5*5*(4+3)"
(ast, pos, error) = parse(calcgrammar, data)
println(ast)

# code = transform(toexpr, ast)
# println(code)
# println(eval(code))
