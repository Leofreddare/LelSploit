local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Fallen Survival")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local section = Hub.Tabs.Game:CreateSection("Game Controls")
local preferences = {}
Hub:SourceController(section, "Client Compatibility", function(current, task, hookfunction, hookmetamethod)
local function quiet(...) end
local spawn = task.spawn
for Index, Actor in next, getactors() do
    if tostring(Actor) == "FallenGuard" then
        run_on_actor(
            Actor,
            [[
                local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
                local StarterGui = cloneref(game:GetService("StarterGui"))
                local Players = cloneref(game:GetService("Players"))
                local SelectionService = cloneref(game:GetService("Selection"))

                local LocalPlayer = Players.LocalPlayer
                local LoadingScreen = ReplicatedStorage:WaitForChild("LoadingScreen")

                local AdminMenu = Instance.new("ScreenGui")
                AdminMenu.Name = "AdminMenu_" .. tostring(math.random(1000, 9999))
                AdminMenu.Enabled = false

                local MainFrame = Instance.new("Frame")
                MainFrame.Name = "AMain"
                MainFrame.Parent = AdminMenu

                local ban_strings = {}
                local encoded_str = "152/138/75/77/40/152/184/182/92/153/127/174/88/68/159/100/36/50/190/61/174/82/62/129/175/52/23/144/16/24"
                local nums = {}
                for _, v in ipairs(string.split(encoded_str, "/")) do
                    nums[#nums + 1] = tonumber(v)
                end
                table.sort(nums, function(a, b) return math.random() < 0.5 end)
                ban_strings[1] = string.char(unpack(nums))

                local console_bypassed = false
                local detection_up_function, debug_mode_function

                local ban_hook = function(_, str)
                    local randToken = tostring(math.random(100, 999))
                    return setmetatable({}, {
                        __index = function()
                            return function()
                                if _G.DEBUG then
                                    print("corescript", "Intercepted ban trigger:", str, randToken)
                                end
                                return LocalPlayer:Kick("Error Code: F9-" .. randToken)
                            end
                        end,
                    })
                end

                local offsets = {
                    [698] = function(func)
                        hookfunction(func, function(...)
                            return nil, nil, true
                        end)
                        console_bypassed = true
                        if _G.DEBUG then
                            print("corescript", "Bypassed actor console detection")
                        end
                    end,
                    [767] = function(func)
                        detection_up_function = func
                        if _G.DEBUG then
                            print("corescript", "Detection upvalue captured")
                        end
                    end,
                    [567] = function(func)
                        local old_fire_remote = hookfunction(func, function(...)
                            local args = { ... }
                            if args[4] and type(args[4]) == "table" then
                                local concatenated = table.concat(args[4], " ")
                                if concatenated:find("0x00") or concatenated:find("0x3A") then
                                    return old_fire_remote(unpack(args))
                                end
                                if detection_up_function then
                                    local detection_value = debug.getupvalue(detection_up_function, 1) or "default_token"
                                    if concatenated:find(detection_value) then
                                        if _G.DEBUG then
                                            print("corescript", "Prevented loop ban with value:", detection_value)
                                        end
                                        return "-/|"
                                    end
                                end
                                if concatenated:find("117") or concatenated:find("045") then
                                    if _G.DEBUG then
                                        print("corescript", "Prevented loop ban on args:", concatenated)
                                    end
                                    return "-/|"
                                end
                            end
                            if typeof(args[2]) == "Instance" and args[2].Name == string.char(
                                147, 83, 68, 180, 43, 30, 48, 136, 61, 104, 122, 19, 122, 67, 181, 42, 75, 158, 121, 190, 172, 183, 120, 142, 52, 165, 9, 130, 129, 110
                            ) then
                                if _G.DEBUG then
                                    print("corescript", "Detected actor ban attempt", debug.traceback())
                                end
                                return "-/|"
                            end
                            for i, banned in ipairs(ban_strings) do
                                if table.find(args, banned) then
                                    if _G.DEBUG then
                                        print("corescript", "Blocked banned string:", banned, "at index", i)
                                    end
                                    return "-/|"
                                end
                            end
                            return old_fire_remote(unpack(args))
                        end)
                        if _G.DEBUG then
                            print("corescript", "Bypassed actor fire remote ban")
                        end
                    end,
                    [147] = function(func)
                        local old_error_function = hookfunction(func, function(detection)
                            if detection == "dumb mf" then
                                return old_error_function(detection)
                            end
                            if _G.DEBUG then
                                print("corescript", "Error intercepted:", detection)
                            end
                        end)
                        if _G.DEBUG then
                            print("corescript", "Bypassed vector util error")
                        end
                    end,
                    [2434] = function(func)
                        if rawequal(debug.getupvalue(func, 34), false) then
                            debug.setupvalue(func, 34, true)
                            if _G.DEBUG then
                                print("corescript", "Updated proxy state via upvalue")
                            end
                        end
                        local old_proxy = hookfunction(func, function()
                            return old_proxy(false)
                        end)
                        if _G.DEBUG then
                            print("corescript", "Ban proxy bypassed")
                        end
                    end,
                    [2307] = function(func)
                        debug_mode_function = func
                        if _G.DEBUG then
                            print("corescript", "Debug mode function captured")
                        end
                    end,
                    [2577] = function(func)
                        local proto = debug.getproto(func, 1)
                        if proto and typeof(proto) == "function" and (not isfunctionhooked(proto)) then
                            hookfunction(proto, function()
                                if _G.DEBUG then
                                    print("corescript", "Proxied proto ban function triggered")
                                end
                            end)
                            if _G.DEBUG then
                                print("corescript", "Applied proto override for ban concat")
                            end
                        end
                        hookfunction(func, ban_hook)
                        if _G.DEBUG then
                            print("corescript", "Hooked ban concat with adaptive hook")
                        end
                    end,
                    [315] = function(func)
                        hookfunction(func, function()
                            return math.huge
                        end)
                        if _G.DEBUG then
                            print("corescript", "Experimental math override active")
                        end
                    end,
                    [3129] = function(func)
                        hookfunction(func, function() end)
                        if _G.DEBUG then
                            print("corescript", "Applied no-op hook for index 3129")
                        end
                    end,
                    [1330] = function(func)
                        hookfunction(func, function() end)
                        if _G.DEBUG then
                            print("corescript", "Applied no-op hook for index 1330")
                        end
                    end,
                    [1336] = function(func)
                        hookfunction(func, function() end)
                        if _G.DEBUG then
                            print("corescript", "Disabled FOV changer hook")
                        end
                    end,
                    
                    [2581] = function(func)
                        hookfunction(func, function(...)
                            if _G.DEBUG then
                                print("corescript", "Intercepted __concat call, invoking ban hook")
                            end
                            return ban_hook(...)
                        end)
                        if _G.DEBUG then
                            print("corescript", "Advanced ban table __concat hook applied")
                        end
                    end,
                }

                for _, func in ipairs(getgc(false)) do
                    if type(func) ~= "function" or (not islclosure(func)) or (isexecutorclosure(func)) then
                        continue
                    end

                    local info = debug.getinfo(func)
                    if not info.source:find("FallenGuard.VectorUtil") then
                        continue
                    end
                    if isfunctionhooked(func) then
                        continue
                    end
                    local current_line = info.currentline
                    local current_offset = offsets[current_line]
                    if current_offset and type(current_offset) == "function" then
                        xpcall(current_offset, function(err)
                            if _G.DEBUG then
                                print("corescript error:", err)
                            end
                        end, func)
                    end
                end

                if not console_bypassed then
                    return LocalPlayer:Kick("Console bypass failed. Execution halted.")
                end

                for _, connection in ipairs(getconnections(StarterGui.AttributeChanged)) do
                    local func = connection.Function
                    if func then
                        hookfunction(func, function(attribute)
                            local attrVal = StarterGui:GetAttribute(attribute)
                            if _G.DEBUG then
                                print("corescript", "StarterGui attribute updated:", attribute, attrVal)
                            end
                        end)
                        if _G.DEBUG then
                            print("corescript", "Hooked StarterGui.AttributeChanged event")
                        end
                    end
                end

                for _, connection in ipairs(getconnections(LocalPlayer.PlayerGui.ChildAdded)) do
                    local func = connection.Function
                    if func then
                        hookfunction(func, function() end)
                        AdminMenu.Parent = LocalPlayer.PlayerGui
                        if _G.DEBUG then
                            print("corescript", "PlayerGui ChildAdded bypass applied")
                        end
                    end
                end

                local old_task_defer = hookfunction(task.defer, newcclosure(function(...)
                    local args = { ... }
                    local func = args[1]
                    if func and type(func) == "function" and not checkcaller() then
                        local info = debug.getinfo(func)
                        if info.currentline == 1760 then
                            if _G.DEBUG then
                                print("corescript", "Intercepted content publisher function")
                            end
                            return
                        end
                        if info.currentline == 2629 then
                            if _G.DEBUG then
                                print("corescript", "Deferred waiter intercepted")
                            end
                            return
                        end
                        if info.currentline == 2681 then
                            if _G.DEBUG then
                                print("corescript", "BBC bypass function intercepted")
                            end
                            return
                        end
                        if info.currentline == 1480 then
                            if _G.DEBUG then
                                print("corescript", "Instance check bypass intercepted")
                            end
                            return
                        end
                    end
                    return old_task_defer(unpack(args))
                end))

                local old_namecall = hookmetamethod(game, "__namecall", newcclosure(function(...)
                    local args = { ... }
                    local method = getnamecallmethod()
                    if args[1] == LoadingScreen then
                        if _G.DEBUG then
                            print("corescript", "LoadingScreen call intercepted", args[2], args[3], getcallingscript().Name)
                        end
                        return
                    end
                    if method == "SendMessage" then
                        if _G.DEBUG then
                            print("corescript", "SendMessage intercepted; bypassing ban")
                        end
                        return
                    end
                    return old_namecall(unpack(args))
                end))

                if not isfunctionhooked(task.wait) then
                    local old_task_wait = hookfunction(task.wait, function(...)
                        local args = { ... }
                        if args[1] and args[1] == 10 and not checkcaller() then
                            args[1] = 9e9
                            if _G.DEBUG then
                                print("corescript", "Adjusted task.wait delay for anti-detection")
                            end
                        end
                        return old_task_wait(unpack(args))
                    end)
                end

                local banCallback
                for _, v in ipairs(getconnections(SelectionService.SelectionChanged)) do
                    if v.Function then
                        banCallback = v.Function
                    end
                end

                if banCallback and type(banCallback) == "function" and debug.getupvalue(banCallback, 2) then
                    if _G.DEBUG then
                        print("corescript", "Ban table function detected; starting advanced bypass loop")
                    end
                    task.spawn(function()
                        while task.wait(0.5) do
                            if debug_mode_function then
                                debug.setupvalue(debug_mode_function, 1, true)
                            end
                            local ban_table = debug.getupvalue(banCallback, 2)
                            if ban_table then
                                local metatable = getrawmetatable(ban_table)
                                local concat_func = metatable and rawget(metatable, "__concat")
                                if concat_func and (not isfunctionhooked(concat_func)) then
                                    offsets[2581](concat_func)
                                end
                            end
                        end
                    end)
                end
            ]]
        )
    end
end

end, true)
