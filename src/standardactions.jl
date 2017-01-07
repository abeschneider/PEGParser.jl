function no_action(rule, value, first, last, children)
  return Node(rule.name, value, first, last, children, typeof(rule))
end

function liftchild(rule, value, first, last, children)  # = default_action for OR-rules
  if length(children) != 1
    error("NYI")
  end
  return children[1]
end
