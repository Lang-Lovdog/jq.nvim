local kmap = vim.keymap.set
local ucmd = vim.api.nvim_create_user_command

function buf_text(bufnr)
  if bufnr == nil then
    bufnr = vim.api.nvim_win_get_buf(0)
  end
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, vim.api.nvim_buf_line_count(bufnr), true)
  local text = ''
  for i, line in ipairs(lines) do
    text = text .. line .. '\n'
  end
  return text
end

function set_buf_text(text, bufnr,editfile,filter)
  if text == nil then
    return
  end

  if text:match('^jq:') and editfile then
    return
  end
  if text:match('^jq:') then
    text = text .. '\n in filter ' .. filter
  end
  
  if bufnr == nil then
    bufnr = vim.fn.bufnr('%')
  end

  if type(text) == 'string' then
    text = vim.fn.split(text, '\n')
  end

  vim.api.nvim_buf_set_lines(
    bufnr,
    0,
    -1,
    false,
    text
  )
end

function jq_filter(json_bufnr, jq_filter)
  -- spawn jq and pipe in json, returning the output text
  local modified = vim.bo[json_bufnr].modified
  local fname = vim.fn.bufname(json_bufnr)

  if (not modified) and fname ~= '' then
    -- the following should be faster as it lets jq read the file contents
    return vim.fn.system({ 'jq', jq_filter, fname })
  else
    local json = buf_text(json_bufnr)
    return vim.fn.system({ 'jq', jq_filter }, json)
  end
end

function Jq_command(horizontal,editfile)
  local splitcmd = 'vnew'
  local splitcmd2 = 'vnew'
  if horizontal == true then
    splitcmd = 'belowright new jq-filter'
    if editfile == true then
      splitcmd2 = splitcmd2 .. ' json-edit'
      --reduce to 1/4 of the height
      splitcmd = splitcmd .. ' | resize 13'
    end
  end

  local json_bufnr = vim.fn.bufnr()

  vim.cmd(splitcmd)
  vim.cmd'set filetype=conf'
  set_buf_text('# JQ filter: press <CR> to execute it (different queries should be separated by a blank line)\n\n.')
  vim.cmd'normal!G'
  local jq_bufnr = vim.fn.bufnr()
  local jq_winnr = vim.fn.bufwinid(jq_bufnr)

  vim.cmd(splitcmd2)
  vim.cmd'set filetype=json'
  local result_bufnr = vim.fn.bufnr()


  vim.fn.win_gotoid(jq_winnr)
  
  -- setup keybindig for bufdelete query buffer
  if vim.fn.maparg('<leader>bd', 'n') ~= '' then
    vim.keymap.del('n', '<leader>bd', { buffer = jq_bufnr })
  end
  kmap( 'n', '<leader>bd', function()
      vim.cmd('bdelete!')
    end,
    { buffer = jq_bufnr }
  )

  -- setup keybindig for saving edited json
  if editfile == true then
    -- setup keybinding for writing edited json
    if vim.fn.maparg('<C-s>', 'n') ~= '' then
      vim.keymap.del('n', '<C-s>', { buffer = jq_bufnr })
    end
    kmap( 'n', '<C-s>', function()
        -- go to json buffer and save
        vim.fn.win_gotoid(vim.fn.bufwinid(json_bufnr))
        vim.cmd'write'
        -- go back to jq buffer
        vim.fn.win_gotoid(jq_winnr)
      end,
      { buffer = jq_bufnr }
    )
    --setup keybinding for searching through jsonfly
    if vim.fn.maparg('<C-a>', 'n') ~= '' then
      vim.keymap.del('n', '<C-a>', { buffer = jq_bufnr })
    end
    kmap( 'n', '<C-a>', function()
        -- go to json buffer and save
        vim.fn.win_gotoid(vim.fn.bufwinid(json_bufnr))
        vim.cmd('Telescope jsonfly')
        -- go back to jq buffer
        --vim.fn.win_gotoid(jq_winnr)
    end,
    { buffer = jq_bufnr }
    )
    -- setup keybinding for undo
    if vim.fn.maparg('<leader>uu', 'n') ~= '' then
      vim.keymap.del('n', '<leader>uu', { buffer = jq_bufnr })
    end
    kmap( 'n', '<leader>uu', function()
        -- go to json buffer and save
        vim.fn.win_gotoid(vim.fn.bufwinid(json_bufnr))
        vim.cmd('undo')
        -- go back to jq buffer
        vim.fn.win_gotoid(jq_winnr)
    end,
    { buffer = jq_bufnr }
    )
    -- setup keybinding for redo
    if vim.fn.maparg('<leader>rr', 'n') ~= '' then
      vim.keymap.del('n', '<leader>rr', { buffer = jq_bufnr })
    end
    kmap( 'n', '<leader>rr', function()
        -- go to json buffer and save
        vim.fn.win_gotoid(vim.fn.bufwinid(json_bufnr))
        vim.cmd('redo')
        -- go back to jq buffer
        vim.fn.win_gotoid(jq_winnr)
    end,
    { buffer = jq_bufnr }
    )
    -- setup keybinding autocmd in the filter buffer:
    -- editing json
    if vim.fn.maparg('<CR>', 'n') ~= '' then
      vim.keymap.del('n', '<CR>', { buffer = jq_bufnr })
    end
    kmap( 'n', '<CR>', function()
        local filter = buf_text(jq_bufnr)
        -- Get filters separated by double newlines
        local filters = vim.fn.split(filter, '\n\n')
        for i, the_filter in ipairs(filters) do
          if the_filter:match('^#') then goto continue end
          if the_filter == '' then goto continue end -- skip empty lines in the filter buffer
          if the_filter == nil then goto continue end -- skip empty lines in the filter buffer
          set_buf_text(jq_filter(json_bufnr, the_filter), json_bufnr,true,the_filter)
          ::continue::
        end
        set_buf_text('# JQ filter: press <CR> to execute it\n\n', jq_bufnr,false,nil)
      end,
      { buffer = jq_bufnr }
    )
    -- setup keybinding autocmd in the filter buffer:
    -- query json
    if vim.fn.maparg('<leader><CR>', 'n') ~= '' then
      vim.keymap.del('n', '<leader><CR>', { buffer = jq_bufnr })
    end
    kmap( 'n', '<leader><CR>', function()
        local filter = buf_text(jq_bufnr)
        -- Get filters separated by double newlines
        local filters = vim.fn.split(filter, '\n\n')
        for i, the_filter in ipairs(filters) do
          if the_filter:match('^#') then goto continue end
          if the_filter == '' then goto continue end -- skip empty lines in the filter buffer
          if the_filter == nil then goto continue end -- skip empty lines in the filter buffer
          set_buf_text(jq_filter(json_bufnr, the_filter), result_bufnr,false,the_filter)
          ::continue::
        end
        set_buf_text('# JQ filter: press <CR> to execute it\n\n', jq_bufnr,false,nil)
      end,
      { buffer = jq_bufnr }
    )

  else
    -- setup keybinding autocmd in the filter buffer:
    if vim.fn.maparg('<CR>', 'n') ~= '' then
      vim.keymap.del('n', '<CR>', { buffer = jq_bufnr })
    end
    kmap( 'n', '<CR>', function()
        local filter = buf_text(jq_bufnr)
        -- Get filters separated by double newlines
        local filters = vim.fn.split(filter, '\n\n')
        for i, the_filter in ipairs(filters) do
          if the_filter:match('^#') then goto continue end
          if the_filter == '' then goto continue end -- skip empty lines in the filter buffer
          if the_filter == nil then goto continue end -- skip empty lines in the filter buffer
          set_buf_text(jq_filter(json_bufnr, the_filter), result_bufnr,editfile,the_filter)
          ::continue::
        end
        set_buf_text('# JQ filter: press <CR> to execute it\n\n', jq_bufnr,false,nil)
      end,
      { buffer = jq_bufnr }
    )
  end
end

ucmd('Jq', function()
  Jq_command(false,false)
end, {})

ucmd('Jqedit', function()
  vim.cmd'set nofoldenable'
  Jq_command(true,true)
end, {})

ucmd('Jqhorizontal', function()
  Jq_command(true,false)
end, {})
