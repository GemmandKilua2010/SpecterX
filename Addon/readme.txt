SPECTERX - ADDON GUIDE / GUIA DE ADDONS / GUÍA DE ADDONS

======================== ENGLISH ========================

Customize SpecterX with your own themes, languages, and UI sounds.

FILES
SpecterX/Addon/theme.lua
SpecterX/Addon/language.lua
SpecterX/Addon/sound.lua

1. CUSTOM THEMES - theme.lua
Each theme name appears in Settings > Theme. Base uses colors from
an existing theme; you only need to change the colors you want.

Example (two themes in one file):

return {
    MyTheme = {
        Base = "Dark",
        ["Color Hub 1"] = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(12, 16, 32)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(27, 38, 65))
        }),
        ["Color Theme"] = Color3.fromRGB(65, 145, 255),
        ["Color Text"] = Color3.fromRGB(245, 248, 255)
    },
    MyThemeBlue = {
        Base = "Dark",
        ["Color Theme"] = Color3.fromRGB(40, 170, 255)
    }
}

Change MyTheme/MyThemeBlue to the names you prefer. "Color Hub 1"
uses ColorSequence; other color fields use Color3.

2. CUSTOM LANGUAGES - language.lua
Change an existing language or add a new option in Settings > Language.

Example A (customize Brazilian Portuguese):

return {
    BR = {
        Name = "Português (Brasil)",
        Translations = {
            ["Settings"] = "Meus ajustes",
            ["Theme"] = "Meu tema",
            ["Audio"] = "Meu áudio"
        }
    }
}

Example B (create a separate language option):

return {
    MYLANGUAGE = {
        Name = "MyLanguage",
        Translations = {
            ["Settings"] = "My Settings",
            ["Theme"] = "My Theme",
            ["Language"] = "My Language"
        }
    }
}

Use one example at a time, or combine both inside the same return table.
Text keys must match the original SpecterX text. Keep placeholders
such as {Theme} unchanged. Missing translations remain unchanged.

3. CUSTOM UI SOUNDS - sound.lua
Add multiple sound options in Settings > Audio.

Example:

return {
    { Name = "MySound", Id = 1234567890 },
    { Name = "MySound2", SoundId = "rbxassetid://9876543210" }
}

Replace the example IDs with Roblox audio IDs available to your game.
Enable UI Sounds and select your sound under UI Sound.

HOW TO APPLY
Edit the desired file, save it, then reopen SpecterX. Select your
new theme, language, or sound in Settings. Each file must contain one
return { ... } table. You can include multiple entries in that table.
Only theme.lua, language.lua, and sound.lua are supported.
Use addons only from sources you trust.

===================== PORTUGUÊS (PT-BR) =====================

Personalize o SpecterX com seus próprios temas, idiomas e sons da interface.

ARQUIVOS
SpecterX/Addon/theme.lua
SpecterX/Addon/language.lua
SpecterX/Addon/sound.lua

1. TEMAS PERSONALIZADOS - theme.lua
Cada tema aparece em Configurações > Tema. Base aproveita as cores de
um tema existente; você só precisa alterar as cores que desejar.

Exemplo (dois temas no mesmo arquivo):

return {
    MyTheme = {
        Base = "Dark",
        ["Color Hub 1"] = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(12, 16, 32)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(27, 38, 65))
        }),
        ["Color Theme"] = Color3.fromRGB(65, 145, 255),
        ["Color Text"] = Color3.fromRGB(245, 248, 255)
    },
    MyThemeBlue = {
        Base = "Dark",
        ["Color Theme"] = Color3.fromRGB(40, 170, 255)
    }
}

Troque MyTheme/MyThemeBlue pelos nomes que quiser. "Color Hub 1"
usa ColorSequence; os demais campos de cor usam Color3.

2. IDIOMAS PERSONALIZADOS - language.lua
Altere um idioma existente ou adicione outro em Configurações > Idioma.

Exemplo A (personalizar o português do Brasil):

return {
    BR = {
        Name = "Português (Brasil)",
        Translations = {
            ["Settings"] = "Meus ajustes",
            ["Theme"] = "Meu tema",
            ["Audio"] = "Meu áudio"
        }
    }
}

Exemplo B (criar uma opção de idioma separada):

return {
    MYLANGUAGE = {
        Name = "MyLanguage",
        Translations = {
            ["Settings"] = "Minhas configurações",
            ["Theme"] = "Meu tema",
            ["Language"] = "Meu idioma"
        }
    }
}

Use um exemplo por vez ou junte os dois dentro do mesmo return.
As chaves devem ser iguais aos textos originais do SpecterX. Preserve
marcadores como {Theme}. Traduções ausentes ficam inalteradas.

3. SONS PERSONALIZADOS - sound.lua
Adicione várias opções de som em Configurações > Áudio.

Exemplo:

return {
    { Name = "MySound", Id = 1234567890 },
    { Name = "MySound2", SoundId = "rbxassetid://9876543210" }
}

Substitua os IDs de exemplo por áudios do Roblox permitidos no jogo.
Ative Sons da interface e escolha o som em Som da interface.

COMO APLICAR
Edite o arquivo desejado, salve e abra o SpecterX novamente. Depois,
escolha o tema, idioma ou som em Configurações. Cada arquivo deve ter
um único return { ... }, que pode conter vários itens.
Somente theme.lua, language.lua e sound.lua são aceitos.
Use addons apenas de fontes confiáveis.

======================== ESPAÑOL ========================

Personaliza SpecterX con tus propios temas, idiomas y sonidos de interfaz.

ARCHIVOS
SpecterX/Addon/theme.lua
SpecterX/Addon/language.lua
SpecterX/Addon/sound.lua

1. TEMAS PERSONALIZADOS - theme.lua
Cada tema aparece en Configuración > Tema. Base hereda los colores de
un tema existente; solo cambia los colores que quieras.

Ejemplo (dos temas en un mismo archivo):

return {
    MyTheme = {
        Base = "Dark",
        ["Color Hub 1"] = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(12, 16, 32)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(27, 38, 65))
        }),
        ["Color Theme"] = Color3.fromRGB(65, 145, 255),
        ["Color Text"] = Color3.fromRGB(245, 248, 255)
    },
    MyThemeBlue = {
        Base = "Dark",
        ["Color Theme"] = Color3.fromRGB(40, 170, 255)
    }
}

Cambia MyTheme/MyThemeBlue por los nombres que prefieras. "Color Hub 1"
usa ColorSequence; los demás campos de color usan Color3.

2. IDIOMAS PERSONALIZADOS - language.lua
Modifica un idioma o añade otro en Configuración > Idioma.

Ejemplo A (personalizar el portugués de Brasil):

return {
    BR = {
        Name = "Português (Brasil)",
        Translations = {
            ["Settings"] = "Mis ajustes",
            ["Theme"] = "Mi tema",
            ["Audio"] = "Mi audio"
        }
    }
}

Ejemplo B (crear una opción de idioma independiente):

return {
    MYLANGUAGE = {
        Name = "MiIdioma",
        Translations = {
            ["Settings"] = "Mis ajustes",
            ["Theme"] = "Mi tema",
            ["Language"] = "Mi idioma"
        }
    }
}

Usa un ejemplo a la vez o combina ambos en un solo return.
Las claves deben coincidir con los textos originales de SpecterX.
Conserva marcadores como {Theme}. Las traducciones ausentes no cambian.

3. SONIDOS PERSONALIZADOS - sound.lua
Añade varias opciones de sonido en Configuración > Audio.

Ejemplo:

return {
    { Name = "MySound", Id = 1234567890 },
    { Name = "MySound2", SoundId = "rbxassetid://9876543210" }
}

Sustituye los IDs de ejemplo por audios de Roblox permitidos en el juego.
Activa Sonidos de la interfaz y elige uno en Sonido de la interfaz.

CÓMO APLICAR
Edita el archivo, guarda los cambios y vuelve a abrir SpecterX.
Selecciona tu tema, idioma o sonido en Configuración. Cada archivo
debe tener un único return { ... }, que puede incluir varias entradas.
Solo se admiten theme.lua, language.lua y sound.lua.
Usa únicamente addons de fuentes confiables.
