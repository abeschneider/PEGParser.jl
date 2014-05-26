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

  (node, pos, error) = parse(grammar, ReferencedRule(:rule), "a", 1, Dict())

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

  (node, pos, error) = parse(grammar, ReferencedRule(:rule), "b", 1, Dict())

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

  (node, pos, error) = parse(grammar, ReferencedRule(:rule), "a", 1, Dict())

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

  (node, pos, error) = parse(grammar, ReferencedRule(:rule), "b", 1, Dict())

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

  (node, pos, error) = parse(grammar, ReferencedRule(:rule), "cde", 1, Dict())

  if node.value != "cde" || error != nothing || pos != 4
    return false
  end

  true
end

@test begin
  @grammar grammar begin
    rule = 'a' | 'b' | "cde"
  end

  (node, pos, error) = parse(grammar, ReferencedRule(:rule), "foo", 1, Dict())

  if node != nothing || !isa(error, ParseError) || pos != 1
    return false
  end

  true
end

@test begin
  @grammar grammar begin
    rule = 'a' + 'b' + "cde"
  end

  (node, pos, error) = parse(grammar, ReferencedRule(:rule), "abcde", 1, Dict())

  if node.value != "abcde" || error != nothing || pos != 6
    return false
  end

  true
end

@test begin
  @grammar grammar begin
    rule = ('a' + 'b') | ('c' + 'd')
  end

  (node, pos, error) = parse(grammar, ReferencedRule(:rule), "ab", 1, Dict())

  if node.value != "ab" || error != nothing || pos != 3
    return false
  end

  (node, pos, error) = parse(grammar, ReferencedRule(:rule), "cd", 1, Dict())
  if node.value != "cd" || error != nothing || pos != 3
    return false
  end

  (value, pos, error) = parse(grammar, ReferencedRule(:rule), "ac", 1, Dict())
  if value != nothing || !isa(error, ParseError) || pos != 1
    return false
  end

  true
end

@test begin
  @grammar grammar begin
    rule = +('a' + 'b')
  end

  (node, pos, error) = parse(grammar, ReferencedRule(:rule), "ababab", 1, Dict())

  if node.value != "ababab" || error != nothing || pos != 7
    return false
  end

  (node, pos, error) = parse(grammar, ReferencedRule(:rule), "ab", 1, Dict())

  if node.value != "ab" || error != nothing || pos != 3
    return false
  end

  # this is still okay, since we're allowed to not match the last 'a'
  (node, pos, error) = parse(grammar, ReferencedRule(:rule), "aba", 1, Dict())
  if node.value != "ab" || error != nothing || pos != 3
    return false
  end

  # we have to match at least one "ab"
  (node, pos, error) = parse(grammar, ReferencedRule(:rule), "", 1, Dict())
  if node != nothing || !isa(error, ParseError) || pos != 1
    return false
  end

  true
end


@test begin
  # NB: need to guard against ':>' binding with '*'
  @grammar grammar begin
    rule = *('a' + 'b')
  end

  (node, pos, error) = parse(grammar, ReferencedRule(:rule), "ababab", 1, Dict())

  if node.value != "ababab" || error != nothing || pos != 7
    return false
  end

  # this is okay, we can match nothing as well
  (node, pos, error) = parse(grammar, ReferencedRule(:rule), "", 1, Dict())
  if node.value != "" || error != nothing || pos != 1
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
  (node, pos, error) = parse(grammar, ReferencedRule(:bold_text), "((foobar))", 1, Dict())

  # transform tree into HTML
  html = Dict()
  html["bold_open"] = (node, children) -> "<b>"
  html["bold_close"]  = (node, children) -> "</b>"
  html["text"] = (node, children) -> node.value
  html["bold_text"] = (node, children) -> join(children)

  result = transform(html, node)

  return result !== "<b>foobar</b>"
end

@test begin
  @grammar grammar begin
    start = expr
    number = r"([0-9]+)"
    expr = (term + op1 + expr) | term
    term = (factor + op2 + term) | factor
    factor = number | pfactor
    pfactor = ('(' + expr + ')')
    op1 = '+' | '-'
    op2 = '*' | '/'
  end

  (node, pos, error) = parse(grammar, "5*(42+3+6+10+2)")

  math = Dict()
  math["number"] = (node, children) -> float(node.value)
  math["expr"] = (node, children) ->
    length(children) == 1 ? children : eval(Expr(:call, children[2], children[1], children[3]))
  math["factor"] = (node, children) -> children
  math["pfactor"] = (node, children) -> children[2]
  math["term"] = (node, children) ->
    length(children) == 1 ? children : eval(Expr(:call, children[2], children[1], children[3]))
  math["op1"] = (node, children) -> symbol(node.value)
  math["op2"] = (node, children) -> symbol(node.value)

  result = transform(math, node)

  return result == 315.0
end
