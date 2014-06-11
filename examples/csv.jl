using EBNF
using PEGParser

# for testing purposes
# using DataFrames

function flatten(list)
#   print("flatten: $list")
#   print(" [$(length(list))]")
  value = {list[1]}
  if length(list) == 2
    if length(list[2]) == 1
      push!(value, list[2])
    else
      append!(value, list[2])
    end
  elseif length(list) > 2
    append!(value, list[2:end])
  end

  return value
end

@grammar csv begin
  start = data
  data = record + *(crlf + record)
  record = field + *(comma + ?(field))
  field = escaped_field | unescaped_field
  escaped_field = dquote + *(textdata | comma | cr | lf | dqoute2) + dquote
  unescaped_field = textdata
  textdata = r"[ !#$%&'()*+\-./0-~]+"
  cr = '\r'
  lf = '\n'
  crlf = +(cr + lf | cr | lf)
  dquote = '"'
  dqoute2 = "\"\""
  comma = ','
end


toarrays(node::Node, cvalues, ::MatchRule{:default}) = cvalues
toarrays(node::Node, cvalues, ::MatchRule{:start}) = cvalues
toarrays(node::Node, cvalues, ::MatchRule{:crlf}) = nothing
toarrays(node::Node, cvalues, ::MatchRule{:comma}) = nothing
toarrays(node::Node, cvalues, ::MatchRule{:lf}) = nothing
toarrays(node::Node, cvalues, ::MatchRule{:cr}) = nothing
toarrays(node::Node, cvalues, ::MatchRule{:dquote}) = nothing
toarrays(node::Node, cvalues, ::MatchRule{:escaped_field}) = node.children[2].value
toarrays(node::Node, cvalues, ::MatchRule{:unescaped_field}) = node.children[1].value
toarrays(node::Node, cvalues, ::MatchRule{:field}) = cvalues
toarrays(node::Node, cvalues, ::MatchRule{:record}) = flatten(cvalues)
toarrays(node::Node, cvalues, ::MatchRule{:data}) = flatten(cvalues)
toarrays(node::Node, cvalues, ::MatchRule{:textdata}) = node.value

# data = open(readall, "/home/abraham/.julia/v0.3/DataFrames/test/data/factors/mixedvartypes.csv")
testdir = "/home/abraham/.julia/v0.3/DataFrames/test"

# filename = "$testdir/data/padding/space_after_delimiter.csv"
#filename = "$testdir/data/scaling/10000rows.csv"
filename = "test.csv"
#println("reading data")
#data = open(readall, filename)
data = """
1,2,3
4,5,6
this,is,a,"test"
"""

# println("parsing data")
(ast, pos, error) = parse(csv, data)

println(ast)

result = transform(toarrays, ast)
println(result)

# println(ast)
#println("running JIT...")
#parse(csv, data)
#println("doing speed test")
#@time parse(csv, data)
# Profile.print()
# println(ast)

# using ProfileView
# ProfileView.view()


# println("transforming data")
# result = apply(toarrays, ast)
# println(result)

#   "$testdir/data/newlines/os9.csv",
#   "$testdir/data/newlines/osx.csv",
#   "$testdir/data/newlines/windows.csv",
#   "$testdir/data/newlines/embedded_os9.csv",
#   "$testdir/data/newlines/embedded_osx.csv",
#   "$testdir/data/newlines/embedded_windows.csv",


# filenames = ["$testdir/data/blanklines/blanklines.csv",
#   "$testdir/data/padding/space_after_delimiter.csv",
#   "$testdir/data/padding/space_around_delimiter.csv",
#   "$testdir/data/padding/space_before_delimiter.csv",
#   "$testdir/data/quoting/empty.csv",
#   "$testdir/data/quoting/escaping.csv",
#   "$testdir/data/quoting/quotedcommas.csv",
#   "$testdir/data/scaling/10000rows.csv",
#   "$testdir/data/scaling/movies.csv",
#   "$testdir/data/separators/sample_data.csv",
#   "$testdir/data/separators/sample_data.tsv",
#   "$testdir/data/separators/sample_data.wsv",
#   "$testdir/data/typeinference/bool.csv",
#   "$testdir/data/typeinference/standardtypes.csv",
#   "$testdir/data/utf8/corrupt_utf8.csv",
#   "$testdir/data/utf8/short_corrupt_utf8.csv",
#   "$testdir/data/utf8/utf8.csv"]

# for filename in filenames
#   println("$filename")

#   data = open(readall, filename)
#   (ast, pos, error) = parse(csv, data)
#   result = apply(toarrays, ast)

#   # load DataFrames representation
#   df = readtable(filename);
#   truth = collect(zip(df.columns...))

#   println("result: $result")
#   println("truth: $truth")
# end
