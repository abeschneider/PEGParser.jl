using PEGParser

@grammar calc1 begin
  start = (number + op + number) {
    apply(eval(children[2]), children[1], children[3])
  }

  op = (plus | minus) { children[1] }
  number = (-space + r"[0-9]+") {parseint(children[1].value)}
  plus = (-space + "+") {symbol(children[1].value)}
  minus = (-space + "-") {symbol(children[1].value)}
  space = r"[ \t\n\r]*"
end

data = "4+5"
(ast, pos, error) = parse(calc1, data)
println(ast)
