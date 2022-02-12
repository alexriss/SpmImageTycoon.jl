"""Delete old files."""
function delete_files(i = 1)::Nothing
    try
        if isdir(DIR_cache)
            rm(DIR_cache, recursive=true)
        end
        if isfile(FNAME_odp)
            rm(FNAME_odp)
        end
        if i > 1
            println(" ok.")
        end
    catch e
        if isa(e, Base.IOError)
            if i == 1 
                print("Can't delete old files. Retrying.")
            else
                print(".")
            end
            if i > 5
                throw(e)
            end
            sleep(1)
            delete_files(i+1)
        else
            throw(e)
        end
    end
    return nothing
end

"""Compare two dictionaries of items."""
function compare_dicts(dict1, dict2, tol=1e-6; basekey="")
    for (k,v1) in dict1
        if k in ["created", "last_modified", "filename_display_last_modified"]  # these won't be the same
            continue
        end

        if !haskey(dict2, k)
            return false
        end
        v2 = dict2[k]

        if v1 == v2
            continue
        end
        if isa(v1, Dict)
            curr_basekey = ""
            if basekey == ""
                curr_basekey = k
            end
            if !compare_dicts(v1, v2, basekey=curr_basekey)
                return false
            end
        elseif isa(v1, AbstractArray)
            if !(length(v1) == length(v2))
                println("$(basekey): not equal $(k):\n $(v1)\n $(v2)")
                return false
            end
            if !all(abs.(v1 .- v2) .< tol)
                println("$(basekey): not equal $(k):\n $(v1)\n $(v2)")
                return false
            end
        elseif isa(v1, String)
            if v1 != v2
                println("$(basekey): not equal $(k):\n $(v1)\n $(v2)")
                return false
            end
        elseif isnan(v1)
            if !isnan(v2)
                println("$(basekey): not equal $(k):\n $(v1)\n $(v2)")
                return false
            end
        elseif isa(v1, Number)
            if !(abs(v1 - v2) < tol)
                println("$(basekey): not equal $(k):\n $(v1)\n $(v2)")
                return false
            end
        else
            if v1 != v2
                println("$(basekey): not equal $(k):\n $(v1)\n $(v2)")
                return false
            end
        end
    end
    return true
end


"""Escape dots in a HTML-id, so it can be used in querySelectorAll."""
function escape_id(id::String)::String
    id = replace(id, "." => "\\.")
    id = replace(id, " " => "\\ ")
    return id
end

"""Escape dots in HTML-ids, so it can be used in querySelectorAll."""
function selector(ids::Vector{String})::String
    ids_ = ["#" * escape_id(id) for id in ids]
    return join(ids_, ",") 
end

"""Construct querySelector from id."""
function selector(id::String)::String
    return "#" * escape_id(id)
end

"""Get window.items from js."""
function get_items(sleeptime=2.)
    sleep(sleeptime)
    return @js w window.items
end

"""Sends a key-press to js. Also modifiers can be included. E.g. `ctrl-a` or `ctrl-shift-a`."""
function send_key(k::String)
    s = split(k, "-")
    k = s[end]
    modifiers = s[1:end-1]
    @js w test_press_key($k, $modifiers)
    sleep(0.1)
end

"""Sends a key-press to js. Also modifiers can be included. E.g. `ctrl-a` or `ctrl-shift-a`."""
function send_key(k::AbstractArray)
    for k_ in k
        send_key(k_)
    end
end

"""Sends a mouse click to all elements set by the css selector."""
function send_click(sel::String)
    @js w test_click_mouse($sel)
    sleep(0.2)
end

"""Sends a double-click to all elements set by the css selector.
Does not seem to work so well."""
function send_double_click(sel::String)
    @js w test_dblclick_mouse($sel)
    sleep(0.2)
end

"""Hovers the mouse over all elements set by the css selector."""
function send_hover_mouse(sel::String)
    @js w test_hover_mouse($sel)
    sleep(0.2)
end


function setmtime(path::AbstractString, mtime::Real, atime::Real=mtime; follow_symlinks::Bool=true)
    req = Libc.malloc(_sizeof_uv_fs)
    try
        if follow_symlinks
            ret = ccall(:uv_fs_utime, Cint,
                (Ptr{Cvoid}, Ptr{Cvoid}, Cstring, Cdouble, Cdouble, Ptr{Cvoid}),
                C_NULL, req, path, atime, mtime, C_NULL)
        else
            ret = ccall(:uv_fs_lutime, Cint,
                (Ptr{Cvoid}, Ptr{Cvoid}, Cstring, Cdouble, Cdouble, Ptr{Cvoid}),
                C_NULL, req, path, atime, mtime, C_NULL)
        end
        ccall(:uv_fs_req_cleanup, Cvoid, (Ptr{Cvoid},), req)
        ret < 0 && uv_error("utime($(repr(path)))", ret)
    finally
        Libc.free(req)
    end
end
setmtime(path::AbstractString, mtime::Dates.AbstractDateTime, atime::Dates.AbstractDateTime=mtime; follow_symlinks::Bool=true) =
    setmtime(path, Dates.datetime2unix(mtime), Dates.datetime2unix(atime); follow_symlinks=follow_symlinks)