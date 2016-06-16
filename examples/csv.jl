using PEGParser

@grammar csv begin
  start = list(record, crlf){ children }
  record = list(field, comma){ AbstractString[children...] }
  field = escaped_field | unescaped_field
  escaped_field = (dquote + escaped_field_value + dquote){ _2 }
  escaped_field_value = r"[ ,\n\r!#$%&'()*+\-./0-~]+|\"\""{ _0 }
  unescaped_field = r"[ !#$%&'()*+\-./0-~]+"{ _0 }
  crlf = r"[\n\r]+"
  dquote = '"'
  dqoute2 = "\"\""
  comma = ','
end

data = """
1,2,3
4,5,6
this,is,a,"test and

only a test"
"""

(ast, pos, error) = parse(csv, data)
println("ast = $ast")
