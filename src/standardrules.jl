macro T_str(s)
  s
end
standardrules = Grammar(T"""
int   => r([0-9]+)r {(r,v,f,l,c) -> parse(Int64,v)}
float => r([-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?)r {(r,v,f,l,c) -> parse(Float64,v)}
space => r([ \t]*)r
"""*
"""
eol   => '\r\n' | '\r' | '\n'
""")
