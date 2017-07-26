-- Copyright 2017 Jens Remus jens.remus@gmail.com. See LICENSE.
-- Copyright 2007-2017 Mitchell mitchell.att.foicica.com. See LICENSE.

--[[ This comment is for LuaDoc.
---
-- Utilize Cscope with Textadept. Based on Mitchell's Ctags module for Textadept.
--
-- There are four ways to tell Textadept about *cscope.out* files:
--
--   1. Place a *cscope.out* file in current file's directory. This file will be
--      used in a search from any file in that directory.
--   2. Place a *cscope.out* file in a project's root directory. This file will
--      be used in a search from any of that project's source files.
--   3. Add a *cscope.out* file or list of *cscope.out* files to the `_M.cscope`
--      table for a project root key. This file(s) will be used in a search from
--      any of that project's source files.
--      For example: `_M.cscope['/path/to/project'] = '/path/to/cscope.out'`.
--   4. Add a *cscope.out* file to the `_M.cscope` table. This file will be used
--      in any search.
--      For example: `_M.cscope[#_M.cscope + 1] = '/path/to/cscope.out'`.
--
-- Textadept will use any and all *cscope.out* files based on the above rules.
module('_M.cscope')]]

local M = {}

-- Default Cscope executable.
M.CSCOPE = 'cscope'

-- Searches all available *cscope.out* files for *tag* and returns a table of
-- tags found.
-- @param tag Tag to find.
-- @return table of tags found with each entry being a table that contains the
--   location, file path and name, line number, and line content.
local function find_tags(tag)
  local tags = {}
  local patt = '^([^ ]*) ([^ ]+) ([0-9]+) (.*)$'
  -- Determine the cscope files to search in.
  local cscope_files = {}
  local cscope_file = ((buffer.filename or ''):match('^.+[/\\]') or
                      lfs.currentdir()..'/')..'cscope.out' -- current directory's Cscope file
  if lfs.attributes(cscope_file) then cscope_files[#cscope_files + 1] = cscope_file end
  if buffer.filename then
    local root = io.get_project_root(buffer.filename)
    if root then
      cscope_file = root..'/cscope.out' -- project's Cscope file
      if lfs.attributes(cscope_file) then cscope_files[#cscope_files + 1] = cscope_file end
      cscope_file = M[root] -- project's specified Cscope file(s)
      if type(cscope_file) == 'string' then
        cscope_files[#cscope_files + 1] = cscope_file
      elseif type(cscope_file) == 'table' then
        for i = 1, #cscope_file do cscope_files[#cscope_files + 1] = cscope_file[i] end
      end
    end
  end
  for i = 1, #M do cscope_files[#cscope_files + 1] = M[i] end -- global Cscope files
  -- Search all Cscope files for matches.
  for i = 1, #cscope_files do
    local dir = cscope_files[i]:match('^.+[/\\]')
    local p = spawn(M.CSCOPE..' -dLf "'..cscope_files[i]..'" -0 "'..tag..'"')
    local line = p:read()
    while (line) do
      local file, location, line_number, content = line:match(patt)
      if not file:find('^%a?:?[/\\]') then file = dir..file end
      tags[#tags + 1] = {location, file, line_number, content}
      line = p:read()
    end
  end
  return tags
end

-- List of jump positions comprising a jump history.
-- Has a `pos` field that points to the current jump position.
-- @class table
-- @name jump_list
local jump_list = {pos = 0}
---
-- Jumps to the source of string *tag* or the source of the word under the
-- caret.
-- Prompts the user when multiple sources are found. If *tag* is `nil`, jumps to
-- the previous or next position in the jump history, depending on boolean
-- *prev*.
-- @param tag The tag to jump to the source of.
-- @param prev Optional flag indicating whether to go to the previous position
--   in the jump history or the next one. Only applicable when *tag* is `nil` or
--   `false`.
-- @see tags
-- @name goto_tag
function M.goto_tag(tag, prev)
  if not tag and prev == nil then
    local s = buffer:word_start_position(buffer.current_pos, true)
    local e = buffer:word_end_position(buffer.current_pos, true)
    tag = buffer:text_range(s, e)
  elseif not tag then
    -- Navigate within the jump history.
    if prev and jump_list.pos <= 1 then return end
    if not prev and jump_list.pos == #jump_list then return end
    jump_list.pos = jump_list.pos + (prev and -1 or 1)
    io.open_file(jump_list[jump_list.pos][1])
    buffer:goto_pos(jump_list[jump_list.pos][2])
    return
  end
  -- Search for potential tags to jump to.
  local tags = find_tags(tag)
  if #tags == 0 then return end
  -- Prompt the user to select a tag from multiple candidates or automatically
  -- pick the only one.
  if #tags > 1 then
    local items = {}
    for i = 1, #tags do
      items[#items + 1] = tags[i][1]
--      items[#items + 1] = tags[i][2]:match('[^/\\]+$') -- filename only
      items[#items + 1] = tags[i][2]
      items[#items + 1] = tags[i][3]
      items[#items + 1] = tags[i][4]
    end
    local button, i = ui.dialogs.filteredlist{
      title = _L['Go To'],
      columns = {_L['Name'], _L['File'], _L['Line:'], 'Extra Information'},
      items = items, search_column = 2, width = CURSES and ui.size[1] - 2 or nil
    }
    if button < 1 then return end
    tag = tags[i]
  else
    tag = tags[1]
  end
  -- Store the current position in the jump history if applicable, clearing any
  -- jump history positions beyond the current one.
  if jump_list.pos < #jump_list then
    for i = jump_list.pos + 1, #jump_list do jump_list[i] = nil end
  end
  if jump_list.pos == 0 or jump_list[#jump_list][1] ~= buffer.filename or
     jump_list[#jump_list][2] ~= buffer.current_pos then
    jump_list[#jump_list + 1] = {buffer.filename, buffer.current_pos}
  end
  -- Jump to the tag.
  io.open_file(tag[2])
  textadept.editing.goto_line(tonumber(tag[3]) - 1)
  -- Store the new position in the jump history.
  jump_list[#jump_list + 1] = {buffer.filename, buffer.current_pos}
  jump_list.pos = #jump_list
end

-- Add menu entries.
local m_search = textadept.menu.menubar[_L['_Search']]
m_search[#m_search + 1] = {''} -- separator
m_search[#m_search + 1] = {
  title = '_Cscope',
  {'_Goto', M.goto_tag},
  {'G_oto...', function()
    local button, name = ui.dialogs.standard_inputbox{title = 'Goto'}
    if button == 1 then _M.cscope.goto_tag(name) end
  end},
  {''},
  {'Jump _Back', function() M.goto_tag(nil, true) end},
  {'Jump _Forward', function() M.goto_tag(nil, false) end}
}

return M
