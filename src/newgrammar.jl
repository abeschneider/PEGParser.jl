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

grammargrammar_string = """
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
function createTermNode(rule, value, first, last, children)
  disescapedcontent = replace(children[1].value, "''", "'")
  return Node(rule.name, disescapedcontent, first, last, [], Terminal)
end

# legibility
sup = SuppressRule
ref = ReferencedRule
and = AndRule
or  = OrRule

"""
The grammar to parse grammars.
"""
const grammargrammar = Grammar(Dict{Symbol,Any}(
:start     => and( sup(ZeroOrMoreRule(ref(:emptyline))), ZeroOrMoreRule(ref(:ruleline)) ),

:emptyline => and( sup(ref(:space)), ref(:endofline) ),
:ruleline  => and([ sup(ref(:space)), ref(:rule), ZeroOrMoreRule(sup(ref(:emptyline))) ]),
:rule      => and("RULE",[ ref(:symbol), sup(ref(:space)), Terminal("=>"), sup(ref(:space)), ref(:definition)]),

:definition=> or([ ref(:parenrule), ref(:double), ref(:single) ]), # from left to right: ' can contain ' => parse order

:single    => and( or([ref(:parenrule),ref(:zeromorerule),ref(:onemorerule),ref(:optionalrule),ref(:suppressrule),ref(:regexrule),ref(:term),ref(:refrule)]), OptionalRule(and(sup(ref(:space)),ref(:action))) ), # only single token rules can have associated actions (-> unique interpretation)
:double    => or([ref(:orrule),ref(:andrule)]), # 'and' groups stronger than 'or'

:parenrule => and("PAREN",[ sup(Terminal('(')), sup(ref(:space)), ref(:definition), sup(ref(:space)), sup(Terminal(')')) ]),
:orrule    => and("OR",[ or(ref(:andrule),ref(:single)), OneOrMoreRule(and([ sup(ref(:space)), sup(Terminal('|')), sup(ref(:space)), or(ref(:andrule),ref(:single)) ])) ]),
:andrule   => and("AND",[ ref(:single), OneOrMoreRule(and([ sup(ref(:space)), sup(Terminal('&')), sup(ref(:space)), ref(:single) ])) ]),
:zeromorerule => and("*",[ sup(Terminal("*(")), ref(:definition), sup(Terminal(')')) ]),
:onemorerule => and("+",[ sup(Terminal("+(")), ref(:definition), sup(Terminal(')')) ]),
:optionalrule => and("?",[ sup(Terminal("?(")), ref(:definition), sup(Terminal(')')) ]),
:suppressrule => and("-",[ sup(Terminal("-(")), ref(:definition), sup(Terminal(')')) ]),
:refrule   => ref("REF",:symbol,liftchild_parentname),
:term      => and("TERM",[ sup(Terminal('\'')), RegexRule(r"([^']|'')+"), sup(Terminal('\'')) ], createTermNode),
:regexrule => and("REGEX",[ sup(Terminal("r(")), RegexRule(r".*?(?=\)r)"), sup(Terminal(")r")) ]), # r(...)r to prevent escaping issues with '(', ')' within the regex, '"' has the same issue but is even weirder because we want to parse a string "... r"..." ..." would then actually have to be input as "... r\"...\" ..." and within the regex "... r\" \\" \" ..."


:action    => and("ACTION",[sup(Terminal('{')), RegexRule(r"[^}]*"), sup(Terminal('}'))]),

:space     => RegexRule(r"[ \t]*"),
:endofline => or([Terminal("\r\n"), Terminal('\r'), Terminal('\n'), Terminal(';')]),
:symbol    => RegexRule("SYM",r"[a-zA-Z_][a-zA-Z0-9_]*"),
))

const testtext = """ 
foo => bar & baz|foobar | '''foobar'''
"""
