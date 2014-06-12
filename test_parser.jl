using Base.Test

using EBNF
using PEGParser

#
# Test parsing without caching
#

@test begin
  @grammar grammar begin
    rule = 'a'
  end

  (node, pos, error) = parse(grammar, ReferencedRule(:rule), "a", 1, Dict{Int64, Node}())

  # we should get the literal back, no error should occur, and our
  # position should move forward
  if node.value != "a" || error != nothing || pos != 2
    return false
  end

  true
end

@test begin
  @grammar grammar begin
    rule = 'a'
  end

  (node, pos, error) = parse(grammar, ReferencedRule(:rule), "b", 1, Dict{Int64, Node}())

  # we should get nothing back for a value, but get a ParseError,
  # and the position should not move forward
  if node != nothing || !isa(error, ParseError) || pos != 1
    return false
  end

  true
end

@test begin
  @grammar grammar begin
    rule = 'a' | 'b' | "cde"
  end

  (node, pos, error) = parse(grammar, ReferencedRule(:rule), "a", 1, Dict{Int64, Node}())

  # we should get the first branch
  if node.value != "a" || error != nothing || pos != 2
    return false
  end

  true
end

@test begin
  @grammar grammar begin
    rule = 'a' | 'b' | "cde"
  end

  (node, pos, error) = parse(grammar, ReferencedRule(:rule), "b", 1, Dict{Int64, Node}())

  # we should get the second branch
  if node.value != "b" || error != nothing || pos != 2
    return false
  end

  true
end

@test begin
  @grammar grammar begin
    rule = 'a' | 'b' | "cde"
  end

  (node, pos, error) = parse(grammar, ReferencedRule(:rule), "cde", 1, Dict{Int64, Node}())

  if node.value != "cde" || error != nothing || pos != 4
    return false
  end

  true
end

@test begin
  @grammar grammar begin
    rule = 'a' | 'b' | "cde"
  end

  (node, pos, error) = parse(grammar, ReferencedRule(:rule), "foo", 1, Dict{Int64, Node}())

  if node != nothing || !isa(error, ParseError) || pos != 1
    return false
  end

  true
end

@test begin
  @grammar grammar begin
    rule = 'a' + 'b' + "cde"
  end

  (node, pos, error) = parse(grammar, ReferencedRule(:rule), "abcde", 1, Dict{Int64, Node}())

  if node.value != "abcde" || error != nothing || pos != 6
    return false
  end

  true
end

@test begin
  @grammar grammar begin
    rule = ('a' + 'b') | ('c' + 'd')
  end

  (node, pos, error) = parse(grammar, ReferencedRule(:rule), "ab", 1, Dict{Int64, Node}())

  if node.value != "ab" || error != nothing || pos != 3
    return false
  end

  (node, pos, error) = parse(grammar, ReferencedRule(:rule), "cd", 1, Dict{Int64, Node}())
  if node.value != "cd" || error != nothing || pos != 3
    return false
  end

  # TODO: should it be an error to not match the entire string? usually this is the difference
  # between parse and match (at least for pyparsing)
  (value, pos, error) = parse(grammar, ReferencedRule(:rule), "ac", 1, Dict{Int64, Node}())
#   if value != nothing || !isa(error, ParseError) || pos != 1
#     return false
#   end

  true
end

@test begin
  @grammar grammar begin
    rule = +('a' + 'b')
  end

  (node, pos, error) = parse(grammar, ReferencedRule(:rule), "ababab", 1, Dict{Int64, Node}())

  if node.value != "ababab" || error != nothing || pos != 7
    return false
  end

  (node, pos, error) = parse(grammar, ReferencedRule(:rule), "ab", 1, Dict{Int64, Node}())

  if node.value != "ab" || error != nothing || pos != 3
    return false
  end

  # this is still okay, since we're allowed to not match the last 'a'
  (node, pos, error) = parse(grammar, ReferencedRule(:rule), "aba", 1, Dict{Int64, Node}())
  if node.value != "ab" || error != nothing || pos != 3
    return false
  end

  # we have to match at least one "ab"
  (node, pos, error) = parse(grammar, ReferencedRule(:rule), "", 1, Dict{Int64, Node}())
  if node != nothing || !isa(error, ParseError) || pos != 1
    return false
  end

  true
end


@test begin
  @grammar grammar begin
    rule = *('a' + 'b')
  end

  (node, pos, error) = parse(grammar, ReferencedRule(:rule), "ababab", 1, Dict{Int64, Node}())

  if node.value != "ababab" || error != nothing || pos != 7
    return false
  end

  # this is okay, we can match nothing as well
  (node, pos, error) = parse(grammar, ReferencedRule(:rule), "", 1, Dict{Int64, Node}())
  if node !== nothing || error != nothing || pos != 1
    return false
  end

  true
end

# test stolen from parsimonious
@test begin
  @grammar grammar begin
    bold_text = bold_open + text + bold_close
    text = r"[a-zA-z]+"
    bold_open = "(("
    bold_close = "))"
  end

  # generate parse tree
  (ast, pos, error) = parse(grammar, ReferencedRule(:bold_text), "((foobar))", 1, Dict{Int64, Node}())

  # transform tree into HTML
  tohtml(node, cvalues, ::MatchRule{:default}) = cvalues
  tohtml(node, cvalues, ::MatchRule{:bold_text}) = join(cvalues)
  tohtml(node, cvalues, ::MatchRule{:bold_open}) = "<b>"
  tohtml(node, cvalues, ::MatchRule{:bold_close}) = "</b>"
  tohtml(node, cvalues, ::MatchRule{:text}) = node.value

  result = transform(tohtml, ast)
  return result !== "<b>foobar</b>"
end

@test begin
  @grammar grammar begin
    start = expr
    number = r"[0-9]+"
    expr = (term + op1 + expr) | term
    term = (factor + op2 + term) | factor
    factor = number | pfactor
    pfactor = lparen + expr + rparen
    op1 = ('+' | '-')
    op2 = ('*' | '/')
    lparen = "("
    rparen = ")"
    space = r"[ \t\n]*"
  end

  tovalue(node, cvalues, ::MatchRule{:default}) = cvalues
  tovalue(node, cvalues, ::MatchRule{:lparen}) = nothing
  tovalue(node, cvalues, ::MatchRule{:rparen}) = nothing
  tovalue(node, cvalues, ::MatchRule{:space}) = nothing

  tovalue(node, cvalues, ::MatchRule{:start}) = cvalues
  tovalue(node, cvalues, ::MatchRule{:number}) = float(node.value)

  tovalue(node, cvalues, ::MatchRule{:factor}) = cvalues
  tovalue(node, cvalues, ::MatchRule{:pfactor}) = cvalues

  tovalue(node, cvalues, ::MatchRule{:op1}) = symbol(node.value)
  tovalue(node, cvalues, ::MatchRule{:op2}) = symbol(node.value)

  function tovalue(node, cvalues, ::MatchRule{:expr})
    length(cvalues) == 1 ? cvalues : eval(Expr(:call, cvalues[2], cvalues[1], cvalues[3]))
  end

  function tovalue(node, cvalues, ::MatchRule{:term})
    length(cvalues) == 1 ? cvalues : eval(Expr(:call, cvalues[2], cvalues[1], cvalues[3]))
  end

  (ast, pos, error) = parse(grammar, "5*(42+164)")

  result = transform(tovalue, ast)
  return result == 1030.0
end
