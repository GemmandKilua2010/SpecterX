local ImageID = 94800455817009
local Config = {
    Title = "SpecterX",
    SubTitle = "By Specter",

    Icon = {
        Image = ImageID,
        Transparency = 0,
        Corner = 5
    },

    DiscordInvite = {
        Name = "Discord",
        Desc = "Entre no nosso Discord e acompanhe todas as atualizações do SpecterX.",
        
        Logo = ImageID,
        Invite = "Em Breve!",
        
        RPC = false
    }
}

Config.DiscordInvite.Name = Config.Title
return Config
