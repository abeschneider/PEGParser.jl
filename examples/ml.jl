using PEGParser

@grammar mlgrammar begin
  start = +(cell)
  expr = lst | atom
  cell = space + list(expr, space)
  # multicell = +(cell)
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
toexpr(node, cvalues, ::MatchRule{:expr}) = cvalues[1]
toexpr(node, cvalues, ::MatchRule{:cell}) = cvalues[1]
toexpr(node, cvalues, ::MatchRule{:delimiter}) = cvalues[1]
toexpr(node, cvalues, ::MatchRule{:atom}) = cvalues[1]
toexpr(node, cvalues, ::MatchRule{:start}) = cvalues[1]
toexpr(node, cvalues, ::MatchRule{:multicell}) = cvalues[1]
toexpr(node, cvalues, ::MatchRule{:boolean}) = node.value == "#t" ? true : false
toexpr(node, cvalues, ::MatchRule{:integer}) = parseint(node.value)
toexpr(node, cvalues, ::MatchRule{:string}) = node.value[2:end-1]
toexpr(node, cvalues, ::MatchRule{:symbol}) = symbol(node.value)

function toexpr(node, cvalues, ::MatchRule{:lst})
  cvalues = cvalues[1][1]
  return Expr(:call, cvalues[1], cvalues[2], cvalues[3])
end

# data = "(+ 1 (- 5 6)) (* 3 4)"
data = "(+ 1 2)"
(ast, pos, error) = parse(mlgrammar, data, cache=false)
# println(ast)
code = transform(toexpr, ast, ignore={:space, :dquote, :lparen, :rparen})
println("code = $(code)")
# for line in code
#   println(eval(line))
# end
