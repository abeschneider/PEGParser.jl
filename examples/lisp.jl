using PEGParser

lispgrammar = Grammar("""
  start => expr { liftchild }
  expr => lst | atom

  lst => (-('(') & lstcontent & -(')')){ liftchild }
  atom => string | boolean | number | sym

  lstcontent => (expr & *((-(space) & expr){liftchild}) {"arguments"}) {"list"}
  string => (-('"') & r([^"]*)r & -('"')){ (r,v,f,l,c) -> c[1].value}
  boolean => ('#t' | '#f') { (r,v,f,l,c) -> v=="#t" }
  number => (-(space) & float){liftchild} | (-(space) & int){liftchild}
  sym => r([^() ]+)r {(r,v,f,l,c) -> getfield(Main,Symbol(v))}

  space => r([ \\n\\r\\t]*)r
""",standardrules)

toexpr(node, children, ::MatchRule{:arguments}) = children
function toexpr(node, children, ::MatchRule{:list})
  if length(children) == 1
    return children[1]
  else
    return children[1](children[2]...)
  end
end

data = "(println \"test: \" (* 10 (- 5 6)))"

println("AST")
println("===")
(ast, pos, error) = parse(lispgrammar, data)
println(ast)

println("RESULT")
println("======")
evaluated = transform(toexpr, ast)
