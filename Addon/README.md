# SpecterX Addon

O SpecterX usa o diretório local `SpecterX/Addon/` do executor. Na primeira execução, o carregador cria a pasta e os três arquivos, copiando os modelos de `Addon/` do repositório.

Os arquivos existentes **não são sobrescritos**. Edite os arquivos no executor e execute `base.lua` novamente para carregar as alterações. Cada arquivo deve retornar uma tabela Lua. Caso um addon tenha erro, os demais continuam carregando. A pasta exige suporte a leitura e escrita de arquivos do ambiente de execução.

## theme.lua

Os temas aparecem em **Configurações → Tema**. `Base` é opcional; pode apontar para um tema nativo. As cores omitidas são herdadas do tema base. Os campos disponíveis são `Color Hub 1` (ColorSequence), `Color Hub 2`, `Color Stroke`, `Color Theme`, `Color Text` e `Color Dark Text` (Color3).

```lua
return {
    MyBlue = {
        Base = "MetalRed",
        ["Color Hub 1"] = ColorSequence.new(Color3.fromRGB(15, 25, 42)),
        ["Color Hub 2"] = Color3.fromRGB(18, 29, 48),
        ["Color Stroke"] = Color3.fromRGB(42, 87, 155),
        ["Color Theme"] = Color3.fromRGB(60, 145, 255),
        ["Color Text"] = Color3.fromRGB(235, 241, 255),
        ["Color Dark Text"] = Color3.fromRGB(160, 178, 208)
    }
}
```

## language.lua

Os idiomas aparecem em **Configurações → Idioma**. Chaves de `Translations` são os textos originais em inglês, iguais aos usados em `Core/translation.lua`. Chaves não traduzidas permanecem com o texto original. Também é possível adicionar ou sobrescrever traduções de `US`, `BR` e `ES`.

```lua
return {
    FR = {
        Name = "Français",
        Translations = {
            ["Settings"] = "Paramètres",
            ["Theme"] = "Thème",
            ["Language"] = "Langue",
            ["Audio"] = "Audio",
            ["UI sounds"] = "Sons de l'interface"
        }
    }
}
```

Também funciona a forma `return {FR = {["Settings"] = "Paramètres"}}`; o nome exibido será `FR`.

## sound.lua

Os sons aparecem em **Configurações → Áudio → Som da interface**. Use IDs de áudio Roblox acessíveis ao jogo. O som deve estar habilitado em Configurações para os cliques tocarem. IDs e nomes iguais aos de um preset existente substituem esse preset; novos valores são adicionados.

```lua
return {
    {Name = "Meu clique", Id = 9120132783},
    {Name = "Outro clique", SoundId = "rbxassetid://9126042506"}
}
```

Esses IDs são exemplos já presentes nos presets nativos e, portanto, substituem seus nomes se utilizados.

## Integração

- `base.lua` inicializa o módulo `Core/Modules/Hub/Addon/script.lua` antes de ler preferências e criar a biblioteca.
- Temas entram em `Config.Themes`, traduções entram no módulo do Hub e sons entram em `Config.Library.Audio.Presets`.
- `Base.Addons.Themes`, `Base.Addons.Languages` e `Base.Addons.Sounds` contêm os nomes carregados na inicialização.
- As configurações salvas de tema, idioma e som continuam utilizando `SpecterX/Library/settings.json`.

Somente execute arquivos de addon escritos por você ou por fontes confiáveis: eles são código Lua executável.
