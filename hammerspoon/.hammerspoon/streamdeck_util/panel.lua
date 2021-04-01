-- Returns a set of children with `panelButton` repeated
function panelChildren(context, panelButton)
    local children = { }
    local count = context['size']['w'] * context['size']['h']
    for i = 0,count-1,1 do
        table.insert(children, panelButton)
    end
    return children
end

