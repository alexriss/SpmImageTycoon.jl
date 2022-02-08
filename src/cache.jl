# Simple version of a linked list


mutable struct ListNode{T}
    key::String
    val::Union{T,Missing}
    prev::ListNode{T}
    next::ListNode{T}

    function ListNode{T}(key, val) where T
        node = new{T}()
        node.key = key
        node.val = val
        node.next = node
        node.prev = node
        return node
    end
end


mutable struct ListNodeCache{T}
    count::Int
    capacity::Float64
    map::Dict{String,ListNode{T}}  # for fast access
    head::ListNode{T}
    tail::ListNode{T}

    function ListNodeCache{T}(capacity) where T
        l = new{T}()
        l.count = 0
        l.capacity = capacity
        l.map = Dict{String,T}()
        l.head = ListNode{T}("", missing)
        l.tail = ListNode{T}("", missing)
        l.head.next = l.tail
        l.tail.prev = l.head
        return l
    end
end


function Base.delete!(l::ListNodeCache, node::ListNode)::Nothing
    node.prev.next = node.next
    node.next.prev = node.prev
    node = nothing
    l.count -= 1
    return nothing
end


function Base.pushfirst!(l::ListNodeCache, node::ListNode)::Nothing
    node.next = l.head.next
    node.next.prev = node
    node.prev = l.head
    l.head.next = node
    l.count += 1
    return nothing
end


function get_cache(l::ListNodeCache{T}, key::String)::Union{T,Missing} where T
    if haskey(l.map, key)
        node = l.map[key]
        res = node.val
        delete!(l, node)
        pushfirst!(l, node)
        return res
    else
        return missing
    end
end


function set_cache(l::ListNodeCache{T}, key::String, val::T)::Nothing where T
    if haskey(l.map, key)
        node = l.map[key]
        node.val = val
        delete!(l, node)
        pushfirst!(l, node)
    else
        node = ListNode{T}(key, val)
        l.map[key] = node
        while Base.summarysize(l) > l.capacity * 1e6 && l.count > 1
            delete!(l.map, l.tail.prev.key)
            delete!(l, l.tail.prev)
        end
        pushfirst!(l, node)
    end
    return nothing
end
