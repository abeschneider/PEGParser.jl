using PEGParser

@grammar lispgrammar begin
  start = cell{ _1 }
  expr = lst | atom
  cell = list(expr, space)
  lst = (lparen + +(cell) + rparen){ _2.children }
  atom = string | boolean | number | sym
  boolean = ("#t" | "#f"){ _1 == "#t" ? true : false }
  number = (-space + float){ parse(Float64, _1.value) } | (-space + integer){ parse(Int, _1.value) }
  string = (dquote + r"[^\"]*" + dquote){ _2.value }
  sym = r"[^() ]+"{ symbol(_0) }

  dquote = "\""
  lparen = "("
  rparen = ")"
  space = r"[ \n\r\t]*"
end

toexpr(node, cvalues, ::MatchRule{:start}) = cvalues

function toexpr(node, cvalues, ::MatchRule{:cell})
  if length(cvalues) > 1
    return Expr(:call, cvalues...)
  else
    return cvalues[1]
  end
end

data = "(println \"test: \" (* 10 (- 5 6)))"
(ast, pos, error) = parse(lispgrammar, data)
println(ast)
code = transform(toexpr, ast)
dump(code)
println("code: $(code)")
eval(code)
