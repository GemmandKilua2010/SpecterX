--// Games

local Games = {}

--// Functions

local function AddGame(Name, Ids)
    for _, Id in ipairs(Ids) do
        Games[Id] = Name
    end
end

--// Register

AddGame("Blade Ball", {
    13772394625,
    4777817887
})

AddGame("Blox Fruits", {
    2753915549,
    994732206
})

AddGame("Brookhaven", {
    4924922222,
    1686885941
})

AddGame("Murder Mystery 2", {
    142823291,
    66654135
})

--// Return

return Games
