local Entries, Session = ...
local Players = game:GetService("Players")

assert(type(Entries) == "table", "Whitelist entries must be a table.")

Session = type(Session) == "table" and Session or {}
for _, Key in ipairs({"ById", "ByName", "GroupsById", "GroupsByName", "Expirations"}) do
    if type(Session[Key]) ~= "table" then
        Session[Key] = {}
    end
end

local ById, ByName = {}, {}
local IdToName, NameToId = {}, {}
local Order = {"Owner", "Admin", "VIP", "Member"}
local Ranks = {owner = 1, admin = 2, vip = 3, member = 4}
local CurrentTimer, OnAccessLost
local Destroyed = false

local function NormalizeId(Value)
    if type(Value) ~= "number" and type(Value) ~= "string" then return nil end
    if type(Value) == "string" and not Value:match("^%d+$") then return nil end
    local Id = tonumber(Value)
    if Id and Id > 0 and Id <= 9007199254740991 and Id % 1 == 0 then return Id end
end

local function NormalizeName(Value)
    if type(Value) ~= "string" then return nil end
    local Name = Value:match("^%s*(.-)%s*$")
    if Name ~= "" and not Name:match("^%d+$") and Name:match("^[%w_]+$") then
        return string.lower(Name)
    end
end

local function NormalizeGroup(Value)
    if type(Value) ~= "string" then return nil end
    local Name = Value:match("^%s*(.-)%s*$")
    if Name == "" then return nil end
    local Key = string.lower(Name)
    return Key, Order[Ranks[Key]] or Name
end

local function Remember(Id, Name)
    if Id and Name then
        IdToName[Id], NameToId[Name] = Name, Id
    end
end

local function ResolvePlayer(Input)
    if typeof(Input) == "Instance" then
        if not Input:IsA("Player") then return nil, nil end
        local Id, Name = NormalizeId(Input.UserId), NormalizeName(Input.Name)
        Remember(Id, Name)
        return Id, Name
    end

    local Id = NormalizeId(Input)
    local Name = Id == nil and NormalizeName(Input) or nil
    if not Id and not Name then return nil, nil end

    if Id then
        Name = IdToName[Id]
        if not Name then
            local Player = Players:GetPlayerByUserId(Id)
            if Player then
                Name = NormalizeName(Player.Name)
                Remember(Id, Name)
            end
        end
        if not Name and (next(ByName) or next(Session.ByName) or next(Session.GroupsByName)) then
            local Success, Result = pcall(Players.GetNameFromUserIdAsync, Players, Id)
            if Success then
                Name = NormalizeName(Result)
                Remember(Id, Name)
            end
        end
    else
        Id = NameToId[Name]
        if not Id then
            for _, Player in ipairs(Players:GetPlayers()) do
                if NormalizeName(Player.Name) == Name then
                    Id = NormalizeId(Player.UserId)
                    Remember(Id, Name)
                    break
                end
            end
        end
        if not Id and (next(ById) or next(Session.ById) or next(Session.GroupsById)) then
            local Success, Result = pcall(Players.GetUserIdFromNameAsync, Players, Name)
            if Success then
                Id = NormalizeId(Result)
                Remember(Id, Name)
            end
        end
    end
    return Id, Name
end

for Key, Entry in pairs(Entries) do
    if Entry == true or type(Entry) == "table" then
        local Id = NormalizeId(Key)
        if Id then
            ById[Id] = Entry
        else
            local Name = NormalizeName(Key)
            if Name then ByName[Name] = Entry end
        end
    end
end

local function ParseTime(Value, CacheKey)
    if Value == nil then return nil, true end
    if type(Value) ~= "string" and type(Value) ~= "number" then return nil, false end

    local Text = tostring(Value)
    local Day, Month, Year = Text:match("^(%d%d?)/(%d%d?)/(%d%d%d%d)$")
    if Day then
        Day, Month, Year = tonumber(Day), tonumber(Month), tonumber(Year)
        local Success, Date = pcall(DateTime.fromUniversalTime, Year, Month, Day, 23, 59, 59)
        if not Success then return nil, false end
        local Parts = Date:ToUniversalTime()
        if Parts.Year ~= Year or Parts.Month ~= Month or Parts.Day ~= Day then return nil, false end
        return Date.UnixTimestamp + 1, true
    end

    local Seconds
    if type(Value) == "number" then
        Seconds = Value
    else
        local Minutes, Sec = Text:match("^(%d+):(%d%d)$")
        local Hours, Mins, S = Text:match("^(%d+):(%d%d):(%d%d)$")
        local Quantity, Unit = Text:match("^(%d+)([smhd])$")
        if Minutes and tonumber(Sec) < 60 then
            Seconds = tonumber(Minutes) * 60 + tonumber(Sec)
        elseif Hours and tonumber(Mins) < 60 and tonumber(S) < 60 then
            Seconds = tonumber(Hours) * 3600 + tonumber(Mins) * 60 + tonumber(S)
        elseif Quantity then
            Seconds = tonumber(Quantity) * ({s = 1, m = 60, h = 3600, d = 86400})[Unit]
        end
    end
    if not Seconds or Seconds ~= Seconds or Seconds < 0 or Seconds == math.huge or Seconds > 315576000000 then
        return nil, false
    end

    if CacheKey then
        if not Session.Expirations[CacheKey] then
            Session.Expirations[CacheKey] = os.time() + Seconds
        end
        return Session.Expirations[CacheKey], true
    end
    return os.time() + Seconds, true
end

local function ActiveTime(Time, Key)
    local Deadline, Valid = ParseTime(Time, Key)
    return Valid and (not Deadline or os.time() < Deadline)
end

local function ActiveOverride(Value)
    if type(Value) == "table" then
        if Value.ExpiresAt and os.time() >= Value.ExpiresAt then return nil end
        return Value.Value
    end
    return Value
end

local function EntryActive(Entry, Key)
    return Entry == true or (type(Entry) == "table" and ActiveTime(Entry.Time, Key .. ":entry:" .. tostring(Entry.Time)))
end

local function GetAllowed(Id, Name)
    local OverrideId = Id and ActiveOverride(Session.ById[Id])
    local OverrideName = Name and ActiveOverride(Session.ByName[Name])
    if OverrideId == false or OverrideName == false then return false end
    if OverrideId == true or OverrideName == true then return true end
    return (Id and EntryActive(ById[Id], "id:" .. Id))
        or (Name and EntryActive(ByName[Name], "name:" .. Name)) or false
end

local function IncludeGroup(Result, Name, Value, Key)
    local Group, Label = NormalizeGroup(Name)
    if not Group then return end
    if Value == true or (type(Value) == "table" and Value.Enabled ~= false
        and ActiveTime(Value.Time, Key .. ":" .. Group .. ":" .. tostring(Value.Time))) then
        Result[Group] = Label
    end
end

local function AddConfiguredGroups(Result, Entry, Key)
    if type(Entry) ~= "table" or not EntryActive(Entry, Key) then return end

    if type(Entry.Group) == "string" then
        IncludeGroup(Result, Entry.Group, true, Key)
    elseif type(Entry.Group) == "table" then
        IncludeGroup(Result, Entry.Group.Name or Entry.Group[1], Entry.Group, Key .. ":group")
    end

    if type(Entry.Groups) == "table" then
        for Group, Value in pairs(Entry.Groups) do
            if type(Group) == "number" then
                if type(Value) == "string" then
                    IncludeGroup(Result, Value, true, Key)
                elseif type(Value) == "table" then
                    IncludeGroup(Result, Value.Name or Value[1], Value, Key .. ":group:" .. Group)
                end
            else
                IncludeGroup(Result, Group, Value, Key .. ":group")
            end
        end
    end
end

local function GetGroups(Id, Name)
    local Groups = {member = "Member"}
    if Id then AddConfiguredGroups(Groups, ById[Id], "id:" .. Id) end
    if Name then AddConfiguredGroups(Groups, ByName[Name], "name:" .. Name) end

    local function Apply(Overrides)
        if type(Overrides) ~= "table" then return end
        for Key, Value in pairs(Overrides) do
            local Current = ActiveOverride(Value)
            if Current == false and Key ~= "member" then
                Groups[Key] = nil
            elseif type(Current) == "string" then
                Groups[Key] = Current
            end
        end
    end
    if Id then Apply(Session.GroupsById[Id]) end
    if Name then Apply(Session.GroupsByName[Name]) end
    return Groups
end

local function SortedGroups(Groups)
    local Keys = {}
    for Key in pairs(Groups) do Keys[#Keys + 1] = Key end
    table.sort(Keys, function(A, B)
        local RankA, RankB = Ranks[A] or math.huge, Ranks[B] or math.huge
        if RankA ~= RankB then return RankA < RankB end
        return A < B
    end)
    local Result = {}
    for Index, Key in ipairs(Keys) do Result[Index] = Groups[Key] end
    return Result
end

for Id in pairs(ById) do
    GetAllowed(Id, nil)
    GetGroups(Id, nil)
end
for Name in pairs(ByName) do
    GetAllowed(nil, Name)
    GetGroups(nil, Name)
end

local function HasProtectedConfiguredRole(Id, Name)
    local Configured = {}
    if Id then AddConfiguredGroups(Configured, ById[Id], "id:" .. Id) end
    if Name then AddConfiguredGroups(Configured, ByName[Name], "name:" .. Name) end
    return Configured.owner ~= nil or Configured.admin ~= nil
end

local function HasUnknownIdentity(Id, Name)
    if Id and not Name and next(ByName) ~= nil then return true end
    if Name and not Id and next(ById) ~= nil then return true end
    return false
end

local function Can(Act, TargetId, TargetName, DesiredGroup)
    local CallerId, CallerName = ResolvePlayer(Players.LocalPlayer)
    if not GetAllowed(CallerId, CallerName) then return false end

    local Own = GetGroups(CallerId, CallerName)
    if Act == "Hub" then return true end
    if Act == "AdminHub" then
        return Own.owner ~= nil or Own.admin ~= nil or Own.vip ~= nil
    end
    if Act ~= "ManageWhitelist" and Act ~= "ManageGroups" then return false end
    if not TargetId and not TargetName then return false end
    if Own.owner then return true end
    if not Own.admin then return false end

    if HasUnknownIdentity(TargetId, TargetName) then return false end
    local Target = GetGroups(TargetId, TargetName)
    if Target.owner or Target.admin or HasProtectedConfiguredRole(TargetId, TargetName) then
        return false
    end
    if DesiredGroup then
        local Key = NormalizeGroup(DesiredGroup)
        if Key == "owner" or Key == "admin" then return false end
    end
    return true
end

local function GetLocalAccess()
    local Id, Name = ResolvePlayer(Players.LocalPlayer)
    return GetAllowed(Id, Name)
end

local Manager = {}

local function Refresh(Reason)
    if Destroyed then return end
    if OnAccessLost and not GetLocalAccess() then
        if CurrentTimer then
            pcall(task.cancel, CurrentTimer)
            CurrentTimer = nil
        end
        local Callback = OnAccessLost
        OnAccessLost = nil
        Callback(Reason or "expired")
        return
    end
    Manager:_Schedule()
end

function Manager:_Schedule()
    if Destroyed or not OnAccessLost then return end
    if CurrentTimer then
        pcall(task.cancel, CurrentTimer)
        CurrentTimer = nil
    end
    local Id, Name = ResolvePlayer(Players.LocalPlayer)
    GetAllowed(Id, Name)
    GetGroups(Id, Name)

    local Soonest, Now = nil, os.time()
    local function Consider(Deadline)
        if type(Deadline) == "number" and Deadline > Now then
            Soonest = Soonest and math.min(Soonest, Deadline) or Deadline
        end
    end
    if Id then
        for Key, Deadline in pairs(Session.Expirations) do
            if type(Key) == "string" and (Key:sub(1, #("id:" .. Id .. ":")) == "id:" .. Id .. ":") then
                Consider(Deadline)
            end
        end
    end
    if Name then
        for Key, Deadline in pairs(Session.Expirations) do
            if type(Key) == "string" and (Key:sub(1, #("name:" .. Name .. ":")) == "name:" .. Name .. ":") then
                Consider(Deadline)
            end
        end
    end
    local function ConsiderOverride(Value)
        if type(Value) == "table" then Consider(Value.ExpiresAt) end
    end
    if Id then ConsiderOverride(Session.ById[Id]) end
    if Name then ConsiderOverride(Session.ByName[Name]) end
    local function ConsiderGroups(Overrides)
        if type(Overrides) == "table" then
            for _, Value in pairs(Overrides) do ConsiderOverride(Value) end
        end
    end
    if Id then ConsiderGroups(Session.GroupsById[Id]) end
    if Name then ConsiderGroups(Session.GroupsByName[Name]) end

    if Soonest then
        CurrentTimer = task.delay(math.min(86400, math.max(0, Soonest - Now)), function()
            CurrentTimer = nil
            Refresh()
        end)
    end
end

function Manager:ObserveAccess(Callback)
    if type(Callback) ~= "function" or Destroyed then return false end
    OnAccessLost = Callback
    Refresh()
    return true
end

function Manager:Destroy()
    Destroyed = true
    OnAccessLost = nil
    if CurrentTimer then
        pcall(task.cancel, CurrentTimer)
        CurrentTimer = nil
    end
end

function Manager:Whitelist(Input)
    local Id, Name = ResolvePlayer(Input)
    if not Id and not Name then return false end
    return GetAllowed(Id, Name)
end

function Manager:Group(Input, Group)
    local Id, Name = ResolvePlayer(Input)
    local Groups = GetGroups(Id, Name)
    if Group ~= nil then
        local Key = NormalizeGroup(Group)
        return Key ~= nil and Groups[Key] ~= nil
    end
    return SortedGroups(Groups)
end

function Manager:Permission(Action, Target, Group)
    if type(Action) ~= "string" then return false end
    local Id, Name = ResolvePlayer(Target)
    return Can(Action, Id, Name, Group)
end

function Manager:CanManage(Input)
    return self:Permission("ManageWhitelist", Input)
end

function Manager:HasAdminHub()
    return self:Permission("AdminHub")
end

function Manager:CanAccessAdminHub()
    return self:Permission("AdminHub")
end

local function SetWhitelist(Input, Allowed, Time)
    local Id, Name = ResolvePlayer(Input)
    if not Id and not Name then return false, "Invalid player" end
    if not Can("ManageWhitelist", Id, Name) then return false, "Permission denied" end
    local Deadline, Valid = ParseTime(Time)
    if not Valid then return false, "Invalid Time" end
    local Value
    if Allowed ~= nil then
        Value = Time == nil and Allowed or {Value = Allowed, ExpiresAt = Deadline}
    end
    if Id then Session.ById[Id] = Value end
    if Name then Session.ByName[Name] = Value end
    Refresh(Allowed == false and "revoked" or "changed")
    return true
end

function Manager:AddWhitelist(Input, Time)
    return SetWhitelist(Input, true, Time)
end

function Manager:RemoveWhitelist(Input, Time)
    return SetWhitelist(Input, false, Time)
end

function Manager:ResetWhitelist(Input)
    return SetWhitelist(Input, nil)
end

local function SetGroup(Input, Group, Enabled, Time)
    local Key, Label = NormalizeGroup(Group)
    if not Key then return false, "Invalid group" end
    local Id, Name = ResolvePlayer(Input)
    if not Id and not Name then return false, "Invalid player" end
    if not Can("ManageGroups", Id, Name, Group) then return false, "Permission denied" end
    local Deadline, Valid = ParseTime(Time)
    if not Valid then return false, "Invalid Time" end
    local Value = Time == nil and (Enabled and Label or false) or {Value = Enabled and Label or false, ExpiresAt = Deadline}
    local function Apply(Store, Identity)
        if not Identity then return end
        Store[Identity] = type(Store[Identity]) == "table" and Store[Identity] or {}
        Store[Identity][Key] = Value
    end
    Apply(Session.GroupsById, Id)
    Apply(Session.GroupsByName, Name)
    Refresh("changed")
    return true
end

function Manager:AddGroup(Input, Group, Time)
    return SetGroup(Input, Group, true, Time)
end

function Manager:RemoveGroup(Input, Group, Time)
    return SetGroup(Input, Group, false, Time)
end

function Manager:ResetGroups(Input)
    local Id, Name = ResolvePlayer(Input)
    if not Id and not Name then return false, "Invalid player" end
    if not Can("ManageGroups", Id, Name) then return false, "Permission denied" end
    if Id then Session.GroupsById[Id] = nil end
    if Name then Session.GroupsByName[Name] = nil end
    Refresh("changed")
    return true
end

function Manager:WhitelistInfo(Input)
    local Id, Name = ResolvePlayer(Input)
    return {
        UserId = Id,
        Username = Name,
        Whitelisted = (Id ~= nil or Name ~= nil) and GetAllowed(Id, Name) or false,
        Groups = SortedGroups(GetGroups(Id, Name)),
        CanManage = Can("ManageWhitelist", Id, Name),
        AdminHub = (Id ~= nil or Name ~= nil) and GetAllowed(Id, Name)
            and (function()
                local Groups = GetGroups(Id, Name)
                return Groups.owner ~= nil or Groups.admin ~= nil or Groups.vip ~= nil
            end)() or false
    }
end

return Manager
