# hi-pos.nvim

Natural language part-of-speech highlighting for Neovim, powered by
[Compromise](https://github.com/spencermountain/compromise).

Inspired by the Obsidian plugin
[Natural Language Syntax Highlighting](https://community.obsidian.md/plugins/nl-syntax-highlighting).

## Requirements

- Neovim 0.10+
- Node.js

## Installation

With `lazy.nvim`:

```lua
{
  "maxonvim/hi-pos.nvim",
  config = function()
    local pos = require("hi_pos").setup()

    vim.keymap.set("n", "<leader>ps", pos.start, { desc = "Start POS highlighting" })
    vim.keymap.set("n", "<leader>pS", pos.stop, { desc = "Stop POS highlighting" })
    vim.keymap.set("n", "<leader>pt", pos.toggle, { desc = "Toggle POS highlighting" })
  end,
}
```

## API

```lua
local pos = require("hi_pos").setup({
  debounce_ms = 250,
  disable_uppercase_filenames = true,
  max_buffer_size = 200000,
  filetypes = { "markdown", "text", "gitcommit" },
  markdown = {
    include = {
      paragraphs = true,
      lists = true,
      blockquotes = false,
      headings = false,
    },
  },
  highlight = {
    Noun = "Identifier",
    Verb = "Statement",
    Adjective = "Type",
    Adverb = "PreProc",
    Preposition = "Operator",
    Conjunction = "Conditional",
    Determiner = "Comment",
    Pronoun = "Special",
    Value = "Number",
    QuestionWord = "Question",
    Expression = "String",
    Url = "Underlined",
    HashTag = "Tag",
    AtMention = "Tag",
  },
})

pos.start()      -- current buffer
pos.stop()       -- current buffer
pos.toggle()     -- current buffer
pos.refresh()    -- rerun compromise for current buffer
pos.is_running() -- current buffer
```

`filetypes` defaults to `{ "markdown", "text", "gitcommit" }` and controls
auto-start only. Set `filetypes = false` or `filetypes = {}` to disable
auto-start. Manual `pos.start()` still works for any buffer.

`disable_uppercase_filenames` defaults to `true`, so files like `README.md`,
`CHANGELOG.md`, and `LICENSE` are ignored. Set it to `false` to highlight those
files too.

Markdown uses a whitelist. By default, only paragraph lines and list item lines
are highlighted. Code fences, frontmatter, tables, HTML blocks, thematic breaks,
headings, and blockquotes are not highlighted.

Enable headings or blockquotes with:

```lua
require("hi_pos").setup({
  markdown = {
    include = {
      headings = true,
      blockquotes = true,
    },
  },
})
```

Each method accepts an optional buffer number:

```lua
pos.start(7)
```

## Highlight Groups

The plugin maps compromise tags to existing highlight groups by default:

```lua
{
  Noun = "Identifier",
  Verb = "Statement",
  Adjective = "Type",
  Adverb = "PreProc",
  Preposition = "Operator",
  Conjunction = "Conditional",
  Determiner = "Comment",
  Pronoun = "Special",
  Value = "Number",
}
```

Override any tag by passing `highlight` to `setup`. The full default map is also
available as:

```lua
require("hi_pos").default_highlight
```

## Contributing/Development

Any contributions are welcome!

The runtime helper in `bin/hi-pos.js` is bundled and committed, so users do not
need `npm install`.

To rebuild it after changing `js/hi-pos.js`:

```sh
npm install
npm run build
```
