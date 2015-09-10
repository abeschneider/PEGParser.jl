using PEGParser
using Compat

immutable RangeType
  first
  last
  step
end

@grammar lang begin
  start = list(stmt, NEWLINE)
  stmt = if_stmt | for_stmt | decl_stmt |
    func_stmt | func_call_stmt | return_stmt | block
  if_stmt = -IF + condition + stmt + *(else_stmt)
  else_stmt = ELSE + stmt
  block = (LBRACE + block_list + RBRACE){ _2 }
  block_list = list(stmt, NEWLINE) #{ children }
  atom = string | range | number | name
  value = expr | atom

  condition = value + comparison + value
  comparison = EQ | NE | LTE | GTE | LT | GT

  string = (-SPACE + r"\"[^\"]*\""){ _1.value }

  number = float_number | integer_number
  integer_number = (-SPACE + integer){ parse(Int, _1.value) }
  float_number = (-SPACE + float){ parse(Float64, _1.value) }

  bool = TRUE | FALSE
  range = (number + COLON + number){ RangeType(_1, _3, 1) }
  name = (-SPACE + r"[a-zA-Z_][0-9a-zA-Z_]*"){ symbol(_1.value) }

  expr_op = term + op1 + expr
  expr = expr_op | term
  term_op = factor + op2 + term

  term = term_op | factor
  factor = atom | pfactor
  pfactor = (LPAREN + expr + RPAREN){ _2 }
  op1 = (ADD | SUB){ symbol(_1.value) }
  op2 = (MULT | DIV){ symbol(_1.value) }

  for_stmt = -FOR + name + -IN + value + stmt

  decl_stmt = var_stmt | const_stmt

  var_type = name
  var_name_type = name + -":" + var_type
  var_stmt = -VAR + (var_name_type | name) + -EQUALS + value
  const_stmt = -CONST + (var_name_type | name) + -EQUALS + value

  func_stmt = -FUNCTION + name + -LPAREN + param_list + -RPAREN + ?(-RARROW + var_type) + block
  param_list = list(var_name_type, COMMA, 0)

  func_call_stmt = name + -LPAREN + param_call_list + -RPAREN
  param_call_list = list(value, COMMA, 0)

  return_stmt = -RETURN + value


  ADD = (-SPACE + "+"){ _1 }
  SUB = (-SPACE + "-"){ _1 }
  MULT = (-SPACE + "*"){ _1 }
  DIV = (-SPACE + "/"){ _1 }
  FUNCTION = SPACE + "function"
  IF = SPACE + "if"
  FOR = SPACE + "for"
  IN = SPACE + "in"
  VAR = SPACE + "var"
  CONST = SPACE + "const"
  TRUE = SPACE + "true"
  FALSE = SPACE + "false"
  RETURN = SPACE + "return"
  EQUALS = SPACE + "="
  EQ = SPACE + "=="
  NEQ = SPACE + "!="
  LT = SPACE + "<"
  GT = SPACE + ">"
  LTE = SPACE + "<="
  GTE = SPACE + ">="
  ELSE = SPACE + "else"
  LBRACE = SPACE + "{"
  RBRACE = SPACE + "}"
  LPAREN = SPACE + "("
  RPAREN = SPACE + ")"
  RARROW = SPACE + "->"
  SPACE = r"[ \n\r\t]*"
  NEWLINE = r"[\n\r]+" | SEMICOLON
  COLON = SPACE + ":"
  SEMICOLON = SPACE + ";"
  COMMA = SPACE + ","
end

toexpr(node, children, ::MatchRule{:default}) = node

toexpr(node, children, ::MatchRule{:start}) = Expr(:block, children...)

toexpr(node, children, ::MatchRule{:term_op}) =
  Expr(:call, children[2], children[1], children[3])

toexpr(node, children, ::MatchRule{:expr_op}) =
  Expr(:call, children[2], children[1], children[3])

toexpr(node, children, ::MatchRule{:var_stmt}) =
  Expr(:(=), children[1], children[2])

toexpr(node, children, ::MatchRule{:const_stmt}) =
  Expr(:const, Expr(:(=), children[1], children[2]))

toexpr(node, children, ::MatchRule{:func_call_stmt}) =
  Expr(:call, children[1], children[2]...)

toexpr(node, children, ::MatchRule{:block_list}) =
  Expr(:block, children...)

toexpr(node, children, ::MatchRule{:param_call_list}) = children

toexpr(node, children, ::MatchRule{:for_stmt}) =
  Expr(:for,
    Expr(:(=), children[1],
      Expr(:(:), children[2].first, children[2].last)),
    children[3])


data = """
const k = 20
var j = (k+5) / 2.0
for i in 0:10 {
  println(i/2.0)
}
"""

(ast, pos, error) = parse(lang, data)
println(ast)
println(error)

code = transform(toexpr, ast)
println(eval(code))
