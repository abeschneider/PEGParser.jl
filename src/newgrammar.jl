examplestring = """
  start = expr

  expr_op = term + op1 + expr
  expr = expr_op | term
  term_op = factor + op2 + term

  term = term_op | factor
  factor = number | pfactor
  pfactor = (lparen + expr + rparen){ _2 }
  op1 = add | sub
  op2 = mult | div

  number = (-space + float){ parsefloat(_1.value) } | (-space + integer){ parseint(_1.value) }
  add = (-space + "+"){ symbol(_1.value) }
  sub = (-space + "-"){ symbol(_1.value) }
  mult = (-space + "*"){ symbol(_1.value) }
  div = (-space + "/"){ symbol(_1.value) }

  lparen = (-space + "("){ _1 }
  rparen = (-space + ")"){ _1 }
  space = r"[ \n\r\t]*"
"""

grammargrammar = """
start => *(line)

line => emptyline | rule
emptyline => space & endofline
rule => symbol & -(space) & '=>' & -(space) & definition & -(emptyline)

definition => andnode | symbol
andnode => definition & -(space) & '&' & -(space) & definition

space => r("[ \t]*)
endofline => "\r\n" | '\r' | '\n'
symbol => r("\w+")
"""

function liftchild_parentname(rule, value, first, last, children) 
  if length(children) != 1
    error("NYI")
  end
  return Node(rule.name, children[1].value, first, last, children[1].children, children[1].ruleType)
end
function liftchild_childname(rule, value, first, last, children) 
  if length(children) != 1
    error("NYI")
  end
  return children[1]
end

grammargrammar = Grammar(Dict{Symbol,Any}(
:start     => AndRule(SuppressRule(ZeroOrMoreRule(ReferencedRule(:emptyline))),ZeroOrMoreRule(ReferencedRule(:ruleline))),

:emptyline => AndRule(SuppressRule(ReferencedRule(:space)), ReferencedRule(:endofline)),
:ruleline  => AndRule([SuppressRule(ReferencedRule(:space)), ReferencedRule(:rule), ZeroOrMoreRule(SuppressRule(ReferencedRule(:emptyline)))]),
:rule      => AndRule("RULE",[ReferencedRule(:symbol), SuppressRule(ReferencedRule(:space)), Terminal("=>"), SuppressRule(ReferencedRule(:space)), ReferencedRule(:definition)]),

:definition=> AndRule([OrRule([ReferencedRule(:parenrule),ReferencedRule(:andrule),ReferencedRule(:refrule)]),OptionalRule(ReferencedRule(:action))]),

:single    => OrRule([ReferencedRule(:parenrule),ReferencedRule(:term),ReferencedRule(:refrule)]),
:double    => OrRule([ReferencedRule(:andrule)]),

:andrule   => AndRule("AND", [ ReferencedRule(:single), OneOrMoreRule(AndRule([SuppressRule(ReferencedRule(:space)), Terminal('&'), SuppressRule(ReferencedRule(:space)), ReferencedRule(:single)])) ]),

:parenrule => AndRule("PAREN", [SuppressRule(Terminal('(')), SuppressRule(ReferencedRule(:space)), ReferencedRule(:definition), SuppressRule(ReferencedRule(:space)), SuppressRule(Terminal(')'))],liftchild_childname),

:refrule   => ReferencedRule("REF",:symbol,liftchild_parentname),

:term      => EmptyRule(),

:action    => AndRule("ACTION",[Terminal('{'), RegexRule(r"[^}]*"), Terminal('}')]),

:space     => RegexRule(r"[ \t]*"),
:endofline => OrRule([Terminal("\r\n"), Terminal('\r'), Terminal('\n'), Terminal(';')]),
:symbol    => RegexRule(r"\w+"),
))

const testtext = """ 
foo => bar & (baz&foobar)
"""
