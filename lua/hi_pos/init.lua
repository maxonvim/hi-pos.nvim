local M = {}

local namespace = vim.api.nvim_create_namespace("hi_pos")
local augroup = vim.api.nvim_create_augroup("hi_pos", { clear = true })
local setup_augroup = vim.api.nvim_create_augroup("hi_pos_setup", { clear = true })

local default_highlight = {
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
}

local defaults = {
  command = { "node" },
  debounce_ms = 250,
  disable_uppercase_filenames = true,
  filetypes = { "markdown", "text", "gitcommit" },
  markdown = {
    include = {
      paragraphs = true,
      lists = true,
      blockquotes = false,
      headings = false,
    },
  },
  max_buffer_size = 200000,
  highlight = default_highlight,
}

local config = vim.deepcopy(defaults)
local buffers = {}

local function current_buffer(bufnr)
  if bufnr == nil or bufnr == 0 then
    return vim.api.nvim_get_current_buf()
  end

  return bufnr
end

local function assert_valid_buffer(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    error("hi_pos: invalid buffer " .. tostring(bufnr), 3)
  end
end

local function plugin_root()
  local source = debug.getinfo(1, "S").source:sub(2)
  return vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(source)))
end

local function script_path()
  return vim.fs.joinpath(plugin_root(), "bin", "hi-pos.js")
end

local function has_uppercase_stem(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)

  if name == "" then
    return false
  end

  local filename = vim.fs.basename(name)
  local stem = filename:match("^(.+)%.[^.]+$") or filename

  return stem:find("%a") ~= nil and stem == stem:upper()
end

local function is_disabled_for_buffer(bufnr)
  return config.disable_uppercase_filenames == true and has_uppercase_stem(bufnr)
end

local function buffer_text(bufnr)
  return table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
end

local function clear(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
end

local function group_for(tag)
  return config.highlight[tag]
end

local function is_table_line(line, next_line)
  if not line:find("|") then
    return false
  end

  if line:match("^%s*|") or line:match("|%s*$") then
    return true
  end

  return next_line ~= nil and next_line:match("^%s*|?%s*:?-+:?%s*|[%s|:%-]*$") ~= nil
end

local function markdown_allowed_lines(lines)
  local allowed = {}
  local include = ((config.markdown or {}).include) or {}
  local in_fence = false
  local in_frontmatter = lines[1] ~= nil and lines[1]:match("^%-%-%-%s*$") ~= nil

  for index, line in ipairs(lines) do
    local row = index - 1
    local next_line = lines[index + 1]
    local fence = line:match("^%s*(```+)") or line:match("^%s*(~~~+)")

    if in_frontmatter then
      if index > 1 and (line:match("^%-%-%-%s*$") or line:match("^%.%.%.%s*$")) then
        in_frontmatter = false
      end
    elseif fence ~= nil then
      in_fence = not in_fence
    elseif not in_fence and not line:match("^%s*$") then
      local is_atx_heading = line:match("^%s*#+%s+") ~= nil
      local is_setext_heading = next_line ~= nil and (next_line:match("^%s*=+%s*$") or next_line:match("^%s*%-%-+%s*$")) ~= nil
      local is_setext_underline = line:match("^%s*=+%s*$") ~= nil or line:match("^%s*%-%-+%s*$") ~= nil
      local is_blockquote = line:match("^%s*>") ~= nil
      local is_list = line:match("^%s*[%*%+%-]%s+") ~= nil or line:match("^%s*%d+[%)%.]%s+") ~= nil
      local is_table = is_table_line(line, next_line)
      local is_html = line:match("^%s*</?[%a][%w:-]*") ~= nil or line:match("^%s*<!%-%-") ~= nil
      local is_thematic_break = line:match("^%s*([%*_%-%s])%s*$") ~= nil and #line:gsub("%s", "") >= 3

      allowed[row] = (include.headings and (is_atx_heading or is_setext_heading))
        or (include.blockquotes and is_blockquote)
        or (include.lists and is_list)
        or (include.paragraphs and not is_atx_heading and not is_setext_heading and not is_setext_underline and not is_blockquote and not is_list and not is_table and not is_html and not is_thematic_break)
    end
  end

  return allowed
end

local function allowed_lines(bufnr)
  if vim.bo[bufnr].filetype ~= "markdown" then
    return nil
  end

  return markdown_allowed_lines(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
end

local function apply_ranges(bufnr, ranges)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  clear(bufnr)

  local allowed = allowed_lines(bufnr)

  for _, range in ipairs(ranges) do
    local group = group_for(range.tag)

    if group ~= nil and (allowed == nil or allowed[range.start_row]) then
      pcall(vim.api.nvim_buf_set_extmark, bufnr, namespace, range.start_row, range.start_col, {
        end_row = range.end_row,
        end_col = range.end_col,
        hl_group = group,
        priority = 120,
      })
    end
  end
end

local function notify_error(message)
  vim.schedule(function()
    vim.notify(message, vim.log.levels.ERROR, { title = "hi_pos" })
  end)
end

local function command()
  local cmd = vim.deepcopy(config.command)
  table.insert(cmd, script_path())
  return cmd
end

local function run(bufnr)
  local state = buffers[bufnr]

  if state == nil or state.enabled ~= true or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  if is_disabled_for_buffer(bufnr) then
    state.enabled = false
    clear(bufnr)
    return
  end

  local text = buffer_text(bufnr)

  if #text > config.max_buffer_size then
    clear(bufnr)
    notify_error("buffer is larger than max_buffer_size")
    return
  end

  state.generation = state.generation + 1
  local generation = state.generation

  vim.system(command(), { stdin = text, text = true }, function(result)
    vim.schedule(function()
      local latest = buffers[bufnr]

      if latest == nil or latest.enabled ~= true or latest.generation ~= generation then
        return
      end

      if result.code ~= 0 then
        notify_error(vim.trim(result.stderr ~= "" and result.stderr or "compromise helper failed"))
        return
      end

      local ok, ranges = pcall(vim.json.decode, result.stdout)

      if not ok or type(ranges) ~= "table" then
        notify_error("compromise helper returned invalid JSON")
        return
      end

      apply_ranges(bufnr, ranges)
    end)
  end)
end

local function schedule(bufnr)
  local state = buffers[bufnr]

  if state == nil or state.enabled ~= true then
    return
  end

  if state.timer ~= nil then
    state.timer:stop()
  end

  state.timer = vim.defer_fn(function()
    run(bufnr)
  end, config.debounce_ms)
end

local function create_autocmds(bufnr)
  vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufEnter" }, {
    group = augroup,
    buffer = bufnr,
    callback = function()
      schedule(bufnr)
    end,
  })

  vim.api.nvim_create_autocmd({ "BufWipeout", "BufDelete" }, {
    group = augroup,
    buffer = bufnr,
    callback = function()
      buffers[bufnr] = nil
    end,
  })
end

function M.start(bufnr)
  bufnr = current_buffer(bufnr)
  assert_valid_buffer(bufnr)

  if is_disabled_for_buffer(bufnr) then
    clear(bufnr)
    return M
  end

  buffers[bufnr] = buffers[bufnr] or {
    enabled = false,
    generation = 0,
  }

  buffers[bufnr].enabled = true
  create_autocmds(bufnr)
  schedule(bufnr)

  return M
end

function M.stop(bufnr)
  bufnr = current_buffer(bufnr)
  assert_valid_buffer(bufnr)

  local state = buffers[bufnr]

  if state ~= nil and state.timer ~= nil then
    state.timer:stop()
  end

  buffers[bufnr] = nil
  vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
  clear(bufnr)

  return M
end

function M.toggle(bufnr)
  bufnr = current_buffer(bufnr)
  assert_valid_buffer(bufnr)

  if M.is_running(bufnr) then
    return M.stop(bufnr)
  end

  return M.start(bufnr)
end

function M.refresh(bufnr)
  bufnr = current_buffer(bufnr)
  assert_valid_buffer(bufnr)
  run(bufnr)

  return M
end

function M.is_running(bufnr)
  bufnr = current_buffer(bufnr)
  assert_valid_buffer(bufnr)

  local state = buffers[bufnr]
  return state ~= nil and state.enabled == true
end

function M.setup(opts)
  config = vim.tbl_deep_extend("force", defaults, opts or {})
  vim.api.nvim_clear_autocmds({ group = setup_augroup })

  if type(config.filetypes) == "table" and #config.filetypes > 0 then
    vim.api.nvim_create_autocmd("FileType", {
      group = setup_augroup,
      pattern = config.filetypes,
      callback = function(event)
        M.start(event.buf)
      end,
    })
  end

  return {
    start = M.start,
    stop = M.stop,
    toggle = M.toggle,
    refresh = M.refresh,
    is_running = M.is_running,
  }
end

M.default_highlight = vim.deepcopy(default_highlight)
M.defaults = vim.deepcopy(defaults)

return M
