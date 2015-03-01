using RunTests
using Base.Test

using PEGParser

# FIXME: Error "MatchRule not defined" occurs when @testmodule is used
# @testmodule TransformTests begin
function test_simple1()
  @grammar grammar begin
    start = list_content
    list_content = (list_label + list_values) { _2 }
    list_values = list(content, "," + space)
    space = r"[ \t]+"
    list_label = "list:" + -space
    content = r"[^,]+"
  end

  tolist(node, cvalues, ::MatchRule{:default}) = cvalues
  tolist(node, cvalues, ::MatchRule{:content}) = node.value

  data = "list: a, b, c"
  (ast, pos, error) = parse(grammar, data)
  result = transform(tolist, ast)
  @test result == {"a","b","c"}
end
# end

test_simple1()
