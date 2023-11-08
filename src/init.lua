local active_entries = {}
local respawn_entries = {}
local Runlevel = -1
local telinit = {}
local inittab

--execute a command
local function exec(cmd)
    local pid, errno = syscall("fork", function()
        local _, errno = syscall("execve", "/bin/sh.lua", {
            "-c",
            cmd,
            [0] = '[init]'
        })
        if not _ then
            printf("init: execve failed: %d: %s\n", tonumber(errno or -1), tostring(_))
            syscall("exit", 1)
        end
    end)

    if not pid then
        printf("init: fork failed: %d\n", errno)
        return nil, errno
    else
        return pid
    end
end

local function load_inittab()
    local tab = ""
    do
        local fd,e = syscall("open", "/etc/inittab", "r")
        local chunk
        local i = 0
        repeat
            chunk = syscall("read", fd, math.huge)
            tab = tab .. (chunk or "")
        until not chunk
        syscall("close", fd)
    end
    local parsed = {}
    do
        local lines = split(tab, "\n")
        for _, line in ipairs(lines) do
            local splitted = split(line, ":")
            local id = splitted[1]
            local runlevels = {}
            for runlevel in splitted[2]:gmatch("%d") do
                runlevels[tonumber(runlevel)] = true
            end
            local action = splitted[3]
            local cmd = splitted[4]:gsub("\r", "")
            parsed[#parsed+1] = {
                id = id,
                runlevels = runlevels,
                cmd = cmd,
                action = action
            }
        end
    end
    return parsed
end

local function start_service(entry)
    if active_entries[entry.id] then return true end
    printf("init: Starting '%s'\n", entry.id)
    local pid,errno = exec(entry.cmd)

    if not pid then
        printf("init: Could not fork for entry %s: %d\n", entry.id, errno)
        return nil, errno
    elseif table.contains({"once", "boot"}, entry.action) then
        active_entries[pid] = entry
    elseif table.contains({"wait", "bootwait"}, entry.action) then
        syscall("wait", pid)
    elseif entry.action == "respawn" then
        respawn_entries[pid] = entry
    end

    active_entries[entry.id] = pid
end

local function stop_service(entry)
    local pid = active_entries[entry.id]
    if pid then
        if syscall("kill", pid, "SIGTERM") then
            active_entries[pid] = nil
            respawn_entries[pid] = nil
            active_entries[entry.id] = nil
            return true
        end
    end
end

local function switch_runlevel(runlevel)
    printf("init: Switch to runlevel %d\n", runlevel)
    Runlevel = runlevel
    
    for id, entry in pairs(active_entries) do
        if type(id) == "string" then
            if not entry.runlevels[runlevel] then
                stop_service(entry)
            end
        end
    end
    
    for _, entry in pairs(inittab) do
        if entry.runlevels[runlevel] then
            start_service(entry)
        end
    end
end

local valid_actions = {
    runlevel = true,
    start = true,
    stop = true,
    status = true,
}

return {
    main = function(...)
        local pid = syscall("getpid")
        if pid ~= 1 then
            printf("Kinit must be run as process 1 (is %s)\n", dump(pid))
            syscall("exit", 1)
        end
        printf("init: Kinit is starting\n")
        inittab = load_inittab()
        switch_runlevel(1) -- Single user mode

        while true do
            -- printf("hello world\n")
            coroutine.yield()
        end

        --[[local evt, err = syscall("open", "/proc/events", "rw")
        if not evt then
            printf("init: \27[91mWARNING: Failed to open /proc/events (%d) - %s", err, "telinit responses will not work\27[m\n")
        end

        while true do
            local sig, id, req, a = coroutine.yield(0.5)
            if sig == "telinit" then
                if type(id) ~= "number" then
                    printf("init: Cannot respond to non-numeric PID %s\n", tostring(id))
                elseif not syscall("kill", id, "SIGEXIST") then
                    printf("init: Cannot respond to nonexistent process %d\n", id)
                elseif type(req) ~= "string" or not valid_actions[req] then
                    printf("init: Got bad telinit %s\n", tostring(req))
                else
                    if req == "runlevel" and arg and type(arg) ~= "number" then
                        printf("init: Got bad runlevel argument %s\n", tostring(arg))
                    elseif req ~= "runlevel" and type(arg) ~= "string" then
                        printf("init: Got bad %s argument %s\n", req, tostring(arg))
                    else
                        telinit[#telinit+1] = {req = req, from = id, arg = a}
                    end
                end
            end
            if #telinit > 0 then
                local request = table.remove(telinit, 1)
            
                if request == "runlevel" then
                    if not request.arg then
                        syscall("ioctl", evt, "send", request.from, "response", "runlevel", Runlevel)
                    elseif request.arg ~= Runlevel then
                        switch_runlevel(request.arg)
                        syscall("ioctl", evt, "send", request.from, "response", "runlevel", true)
                    end
                elseif request == "start" then
                    if active_entries[request.arg] then
                        syscall("ioctl", evt, "send", request.from, "response", "start", start_service(active_entries[request.arg]))
                    end
                elseif request == "stop" then
                    if active_entries[request.arg] then
                        syscall("ioctl", evt, "send", request.from, "response", "stop", stop_service(active_entries[request.arg]))
                    end
                end
            end
        end]]
    end
}