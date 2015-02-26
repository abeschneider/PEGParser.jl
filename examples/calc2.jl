using PEGParser

@grammar calc2 begin
  start = expr { children[1] }

  expr_op = (term + op1 + expr) {
    apply(eval(children[2]), children[1], children[3])
  }

  expr = (expr_op | term) { children[1] }

  term_op = (factor + op2 + term) {
    apply(eval(children[2]), children[1], children[3])
  }

  term = (term_op | factor) { children[1] }
  factor = (number | pfactor) { children[1] }
  pfactor = (-lparen + expr + -rparen) { children[1] }

  op1 = (add | sub) { children[1] }
  op2 = (mult | div) { children[1] }

  number = (-space + r"[1-9][0-9]*") { parseint(children[1].value) }
  add = (-space + "+") { symbol(children[1].value) }
  sub = (-space + "-") { symbol(children[1].value) }
  mult = (-space + "*") { symbol(children[1].value) }
  div = (-space + "/") { symbol(children[1].value) }

  lparen = space + "("
  rparen = space + ")"
  space = r"[ \n\r\t]*"
end

data = "4+5*8"
(ast, pos, error) = parse(calc2, data)
println(ast)
