using PEGParser

# for testing purposes
# using DataFrames

@grammar csv begin
  start = list(record, crlf)
  record = list(field, comma)
  field = (escaped_field | unescaped_field)[(ast) -> ast.children]
  escaped_field = (-dquote + escaped_field_value + -dquote)[1]
  escaped_field_value = (r"[ ,\n\r!#$%&'()*+\-./0-~]+" | -dquote2)[1]
  unescaped_field = r"[ !#$%&'()*+\-./0-~]+"
  crlf = r"[\n\r]+"
  dquote = '"'
  dqoute2 = "\"\""
  comma = ','
end


toarrays(node::Node, cvalues, ::MatchRule{:default}) = cvalues
toarrays(node::Node, cvalues, ::MatchRule{:unescaped_field}) = node.value
toarrays(node::Node, cvalues, ::MatchRule{:escaped_field}) = node.value

data = """
1,2,3
4,5,6
this,is,a,"test and only a test"
"""

(ast, pos, error) = parse(csv, data, cache=false)
println(ast)
result = transform(toarrays, ast)
println("---------------")
println(result)
