using PEGParser

calc2 = Grammar("""
  start => (number & op & number){(r,v,f,l,c) -> c[2](c[1],c[3])}

  op => plus | minus
  number => (-(space) & r([0-9]+)r) {(r,v,f,l,c) -> parse(Int,c[1].value)}
  plus => (-(space) & '+'){(a...) -> +}
  minus => (-(space) & '-'){(a...) -> -}
  space => r([ \\t\\n\\r]*)r
""")

data = "4+5"

(ast, pos, error) = parse(calc2, data)
println(ast)
