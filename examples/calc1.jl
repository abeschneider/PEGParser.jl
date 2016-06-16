using PEGParser

@grammar calc1 begin
  start = (number + op + number){
  	eval(_2)(_1, _3)
  }

  op = plus | minus
  number = (-space + r"[0-9]+"){parse(Int, _1.value)}
  plus = (-space + "+"){symbol(_1.value)}
  minus = (-space + "-"){symbol(_1.value)}
  space = r"[ \t\n\r]*"
end

data = "4+5"
(ast, pos, error) = parse(calc1, data)
println(ast)
