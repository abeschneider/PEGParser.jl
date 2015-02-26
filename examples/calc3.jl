using PEGParser

@grammar calc3 begin
  start = expr { _1 }

  expr_op = term + op1 + expr
  expr = (expr_op | term) { _1 }
  term_op = factor + op2 + term

  term = (term_op | factor) { _1 }
  factor = (number | pfactor) { _1 }
  pfactor = (-lparen + expr + -rparen) { _1 }

  op1 = (add | sub) { _1 }
  op2 = (mult | div) { _1 }

  number = (-space + r"[1-9][0-9]*") { parseint(_1.value) }
  add = (-space + "+") { symbol(_1.value) }
  sub = (-space + "-") { symbol(_1.value) }
  mult = (-space + "*") { symbol(_1.value) }
  div = (-space + "/") { symbol(_1.value) }

  lparen = space + "("
  rparen = space + ")"
  space = r"[ \n\r\t]*"
end

data = "4+5*(8+2)"
(ast, pos, error) = parse(calc3, data)
println(ast)

toexpr(node, cnodes, ::MatchRule{:default}) = cnodes
toexpr(node, cnodes, ::MatchRule{:term_op}) = Expr(:call, cnodes[2], cnodes[1], cnodes[3])
toexpr(node, cnodes, ::MatchRule{:expr_op}) = Expr(:call, cnodes[2], cnodes[1], cnodes[3])

code = transform(toexpr, ast)
dump(code)
println(eval(code))
