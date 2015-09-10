using Base.Test

using PEGParser
using PEGParser: AndRule, IntegerRule, FloatRule
import Base.float
using Compat

function test_default_or_action()
  @grammar grammar begin
    start = "a" | "b"
  end

  (ast, pos, error) = parse(grammar, "a")

  # default_or_action returns the one child from the or-rule
  @test length(ast.children) == 0
  @test ast.value == "a"
end

function test_custom_action1()
	@grammar grammar begin
		# transform to just the integer value
		start = ("value:" + integer){ parse(Int, _2.value) }
	end

	(ast, pos, error) = parse(grammar, "value:5")

	# AST was convert to a single integer
	@test ast == 5
end

function test_custom_action2()
	@grammar grammar begin
		start = (integer + "::integer"){ parse(Int, _1.value) } |
				(float + "::float"){ parse(Float64, _1.value) }
	end

	(ast, pos, error) = parse(grammar, "5::integer")
	@test typeof(ast) == Int
	@test ast == 5

	(ast, pos, error) = parse(grammar, "5.0::float")
	@test typeof(ast) == Float64
	@test ast == 5.0
end

function test_custom_action3()
	@grammar grammar begin
		start = ((integer + "::integer") | (float + "::float")){ _1 }
	end

	(ast, pos, error) = parse(grammar, "5::integer")

	# should have the first and-rule
	@test ast.ruleType == AndRule
	@test length(ast.children) == 2
	@test ast.children[1].ruleType == IntegerRule
	@test ast.children[1].value == "5"

	(ast, pos, error) = parse(grammar, "5.0::float")
	@test ast.ruleType == AndRule
	@test length(ast.children) == 2
	@test ast.children[1].ruleType == FloatRule
	@test ast.children[1].value == "5.0"
end

function test_custom_action4()
	@grammar grammar begin
		start = ((r"[a-zA-Z][a-zA-Z0-9_]*" + "::integer"){ symbol(_1.value) } +
			"=" + integer{ parse(Int, _0) }){ (_1, _3) }
	end

	(ast, pos, error) = parse(grammar, "foo2::integer=5")
	@test length(ast) == 2
	@test ast[1] == :foo2
	@test ast[2] == 5
end

test_default_or_action()
test_custom_action1()
test_custom_action2()
test_custom_action3()
test_custom_action4()
