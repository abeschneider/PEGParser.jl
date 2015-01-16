using PEGParser

@grammar lispgrammar begin
  start = (+(cell))[1]
  expr = (lst | atom)[(ast) -> ast.children[1]]
  cell = (-space + list(expr, space))[1]
  lst = (-lparen + +(cell) + -rparen)[1]
  atom = (boolean | integer | string | symbol)[(ast) -> ast.children[1]]
  boolean = "#t" | "#f"
  integer = r"[1-9][0-9]*"
  string = -dquote + r"[^\"]*" + -dquote
  symbol = r"[^() ]+"

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

function toexpr(node, cvalues, ::MatchRule{:lst})
  cvalues = cvalues[1]
  return Expr(:call, cvalues...)
end

data = "(println \"test: \" (* 10 (- 5 6)))"
(ast, pos, error) = parse(lispgrammar, data)
println(ast)
code = transform(toexpr, ast)
println("code = $(code)")
for line in code
  eval(line)
end
