using RunTests
using Base.Test

push!(LOAD_PATH, "../src")
using EBNF
using PEGParser

@testmodule ParserTests begin
  function test_simple1()
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

  function test_or1()
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

  function test_or2()
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

  function test_and1()
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

  function test_andor()
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

  function test_oneormore()
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

  function test_zeroormore()
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
end
