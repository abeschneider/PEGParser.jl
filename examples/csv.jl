# CSV test

using EBNF
using PEGParser

function unroll(list)
  value = {list[1]}
  if length(list) > 1
    rest = list[2:end]
    value = append!(value, rest[1])
  end

  return value
end

@grammar csv begin
  start = data
  data = record + *(crlf + record)
  record = field + *(comma + field)
  field = escaped_field | unescaped_field
  escaped_field = dquote + *(textdata | comma | cr | lf | dqoute2) + dquote
  unescaped_field = textdata
  textdata = r"[ !#$%&'()*+\-./0-~]+"
  cr = '\r'
  lf = '\n'
  crlf = cr + lf
  dquote = '"'
  dqoute2 = "\"\""
  comma = ','
end

tr = Dict()

# want to ignore punctuation
tr["crlf"] = (node, children) -> nothing
tr["comma"] = (node, children) -> nothing

tr["escaped_field"] = (node, children) -> node.children[2].value
tr["unescaped_field"] = (node, children) -> node.children[1].value
tr["field"] = (node, children) -> children
tr["record"] = (node, children) -> unroll(children)
tr["data"] = (node, children) -> unroll(children)
tr["textdata"] = (node, children) -> node.value


parse_data = """
1,2,3\r\nthis is,a test,of csv\r\n"these","are","quotes ("")"
"""

(node, pos, error) = parse(csv, parse_data)
#println(node)

result = transform(tr, node)
println(result)