for rule in subtypes(Rule)
  definition = "==(r1::$rule,r2::$rule) = ("
  for field in fieldnames(rule)
    definition *= "r1.$field==r2.$field && "
  end
  definition *= "true)"
  eval(parse(definition))
end


## GRAMMAR
==(g1::Grammar,g2::Grammar) = g1.rules==g2.rules
function diff(g1::Grammar,g2::Grammar)
  for (key,val) in g1.rules
    if g1.rules[key] != g2.rules[key]
      println("$key:")
      println("+ $(g1.rules[key])")
      println("- $(g2.rules[key])")
    end
  end
end
