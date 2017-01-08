using PEGParser

function createRecord(rule,value,first,last,children)
  if length(children) == 0
    return String[]
  elseif length(children) == 1
    return children[1]
  else
    return append!([children[1]],children[2].children)
  end
end
csv = Grammar("""
  start => *((record & -(crlf)) {liftchild}) {childrenarray}
  record => ( field & *((-(',') & field){liftchild}) ) {Main.createRecord}
  field => ?(escaped_field | unescaped_field) {liftchild}

  escaped_field => (-('"') & escaped_field_value & -('"')) {liftchild}
  escaped_field_value => r([^"]+)r {nodevalue}
  unescaped_field => r([^\\n\\r,]+)r {nodevalue}

  crlf => r([\\n\\r]+)r
""")

data = """
1,2,3
4,5,6

this,is,a,"test and

only a test"
"""

(ast, pos, error) = parse(csv, data)
println("ast = $ast")
