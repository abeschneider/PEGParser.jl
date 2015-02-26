using PEGParser

@grammar calc2 begin
  start = expr { _1 }

  expr_op = (term + op1 + expr) {
    apply(eval(_2), _1, _3)
  }

  expr = (expr_op | term) { _1 }

  term_op = (factor + op2 + term) {
    apply(eval(_2), _1, _3)
  }

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
(ast, pos, error) = parse(calc2, data)
println(ast)