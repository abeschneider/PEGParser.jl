using Base.Test

using PEGParser
import PEGParser: Node, StandardCache
using Compat

function test_string1_ncache()
  @grammar grammar begin
    start = "a"
  end

  (ast, pos, error) = parse(grammar, "a")
  @test error === nothing
  @test length(ast.children) == 0
  @test ast.value == "a"
  @test ast.sym === :start
  @test pos == 2
end

function test_string1_cache()
  @grammar grammar begin
    start = "a"
  end

  (ast, pos, error) = parse(grammar, "a", cache=StandardCache())
  @test error === nothing
  @test length(ast.children) == 0
  @test ast.value == "a"
  @test ast.sym === :start
  @test pos == 2
end

function test_or1_ncache()
  @grammar grammar begin
    start = "a" | "b" | "c"
  end

  (ast, pos, error) = parse(grammar, "a")
  @test ast.value == "a"
  @test pos == 2

  (ast, pos, error) = parse(grammar, "b")
  @test ast.value == "b"
  @test pos == 2

  (ast, pos, error) = parse(grammar, "c")
  @test ast.value == "c"
  @test pos == 2

  (ast, pos, error) = parse(grammar, "d")
  @test error !== nothing
  @test pos == 1
end

function test_or1_cache()
  @grammar grammar begin
    start = "a" | "b" | "c"
  end

  (ast, pos, error) = parse(grammar, "a", cache=StandardCache())
  @test ast.value == "a"
  @test pos == 2

  (ast, pos, error) = parse(grammar, "b", cache=StandardCache())
  @test ast.value == "b"
  @test pos == 2

  (ast, pos, error) = parse(grammar, "c", cache=StandardCache())
  @test ast.value == "c"
  @test pos == 2

  (ast, pos, error) = parse(grammar, "d", cache=StandardCache())
  @test error !== nothing
  @test pos == 1
end

function test_reference1_ncache()
  @grammar grammar begin
    start = a
    a = "a"
  end

  (ast, pos, error) = parse(grammar, "a")
  @test ast.value == "a"

  (ast, pos, error) = parse(grammar, "b")
  @test error !== nothing
end

function test_reference1_cache()
  @grammar grammar begin
    start = a
    a = "a"
  end

  (ast, pos, error) = parse(grammar, "a", cache=StandardCache())
  @test ast.value == "a"

  (ast, pos, error) = parse(grammar, "b", cache=StandardCache())
  @test error !== nothing
end

function test_or2_ncache()
  @grammar grammar begin
    start = a | b
    a = "a"
    b = "b"
  end

  (ast, pos, error) = parse(grammar, "a")
  @test ast.value == "a"
  @test pos == 2

  (ast, pos, error) = parse(grammar, "b")
  @test ast.value == "b"
  @test pos == 2

  (ast, pos, error) = parse(grammar, "c")
  @test error !== nothing
end

function test_or2_cache()
  @grammar grammar begin
    start = a | b
    a = "a"
    b = "b"
  end

  (ast, pos, error) = parse(grammar, "a", cache=StandardCache())
  @test ast.value == "a"
  @test pos == 2

  (ast, pos, error) = parse(grammar, "b", cache=StandardCache())
  @test ast.value == "b"
  @test pos == 2

  (ast, pos, error) = parse(grammar, "c", cache=StandardCache())
  @test error !== nothing
end

function test_and1_ncache()
  @grammar grammar begin
    start = a + b
    a = "a"
    b = "b"
  end

  (ast, pos, error) = parse(grammar, "ab")
  @test ast.value == "ab"
  @test length(ast.children) == 2
  @test ast.children[1].value == "a"
  @test ast.children[2].value == "b"
end

function test_and1_cache()
  @grammar grammar begin
    start = a + b
    a = "a"
    b = "b"
  end

  (ast, pos, error) = parse(grammar, "ab", cache=StandardCache())
  @test ast.value == "ab"
  @test length(ast.children) == 2
  @test ast.children[1].value == "a"
  @test ast.children[2].value == "b"
end

function test_andor_ncache()
  @grammar grammar begin
    start = a | b
    a = "a" + "b"
    b = "a" + "c"
  end

  (ast, pos, error) = parse(grammar, "ab")
  @test ast.value == "ab"

  (ast, pos, error) = parse(grammar, "ac")
  @test ast.value == "ac"
end

function test_andor_cache()
  @grammar grammar begin
    start = a | b
    a = "a" + "b"
    b = "a" + "c"
  end

  (ast, pos, error) = parse(grammar, "ab", cache=StandardCache())
  @test ast.value == "ab"

  (ast, pos, error) = parse(grammar, "ac", cache=StandardCache())
  @test ast.value == "ac"
end

function test_oneormore_ncache()
  @grammar grammar begin
    start = +("a")
  end

  (ast, pos, error) = parse(grammar, "")
  @test error !== nothing

  (ast, pos, error) = parse(grammar, "a")
  @test ast.value == "a"

  (ast, pos, error) = parse(grammar, "aa")
  @test ast.value == "aa"

  (ast, pos, error) = parse(grammar, "aaa")
  @test ast.value == "aaa"
end

function test_oneormore_cache()
  @grammar grammar begin
    start = +("a")
  end

  (ast, pos, error) = parse(grammar, "", cache=StandardCache())
  @test error !== nothing

  (ast, pos, error) = parse(grammar, "a", cache=StandardCache())
  @test ast.value == "a"

  (ast, pos, error) = parse(grammar, "aa", cache=StandardCache())
  @test ast.value == "aa"

  (ast, pos, error) = parse(grammar, "aaa", cache=StandardCache())
  @test ast.value == "aaa"
end

function test_zeroormore_ncache()
  @grammar grammar begin
    start = *("a")
  end

  (ast, pos, error) = parse(grammar, "b")
  @test ast === nothing

  (ast, pos, error) = parse(grammar, "a")
  @test ast.value == "a"

  (ast, pos, error) = parse(grammar, "aa")
  @test ast.value == "aa"

  (ast, pos, error) = parse(grammar, "aaa")
  @test ast.value == "aaa"
end

function test_zeroormore_cache()
  @grammar grammar begin
    start = *("a")
  end

  (ast, pos, error) = parse(grammar, "b", cache=StandardCache())
  @test ast === nothing

  (ast, pos, error) = parse(grammar, "a", cache=StandardCache())
  @test ast.value == "a"

  (ast, pos, error) = parse(grammar, "aa", cache=StandardCache())
  @test ast.value == "aa"

  (ast, pos, error) = parse(grammar, "aaa", cache=StandardCache())
  @test ast.value == "aaa"
end

function test_optional_ncache()
  @grammar grammar begin
    start = "a" + ?("b")
  end

  (ast, pos, error) = parse(grammar, "a")
  @test ast.value == "a"

  (ast, pos, error) = parse(grammar, "ab")
  @test ast.value == "ab"
end

function test_optional_cache()
  @grammar grammar begin
    start = "a" + ?("b")
  end

  (ast, pos, error) = parse(grammar, "a", cache=StandardCache())
  @test ast.value == "a"

  (ast, pos, error) = parse(grammar, "ab", cache=StandardCache())
  @test ast.value == "ab"
end

function test_regex_ncache()
  @grammar grammar begin
    start = r"[0-9]+"
  end

  (ast, pos, error) = parse(grammar, "0")
  @test ast.value == "0"

  (ast, pos, error) = parse(grammar, "42")
  @test ast.value == "42"
end

function test_regex_cache()
  @grammar grammar begin
    start = r"[0-9]+"
  end

  (ast, pos, error) = parse(grammar, "0", cache=StandardCache())
  @test ast.value == "0"

  (ast, pos, error) = parse(grammar, "42", cache=StandardCache())
  @test ast.value == "42"
end

function test_ambigious_ncache()
  @grammar grammar begin
    # ambigious on "c"
    start = "a" + ((Y + "e") | (?("b") + Y + "f"))
    Y = "c" + "d"
  end

  # first branch
  (ast, pos, error) = parse(grammar, "acde")
  @test ast.value == "acde"


  # second branch; skip optional "b"
  (ast, pos, error) = parse(grammar, "acdf")
  @test ast.value == "acdf"

  # second branch, use optional "b"
  (ast, pos, error) = parse(grammar, "abcdf")
  @test ast.value == "abcdf"
end

function test_ambigious_cache()
  @grammar grammar begin
    # ambigious on "c"
    start = "a" + ((Y + "e") | (?("b") + Y + "f"))
    Y = "c" + "d"
  end

  # first branch
  (ast, pos, error) = parse(grammar, "acde", cache=StandardCache())
  @test ast.value == "acde"

  # second branch; skip optional "b"
  (ast, pos, error) = parse(grammar, "acdf", cache=StandardCache())
  @test ast.value == "acdf"

  # We should traverse the first branch, bail because 'f' doesn't match
  # and then go up the second branch. At that point cache should be used.
  # Once a method to trace calls is created, can test this.
  # second branch, use optional "b"

  (ast, pos, error) = parse(grammar, "abcdf", cache=StandardCache())
  @test ast.value == "abcdf"
end

function test_list_ncache()
  @grammar grammar begin
    start = list(number, ",")
    number = r"[0-9]"
  end

  (ast, pos, error) = parse(grammar, "1,2,3")
  @test error === nothing
  @test ast.value == "1,2,3"

  (ast, pos, error) = parse(grammar, "")
  @test error !== nothing
end

function test_list0_ncache()
  @grammar grammar begin
    start = list(number, ",", 0)
    number = r"[0-9]"
  end

  (ast, pos, error) = parse(grammar, "1,2,3")
  @test error === nothing
  @test ast.value == "1,2,3"

  (ast, pos, error) = parse(grammar, "")
  @test error === nothing
  @test length(ast.children) == 0
end

function test_integer_parser()
  @grammar grammar begin
    start = integer
  end

  (ast, pos, error) = parse(grammar, "5")
  @test error === nothing
  @test ast.ruleType === IntegerRule
  @test ast.value == "5"
end

function test_float_parser()
  @grammar grammar begin
    start = float
  end

  (ast, pos, error) = parse(grammar, "5.123")
  @test error === nothing
  @test ast.ruleType === FloatRule
  @test ast.value == "5.123"
end

function test_semantic_action()
  @grammar grammar begin
    start = list(number, COMMA)
    number = (-SPACE + float){ parse(Float64, _1.value) } |
             (-SPACE + integer){ parse(Int64, _1.value) }
    COMMA = SPACE + ","
    SPACE = r"[ \t\n]*"
  end

  (ast, pos, error) = parse(grammar, "1,2.0,3,4.5")
  @test error === nothing
  @test length(ast.children) == 4
  @test ast.children[1] == 1
  @test ast.children[2] == 2.0
  @test ast.children[3] == 3
  @test ast.children[4] == 4.5
end

test_string1_ncache()
test_string1_cache()
test_or1_ncache()
test_or1_cache()
test_reference1_ncache()
test_reference1_cache()
test_or2_ncache()
test_or2_cache()
test_and1_ncache()
test_and1_cache()
test_andor_ncache()
test_andor_cache()
test_oneormore_ncache()
test_oneormore_cache()
test_zeroormore_ncache()
test_zeroormore_cache()
test_optional_ncache()
test_optional_cache()
test_regex_ncache()
test_regex_cache()
test_ambigious_ncache()
test_ambigious_cache()
test_list_ncache()
test_list0_ncache()

test_integer_parser()
test_float_parser()
test_semantic_action()
