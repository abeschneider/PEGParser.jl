using PEGParser

@grammar calc3 begin
  start = expr{ _1 }

  expr_op = term + op1 + expr
  expr = expr_op | term
  term_op = factor + op2 + term

  term = term_op | factor
  factor = number | pfactor
  pfactor = (lparen + expr + rparen){ _2 }
  op1 = add | sub
  op2 = mult | div

  number = (-space + float){ parse(Float64, _1.value) } | (-space + integer){
    parse(Int, _1.value)
  }
  add = (-space + "+"){ symbol(_1.value) }
  sub = (-space + "-"){ symbol(_1.value) }
  mult = (-space + "*"){ symbol(_1.value) }
  div = (-space + "/"){ symbol(_1.value) }

  lparen = (-space + "("){ _1 }
  rparen = (-space + ")"){ _1 }
  space = r"[ \n\r\t]*"
end

data = "3.145+5*(6-4.0)"
(ast, pos, error) = parse(calc3, data)
println(ast)

toexpr(node, cnodes, ::MatchRule{:default}) = cnodes
toexpr(node, cnodes, ::MatchRule{:term_op}) = Expr(:call, cnodes[2], cnodes[1], cnodes[3])
toexpr(node, cnodes, ::MatchRule{:expr_op}) = Expr(:call, cnodes[2], cnodes[1], cnodes[3])

code = transform(toexpr, ast)
dump(code)
println(eval(code))
