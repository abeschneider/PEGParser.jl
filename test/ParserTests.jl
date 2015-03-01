using RunTests
using Base.Test

using PEGParser
import PEGParser: Node, StandardCache

@testmodule ParserTests begin
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
    #@test ast.ruleType ===
  end

  # function test_string1_cache()
  #   @grammar grammar begin
  #     start = "a"
  #   end
  #
  #   (ast, pos, error) = parse(grammar, "a", StandardCache())
  #   @test error === nothing
  #   @test length(ast.children) == 0
  #   @test ast.value == "a"
  #   @test ast.sym === :start
  #   @test pos == 2
  # end

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

  # function test_or1_cache()
  #   @grammar grammar begin
  #     start = "a" | "b" | "c"
  #   end
  #
  #   (ast, pos, error) = parse(grammar, "a")
  #   @test ast.value == "a"
  #   @test pos == 2
  #
  #   (ast, pos, error) = parse(grammar, "b")
  #   @test ast.value == "b"
  #   @test pos == 2
  #
  #   (ast, pos, error) = parse(grammar, "c")
  #   @test ast.value == "c"
  #   @test pos == 2
  #
  #   (ast, pos, error) = parse(grammar, "d")
  #   @test error !== nothing
  #   @test pos == 1
  # end

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

  # function test_reference1_cache()
  #   @grammar grammar begin
  #     start = a
  #     a = "a"
  #   end
  #
  #   (ast, pos, error) = parse(grammar, "a")
  #   @test ast.value == "a"
  #
  #   (ast, pos, error) = parse(grammar, "b")
  #   @test error !== nothing
  # end

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

  # function test_or2_cache()
  #   @grammar grammar begin
  #     start = a | b
  #     a = "a"
  #     b = "b"
  #   end
  #
  #   (ast, pos, error) = parse(grammar, "a")
  #   @test ast.value == "a"
  #   @test pos == 2
  #
  #   (ast, pos, error) = parse(grammar, "b")
  #   @test ast.value == "b"
  #   @test pos == 2
  #
  #   (ast, pos, error) = parse(grammar, "c")
  #   @test error !== nothing
  # end

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

  # function test_and1_cache()
  #   @grammar grammar begin
  #     start = a + b
  #     a = "a"
  #     b = "b"
  #   end
  #
  #   (ast, pos, error) = parse(grammar, "ab")
  #   @test ast.value == "ab"
  #   @test length(ast.children) == 2
  #   @test ast.children[1].value == "a"
  #   @test ast.children[2].value == "b"
  # end

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

  # function test_andor_cache()
  #   @grammar grammar begin
  #     start = a | b
  #     a = "a" + "b"
  #     b = "a" + "c"
  #   end
  #
  #   (ast, pos, error) = parse(grammar, "ab")
  #   @test ast.value == "ab"
  #
  #   (ast, pos, error) = parse(grammar, "ac")
  #   @test ast.value == "ac"
  # end

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

  # function test_oneormore_cache()
  #   @grammar grammar begin
  #     start = +("a")
  #   end
  #
  #   (ast, pos, error) = parse(grammar, "")
  #   @test error !== nothing
  #
  #   (ast, pos, error) = parse(grammar, "a")
  #   @test ast.value == "a"
  #
  #   (ast, pos, error) = parse(grammar, "aa")
  #   @test ast.value == "aa"
  #
  #   (ast, pos, error) = parse(grammar, "aaa")
  #   @test ast.value == "aaa"
  # end

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

  # function test_zeroormore_cache()
  #   @grammar grammar begin
  #     start = *("a")
  #   end
  #
  #   (ast, pos, error) = parse(grammar, "b")
  #   @test ast === nothing
  #
  #   (ast, pos, error) = parse(grammar, "a")
  #   @test ast.value == "a"
  #
  #   (ast, pos, error) = parse(grammar, "aa")
  #   @test ast.value == "aa"
  #
  #   (ast, pos, error) = parse(grammar, "aaa")
  #   @test ast.value == "aaa"
  # end

  function test_optional_ncache()
    @grammar grammar begin
      start = "a" + ?("b")
    end

    (ast, pos, error) = parse(grammar, "a")
    @test ast.value == "a"

    (ast, pos, error) = parse(grammar, "ab")
    @test ast.value == "ab"
  end

  # function test_optional_cache()
  #   @grammar grammar begin
  #     start = "a" + ?("b")
  #   end
  #
  #   (ast, pos, error) = parse(grammar, "a")
  #   @test ast.value == "a"
  #
  #   (ast, pos, error) = parse(grammar, "ab")
  #   @test ast.value == "ab"
  # end

  function test_regex_ncache()
    @grammar grammar begin
      start = r"[0-9]+"
    end

    (ast, pos, error) = parse(grammar, "0")
    @test ast.value == "0"

    (ast, pos, error) = parse(grammar, "42")
    @test ast.value == "42"
  end

  # function test_regex_cache()
  #   @grammar grammar begin
  #     start = r"[0-9]+"
  #   end
  #
  #   (ast, pos, error) = parse(grammar, "0")
  #   @test ast.value == "0"
  #
  #   (ast, pos, error) = parse(grammar, "42")
  #   @test ast.value == "42"
  # end

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

  # function test_ambigious_cache()
  #   @grammar grammar begin
  #     # ambigious on "c"
  #     start = "a" + ((Y + "e") | (?("b") + Y + "f"))
  #     Y = "c" + "d"
  #   end
  #
  #   # first branch
  #   (ast, pos, error) = parse(grammar, "acde")
  #   @test ast.value == "acde"
  #
  #   # second branch; skip optional "b"
  #   (ast, pos, error) = parse(grammar, "acdf")
  #   @test ast.value == "acdf"
  #
  #   # second branch, use optional "b"
  #   (ast, pos, error) = parse(grammar, "abcdf")
  #   @test ast.value == "abcdf"
  #
  #   # TODO: need method to test cache was accessed
  # end

  function test_list_uncached()
    @grammar grammar begin
      start = list(number, ",")
      number = r"[0-9]"
    end

    (ast, pos, error) = parse(grammar, "1,2,3")
    @test error === nothing
    @test ast.value == "1,2,3"

    (ast, pos, error) = parse(grammar, "")
    @test error !== nothing
    # @test ast.value == "1,2,3"
  end

  function test_list0_uncached()
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
end
