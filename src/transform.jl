type MatchRule{T} end

# default transform is to do nothing
transform(fn::Function, value) = value

function transform(fn::Function, node::Node)
  if isa(node.children, Array)
    transformedchildren = [transform(fn, child) for child in node.children]
  else
    transformedchildren = transform(fn, node.children)
  end

  if method_exists(fn, (Node, Any, MatchRule{Symbol(node.name)}))
    label = MatchRule{Symbol(node.name)}()
  else
    label = MatchRule{:default}()
  end

  return fn(node, transformedchildren, label)
end
