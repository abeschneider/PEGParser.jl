###########
# ACTIONS #
###########

function liftchild_parentname(rule, value, first, last, children) 
  if length(children) != 1
    error("NYI")
  end
  return Node(rule.name, children[1].value, first, last, children[1].children, children[1].ruleType)
end
function liftchild_childname(rule, value, first, last, children)  # or_default_action
  if length(children) != 1
    error("NYI")
  end
  return children[1]
end
function createRegexNode(rule, value, first, last, children)
  return Node("REGEX", children[1].value, first, last, children[1].children, children[1].ruleType)
end
function createActionNode(rule, value, first, last, children)
  return Node("ACTION", children[1].value, first, last, children[1].children, children[1].ruleType)
end
function createRefNode(rule, value, first, last, children)
  return Node("REF", children[1].value, first, last, children[1].children, children[1].ruleType)
end
function createTermNode(rule, value, first, last, children)
  disescapedcontent = replace(children[1].value, "''", "'")
  return Node("TERM", disescapedcontent, first, last, [], Terminal)
end

###########################################################
# HANDCONSTRUCTION OF THE GRAMMAR TO PARSE GRAMMARSTRINGS #
###########################################################

# legibility
sup = SuppressRule
ref = ReferencedRule
and = AndRule
or  = OrRule

"""
The grammar to parse grammars. For obvious reasons this has to be constructed "by hand" from constructors, as it is needed itself for the parsing of grammar strings. `grammargrammar_string` is a consistency check and parses to grammargrammar - but only when grammargrammar already exists for its parsing.
"""
const grammargrammar = Grammar(Dict{Symbol,Any}(
:start     => and([ sup(ZeroOrMoreRule(ref(:emptyline))), ZeroOrMoreRule("ALLRULES",ref(:ruleline)) ],liftchild_childname),

:emptyline => and( sup(ref(:space)), ref(:endofline) ),
:ruleline  => and([ sup(ref(:space)), ref(:rule), ZeroOrMoreRule(sup(ref(:emptyline))) ],liftchild_childname),
:rule      => and("RULE",[ ref(:symbol), sup(ref(:space)), sup(Terminal("=>")), sup(ref(:space)), ref(:definition)]),

:definition=> or([ ref(:double), ref(:single) ]), # from left to right: ' can contain ' => parse order

:single    => and("SINGLE", or([ref(:parenrule),ref(:zeromorerule),ref(:onemorerule),ref(:optionalrule),ref(:suppressrule),ref(:regexrule),ref(:term),ref(:refrule)]), OptionalRule(and([sup(ref(:space)),ref(:action)],liftchild_childname),liftchild_childname) ), # only single token rules can have associated actions (-> unique interpretation)
:double    => or([ref(:orrule),ref(:andrule)]), # 'and' groups stronger than 'or'

:parenrule => and("PAREN",[ sup(Terminal('(')), sup(ref(:space)), ref(:definition), sup(ref(:space)), sup(Terminal(')')) ]),
:orrule    => and("OR",[ or(ref(:andrule),ref(:single)), OneOrMoreRule("more",and([ sup(ref(:space)), sup(Terminal('|')), sup(ref(:space)), or(ref(:andrule),ref(:single)) ],liftchild_childname)) ]),
:andrule   => and("AND",[ ref(:single), OneOrMoreRule("more",and([ sup(ref(:space)), sup(Terminal('&')), sup(ref(:space)), ref(:single) ],liftchild_childname)) ]),
:zeromorerule => and("*",[ sup(Terminal("*(")), sup(ref(:space)), ref(:definition), sup(ref(:space)), sup(Terminal(')')) ]),
:onemorerule  => and("+",[ sup(Terminal("+(")), sup(ref(:space)), ref(:definition), sup(ref(:space)), sup(Terminal(')')) ]),
:optionalrule => and("?",[ sup(Terminal("?(")), sup(ref(:space)), ref(:definition), sup(ref(:space)), sup(Terminal(')')) ]),
:suppressrule => and("-",[ sup(Terminal("-(")), sup(ref(:space)), ref(:definition), sup(ref(:space)), sup(Terminal(')')) ]),
:refrule   => ref(:symbol,createRefNode),
:term      => and([ sup(Terminal('\'')), RegexRule(r"([^']|'')+"), sup(Terminal('\'')) ], createTermNode),
:regexrule => and([ sup(Terminal("r(")), RegexRule(r".*?(?=\)(?=r))"), sup(Terminal(")r")) ],createRegexNode), # r(...)r to prevent escaping issues with '(', ')' within the regex, '"' has the same issue but is even weirder because we want to parse a string "... r"..." ..." would then actually have to be input as "... r\"...\" ..." and within the regex "... r\" \\" \" ..."

:action    => and([sup(Terminal('{')), RegexRule(r"[^}]*"), sup(Terminal('}'))],createActionNode),

:space     => RegexRule(r"[ \t]*"),
:endofline => or([Terminal("\r\n"), Terminal('\r'), Terminal('\n'), Terminal(';')]),
:symbol    => RegexRule("SYM",r"[a-zA-Z_][a-zA-Z0-9_]*"),
))

######################################
# TRANSFORMS FOR THIS GRAMMARGRAMMAR #
######################################

togrammar(node, children, ::MatchRule{:default}) = (warn("Unmatched transform: $node"); children)
togrammar(node, children, ::MatchRule{:PAREN}) = children[1]
togrammar(node, children, ::MatchRule{:TERM}) = Terminal(node.value)
togrammar(node, children, ::MatchRule{:REGEX}) = RegexRule(Regex(node.value))
togrammar(node, children, ::MatchRule{:REF}) = ReferencedRule(Symbol(node.value))
togrammar(node, children, ::MatchRule{:ACTION}) = node.value
function togrammar(node, children, ::MatchRule{:SINGLE})
  node = children[1]
  if length(children)==2 # action specification exists
    action = parse(children[2])
    if isa(action,AbstractString)
      node.name = action
    elseif isa(action,Function)
      node.action = action
    elseif isa(action,Expr)
      node.action = eval(action)
    elseif isa(action,Symbol)
      node.action = getfield(PEGParser,action)
    else
      error("Unexpected action type $(typeof(action)): $action")
    end
  end
  return node
end
togrammar(node, children, ::MatchRule{:*}) = ZeroOrMoreRule(children[1])
togrammar(node, children, ::MatchRule{:?}) = OptionalRule(children[1])
togrammar(node, children, ::MatchRule{:+}) = OneOrMoreRule(children[1])
togrammar(node, children, ::MatchRule{:-}) = SuppressRule(children[1])
togrammar(node, children, ::MatchRule{:more}) = Vector{Rule}(children)
function togrammar(node, children, ::MatchRule{:AND})
  list = Vector{Rule}()
  push!(list,children[1])
  append!(list,children[2])
  AndRule(list)
end
function togrammar(node, children, ::MatchRule{:OR})
  list = Vector{Rule}()
  push!(list,children[1])
  append!(list,children[2])
  OrRule(list)
end
togrammar(node, children, ::MatchRule{:SYM}) = Symbol(node.value)
togrammar(node, children, ::MatchRule{:RULE}) = (children[1],children[2])
togrammar(node, children, ::MatchRule{:ALLRULES}) = Grammar(Dict(children))

###########
# TESTING #
###########

"""
`grammargrammar` parses `grammargrammar_string` such that when transformed with `transform(togrammar,ast)` again `grammmargrammmar` results. This is a consistency check and allows to understand what happens in the `grammargrammar` construction in a more legible form.
"""
const grammargrammar_string = """
start      => (-(*(emptyline)) & *(ruleline) {"ALLRULES"}) {liftchild_childname}

emptyline  => -(space) & endofline
ruleline   => ( -(space) & rule & *(-(emptyline)) ) {liftchild_childname}
rule       => ( symbol & -(space) & -('=>') & -(space) & definition ) {"RULE"}

definition => double | single

single     => ( (parenrule | zeromorerule | onemorerule | optionalrule | suppressrule | regexrule | term | refrule) & ?((-(space) & action) {liftchild_childname}) {liftchild_childname} ) {"SINGLE"}
double     => orrule | andrule

parenrule  => ( -('(') & -(space) & definition & -(space) & -(')') ) {"PAREN"}
orrule     => ( (andrule | single) & +( (-(space) & -('|') & -(space) & (andrule|single)){liftchild_childname} ){"more"} ) {"OR"}
andrule    => (            single  & +( (-(space) & -('&') & -(space) &          single ){liftchild_childname} ){"more"} ) {"AND"}
zeromorerule   => ( -('*(') & -(space) & definition & -(space) & -(')') ){"*"}
onemorerule    => ( -('+(') & -(space) & definition & -(space) & -(')') ){"+"}
optionalrule   => ( -('?(') & -(space) & definition & -(space) & -(')') ){"?"}
suppressrule   => ( -('-(') & -(space) & definition & -(space) & -(')') ){"-"}
refrule    => symbol {createRefNode}
term       => ( -('''') & r(([^']|'')+)r & -('''') ) {createTermNode}
regexrule  => ( -('r(') & r(.*?(?=\\)(?=r)))r & -(')r') ) {createRegexNode} 

action     => (-('{') & r([^}]*)r & -('}')) {createActionNode}

space      => r([ \\t]*)r
endofline  => '\r\n' | '\r' | '\n' | ';'
symbol     => r([a-zA-Z_][a-zA-Z0-9_]*)r {"SYM"}
"""

