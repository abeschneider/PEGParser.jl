using PEGParser

calc1 = Grammar("""
  start => (number & op & number) {"start"}

  op => (plus | minus) {"op"}
  number => (-(space) & r([0-9]+)r) {"number"}
  plus => (-(space) & '+') {"plus"}
  minus => (-(space) & '-') {"minus"}
  space => r([ \\t\\n\\r]*)r 
""")
toresult(node,children,::MatchRule{:default}) = node.value
toresult(node,children,::MatchRule{:number}) = parse(Int,node.value)
toresult(node,children,::MatchRule{:plus}) = +
toresult(node,children,::MatchRule{:minus}) = -
toresult(node,children,::MatchRule{:start}) = children[2](children[1],children[3])

data = "4+5"

(ast, pos, error) = parse(calc1, data)
transformed = transform(toresult,ast)
println(transformed)
