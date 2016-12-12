" highlight object - managing highlight on a buffer

" variables "{{{
" null valiables
let s:null_pos = [0, 0, 0, 0]

" constants
let s:maxcol = 2147483647

" types
let s:type_list = type([])

" patchs
if v:version > 704 || (v:version == 704 && has('patch237'))
  let s:has_patch_7_4_362 = has('patch-7.4.362')
  let s:has_patch_7_4_392 = has('patch-7.4.392')
else
  let s:has_patch_7_4_362 = v:version == 704 && has('patch362')
  let s:has_patch_7_4_392 = v:version == 704 && has('patch392')
endif

" features
let s:has_gui_running = has('gui_running')

" SID
function! s:SID() abort
  return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_SID$')
endfunction
let s:SID = printf("\<SNR>%s_", s:SID())
delfunction s:SID
"}}}

function! highlightedyank#highlight#new() abort  "{{{
  return deepcopy(s:highlight)
endfunction
"}}}

" s:highlight "{{{
let s:highlight = {
      \   'status': 0,
      \   'group' : '',
      \   'id'    : [],
      \   'order_list': [],
      \   'region': {},
      \   'motionwise': '',
      \   'bufnr': 0,
      \   'winid': 0,
      \ }
"}}}
function! s:highlight.order(region, motionwise) dict abort  "{{{
  if a:motionwise ==# 'char' || a:motionwise ==# 'v'
    let order_list = s:highlight_order_charwise(a:region)
  elseif a:motionwise ==# 'line' || a:motionwise ==# 'V'
    let order_list = s:highlight_order_linewise(a:region)
  elseif a:motionwise ==# 'block' || a:motionwise[0] ==# "\<C-v>"
    let order_list = s:highlight_order_blockwise(a:region)
  else
    return
  endif
  let self.order_list += order_list
  let self.region = deepcopy(a:region)
  let self.motionwise = a:motionwise
endfunction
"}}}
function! s:highlight.show(...) dict abort "{{{
  if self.order_list == []
    return 0
  endif

  if a:0 < 1
    if self.group ==# ''
      return 0
    else
      let hi_group = self.group
    endif
  else
    let hi_group = a:1
  endif

  if self.status
    if hi_group ==# self.group
      return 0
    else
      call self.quench()
    endif
  endif

  for order in self.order_list
    let self.id += s:matchaddpos(hi_group, order)
  endfor
  call filter(self.id, 'v:val > 0')
  let self.status = 1
  let self.group = hi_group
  let self.bufnr = bufnr('%')
  let self.winid = win_getid()
  let self.text  = s:get_buf_text(self.region, self.motionwise)
  return 1
endfunction
"}}}
function! s:highlight.quench() dict abort "{{{
  if !self.status
    return 0
  endif

  let winid = win_getid()
  let view = winsaveview()
  if win_getid() == self.winid
    call map(self.id, 'matchdelete(v:val)')
    call filter(self.id, 'v:val > 0')
    let succeeded = 1
  else
    if s:is_in_cmdline_window()
      let s:quenching_queue += [self]
      augroup highlightedyank-quech-queue
        autocmd!
        autocmd CmdWinLeave * call s:exodus_from_cmdwindow()
      augroup END
      let succeeded = 0
    else
      if win_gotoid(self.winid)
        call map(self.id, 'matchdelete(v:val)')
        call filter(self.id, 'v:val > 0')
      else
        call filter(self.id, 0)
      endif
      let succeeded = 1
      call win_gotoid(winid)
      call winrestview(view)
    endif
  endif

  if succeeded
    let self.status = 0
  endif
  return succeeded
endfunction
"}}}
function! s:highlight.quench_timer(time) dict abort "{{{
  let id = timer_start(a:time, s:SID . 'scheduled_quench')
  let s:quench_table[id] = self
  call s:set_autocmds(id)
  return id
endfunction
"}}}
function! s:highlight.persist() dict abort  "{{{
  let id = s:get_pid()
  call s:set_autocmds(id)
  let s:quench_table[id] = self
  return id
endfunction
"}}}
function! s:highlight.is_text_identical() dict abort "{{{
  return s:get_buf_text(self.region, self.motionwise) ==# self.text
endfunction
"}}}

" for scheduled-quench "{{{
let s:quench_table = {}
let s:obsolete_augroup = []
function! s:scheduled_quench(id) abort  "{{{
  let options = s:shift_options()
  try
    let highlight = s:quench_table[a:id]
    call highlight.quench()
  catch /^Vim\%((\a\+)\)\=:E523/
    " NOTE: TextYankPost event sets "textlock"
    let highlight = s:quench_table[a:id]
    call highlight.quench_timer(50)
    return 1
  finally
    unlet s:quench_table[a:id]
    call s:metabolize_augroup(a:id)
    call timer_stop(a:id)
    call s:restore_options(options)
    redraw
  endtry
endfunction
"}}}
function! highlightedyank#highlight#cancel(...) abort "{{{
  if a:0 > 0
    let id_list = type(a:1) == s:type_list ? a:1 : a:000
  else
    let id_list = map(keys(s:quench_table), 'str2nr(v:val)')
  endif

  for id in id_list
    call s:scheduled_quench(id)
  endfor
endfunction
"}}}
function! highlightedyank#highlight#get(id) abort "{{{
  return get(s:quench_table, a:id, {})
endfunction
"}}}
function! s:metabolize_augroup(id) abort  "{{{
  " clean up autocommands in the current augroup
  execute 'augroup highlightedyank-highlight-' . a:id
    autocmd!
  augroup END

  " clean up obsolete augroup
  call filter(s:obsolete_augroup, 'v:val != a:id')
  for id in s:obsolete_augroup
    execute 'augroup! highlightedyank-highlight-' . id
  endfor
  call filter(s:obsolete_augroup, 0)

  " queue the current augroup
  call add(s:obsolete_augroup, a:id)
endfunction
"}}}
let s:quenching_queue = []
function! s:quench_queued(...) abort "{{{
  if s:is_in_cmdline_window()
    return
  endif

  augroup highlightedyank-quech-queue
    autocmd!
  augroup END

  let list = copy(s:quenching_queue)
  let s:quenching_queue = []
  for highlight in list
    call highlight.quench()
  endfor
endfunction
"}}}
function! s:exodus_from_cmdwindow() abort "{{{
  augroup highlightedyank-quech-queue
    autocmd!
    autocmd CursorMoved * call s:quench_queued()
  augroup END
endfunction
"}}}

" ID for persistent highlights
let s:pid = 0
function! s:get_pid() abort "{{{
  if s:pid != -1/0
    let s:pid -= 1
  else
    let s:pid = -1
  endif
  return s:pid
endfunction
"}}}
"}}}

" private functions
function! s:highlight_order_charwise(region) abort  "{{{
  let order = []
  let order_list = []
  let n = 0
  if a:region.head != s:null_pos && a:region.tail != s:null_pos && s:is_equal_or_ahead(a:region.tail, a:region.head)
    if a:region.head[1] == a:region.tail[1]
      let order += [a:region.head[1:2] + [a:region.tail[2] - a:region.head[2] + 1]]
      let n += 1
    else
      for lnum in range(a:region.head[1], a:region.tail[1])
        if lnum == a:region.head[1]
          let order += [a:region.head[1:2] + [col([a:region.head[1], '$']) - a:region.head[2] + 1]]
        elseif lnum == a:region.tail[1]
          let order += [[a:region.tail[1], 1] + [a:region.tail[2]]]
        else
          let order += [[lnum]]
        endif

        if n == 7
          let order_list += [order]
          let order = []
          let n = 0
        else
          let n += 1
        endif
      endfor
    endif
  endif
  if order != []
    let order_list += [order]
  endif
  return order_list
endfunction
"}}}
function! s:highlight_order_linewise(region) abort  "{{{
  let order = []
  let order_list = []
  let n = 0
  if a:region.head != s:null_pos && a:region.tail != s:null_pos && a:region.head[1] <= a:region.tail[1]
    for lnum in range(a:region.head[1], a:region.tail[1])
      let order += [[lnum]]
      if n == 7
        let order_list += [order]
        let order = []
        let n = 0
      else
        let n += 1
      endif
    endfor
  endif
  if order != []
    let order_list += [order]
  endif
  return order_list
endfunction
"}}}
function! s:highlight_order_blockwise(region) abort "{{{
  let view = winsaveview()
  let vcol_head = virtcol(a:region.head[1:2])
  if a:region.blockwidth == s:maxcol
    let vcol_tail = a:region.blockwidth
  else
    let vcol_tail = vcol_head + a:region.blockwidth - 1
  endif
  let order = []
  let order_list = []
  let n = 0
  if a:region.head != s:null_pos && a:region.tail != s:null_pos && s:is_equal_or_ahead(a:region.tail, a:region.head)
    for lnum in range(a:region.head[1], a:region.tail[1])
      call cursor(lnum, 1)
      execute printf('normal! %s|', vcol_head)
      let head = getpos('.')
      execute printf('normal! %s|', vcol_tail)
      let tail = getpos('.')
      let col = head[2]
      let len = tail[2] - head[2] + 1
      let order += [[lnum, col, len]]

      if n == 7
        let order_list += [order]
        let order = []
        let n = 0
      else
        let n += 1
      endif
    endfor
  endif
  if order != []
    let order_list += [order]
  endif
  call winrestview(view)
  return order_list
endfunction
"}}}
" function! s:matchaddpos(group, pos) abort "{{{
if s:has_patch_7_4_362
  function! s:matchaddpos(group, pos) abort
    return [matchaddpos(a:group, a:pos)]
  endfunction
else
  function! s:matchaddpos(group, pos) abort
    let id_list = []
    for pos in a:pos
      if len(pos) == 1
        let id_list += [matchadd(a:group, printf('\%%%dl', pos[0]))]
      else
        let id_list += [matchadd(a:group, printf('\%%%dl\%%>%dc.*\%%<%dc', pos[0], pos[1]-1, pos[1]+pos[2]))]
      endif
    endfor
    return id_list
  endfunction
endif
"}}}
function! s:is_equal_or_ahead(pos1, pos2) abort  "{{{
  return a:pos1[1] > a:pos2[1] || (a:pos1[1] == a:pos2[1] && a:pos1[2] >= a:pos2[2])
endfunction
"}}}
" function! s:is_in_cmdline_window() abort  "{{{
if s:has_patch_7_4_392
  function! s:is_in_cmdline_window() abort
    return getcmdwintype() !=# ''
  endfunction
else
  function! s:is_in_cmdline_window() abort
    let is_in_cmdline_window = 0
    try
      execute 'tabnext ' . tabpagenr()
    catch /^Vim\%((\a\+)\)\=:E11/
      let is_in_cmdline_window = 1
    catch
    finally
      return is_in_cmdline_window
    endtry
  endfunction
endif
"}}}
function! s:shift_options() abort "{{{
  let options = {}

  """ tweak appearance
  " hide_cursor
  if s:has_gui_running
    let options.cursor = &guicursor
    set guicursor+=a:block-NONE
  else
    let options.cursor = &t_ve
    set t_ve=
  endif

  return options
endfunction
"}}}
function! s:restore_options(options) abort "{{{
  if s:has_gui_running
    set guicursor&
    let &guicursor = a:options.cursor
  else
    let &t_ve = a:options.cursor
  endif
endfunction
"}}}
function! s:get_buf_text(region, type) abort  "{{{
  " NOTE: Do *not* use operator+textobject in another textobject!
  "       For example, getting a text with the command is not appropriate.
  "         execute printf('normal! %s:call setpos(".", %s)%s""y', a:type, string(a:region.tail), "\<CR>")
  "       Because it causes confusions for the unit of dot-repeating.
  "       Use visual selection+operator as following.
  let text = ''
  let visual = [getpos("'<"), getpos("'>")]
  let modified = [getpos("'["), getpos("']")]
  let registers = s:saveregisters()
  let view = winsaveview()
  try
    call setpos('.', a:region.head)
    execute 'normal! ' . s:v(a:type)
    call setpos('.', a:region.tail)
    silent noautocmd normal! ""y
    let text = @@

    " NOTE: This line is required to reset v:register.
    normal! :
  finally
    call s:restoreregisters(registers)
    call setpos("'<", visual[0])
    call setpos("'>", visual[1])
    call setpos("'[", modified[0])
    call setpos("']", modified[1])
    call winrestview(view)
    return text
  endtry
endfunction
"}}}
function! s:saveregisters() abort "{{{
  let registers = {}
  let registers['0'] = s:getregister('0')
  let registers['1'] = s:getregister('1')
  let registers['2'] = s:getregister('2')
  let registers['3'] = s:getregister('3')
  let registers['4'] = s:getregister('4')
  let registers['5'] = s:getregister('5')
  let registers['6'] = s:getregister('6')
  let registers['7'] = s:getregister('7')
  let registers['8'] = s:getregister('8')
  let registers['9'] = s:getregister('9')
  let registers['"'] = s:getregister('"')
  if &clipboard =~# 'unnamed'
    let registers['*'] = s:getregister('*')
  endif
  if &clipboard =~# 'unnamedplus'
    let registers['+'] = s:getregister('+')
  endif
  return registers
endfunction
"}}}
function! s:restoreregisters(registers) abort "{{{
  for [register, contains] in items(a:registers)
    call s:setregister(register, contains)
  endfor
endfunction
"}}}
function! s:getregister(register) abort "{{{
  return [getreg(a:register), getregtype(a:register)]
endfunction
"}}}
function! s:setregister(register, contains) abort "{{{
  let [value, options] = a:contains
  return setreg(a:register, value, options)
endfunction
"}}}
function! s:v(v) abort  "{{{
  if a:v ==# 'char'
    let v = 'v'
  elseif a:v ==# 'line'
    let v = 'V'
  elseif a:v ==# 'block'
    let v = "\<C-v>"
  else
    let v = a:v
  endif
  return v
endfunction
"}}}
function! s:set_autocmds(id) abort "{{{
  execute 'augroup highlightedyank-highlight-' . a:id
    autocmd!
    execute printf('autocmd TextChanged <buffer> call s:cancel_highlight(%s, "TextChanged")', a:id)
    execute printf('autocmd InsertEnter <buffer> call s:cancel_highlight(%s, "InsertEnter")', a:id)
    execute printf('autocmd BufUnload <buffer> call s:cancel_highlight(%s, "BufUnload")', a:id)
    execute printf('autocmd BufEnter * call s:switch_highlight(%s)', a:id)
  augroup END
endfunction
"}}}
function! s:cancel_highlight(id, event) abort  "{{{
  let highlight = highlightedyank#highlight#get(a:id)
  if highlight != {} && s:highlight_off_by_{a:event}(highlight)
    call highlightedyank#highlight#cancel(a:id)
  endif
endfunction
"}}}
function! s:highlight_off_by_InsertEnter(highlight) abort  "{{{
  return 1
endfunction
"}}}
function! s:highlight_off_by_TextChanged(highlight) abort  "{{{
  return !a:highlight.is_text_identical()
endfunction
"}}}
function! s:highlight_off_by_BufUnload(highlight) abort  "{{{
  return 1
endfunction
"}}}
function! s:switch_highlight(id) abort "{{{
  let highlight = highlightedyank#highlight#get(a:id)
  if highlight != {} && highlight.winid == win_getid()
    if highlight.bufnr == bufnr('%')
      call highlight.show()
    else
      call highlight.quench()
    endif
  endif
endfunction
"}}}

" vim:set foldmethod=marker:
" vim:set commentstring="%s:
" vim:set ts=2 sts=2 sw=2:
