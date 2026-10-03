local Config = {
    Title = "SpecterX",
    SubTitle = "By Specter",

    LoadingScreen = false,
    Image = 121730327067473,

    Icon = {
        Transparency = 0,
        Corner = 5
    },

    DiscordInvite = {
        Name = "Discord",
        Desc = "Join our Discord and keep up with all SpecterX updates.",

        Invite = "Coming soon"
    }
}

--// Configs

Config.Icon.Image = Config.Image
Config.DiscordInvite.Name, Config.DiscordInvite.Image = Config.Title, Config.Image

return Config
