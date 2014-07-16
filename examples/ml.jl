using EBNF
using PEGParser

@grammar mlgrammar begin
  start = +(cell)
  cell = space + list(lst | atom, space)
  lst = lparen + +(cell) + rparen
  atom = boolean | integer | string | symbol
  boolean = "#t" | "#f"
  integer = r"[1-9][0-9]*"
  string = dquote + r"[^\"]*" + dquote
  symbol = r"[^() ]+"
  delimiter = lparen | rparen | space

  dquote = "\""
  lparen = "("
  rparen = ")"
  space = r"[ \n\r\t]*"
end


toexpr(node, cvalues, ::MatchRule{:default}) = cvalues
toexpr(node, cvalues, ::MatchRule{:boolean}) = node.value == "#t" ? true : false
toexpr(node, cvalues, ::MatchRule{:integer}) = parseint(node.value)
toexpr(node, cvalues, ::MatchRule{:string}) = node.value[2:end-1]
toexpr(node, cvalues, ::MatchRule{:symbol}) = symbol(node.value)
toexpr(node, cvalues, ::MatchRule{:lst}) = Expr(:call, cvalues[1], cvalues[2], cvalues[3])

data = "(+ 1 (- 5 6)) (* 3 4)"
(ast, pos, error) = parse(mlgrammar, data)
code = transform(toexpr, ast, ignore={:space, :dquote, :lparen, :rparen})

for line in code
  println(eval(line))
end
