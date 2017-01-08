function no_action(rule, value, first, last, children)
  return Node(rule.name, value, first, last, children, typeof(rule))
end

function liftchild(rule, value, first, last, children)  # = default_action for OR-rules
  if length(children) == 0
    return nothing
  elseif length(children) == 1
    return children[1]
  else
    error("More than one child! rule: $rule; children: $children")
  end
end

function childrenarray(rule, value, first, last, children)
  return children
end

function nodevalue(rule, value, first, last, children)
  return value
end
