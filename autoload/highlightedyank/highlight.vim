" highlight object - managing highlight on a buffer

" variables "{{{
" null valiables
let s:null_pos = [0, 0, 0, 0]

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
      \   'tabnr': 0,
      \   'winnr': 0,
      \   'bufnr': 0,
      \ }
"}}}
function! s:highlight.order(region, motionwise) dict abort  "{{{
  if a:motionwise ==# 'char'
    let order_list = s:highlight_order_charwise(a:region)
  elseif a:motionwise ==# 'line'
    let order_list = s:highlight_order_linewise(a:region)
  elseif a:motionwise ==# 'block'
    let order_list = s:highlight_order_blockwise(a:region)
  endif
  let self.order_list += order_list
  let self.region = deepcopy(a:region)
  let self.motionwise = a:motionwise
endfunction
"}}}
function! s:highlight.show(hi_group) dict abort "{{{
  if self.order_list == []
    return 0
  endif

  if self.status && a:hi_group !=# self.group
    call self.quench()
  endif

  if self.status
    return 0
  endif

  for order in self.order_list
    let self.id += s:matchaddpos(a:hi_group, order)
  endfor
  call filter(self.id, 'v:val > 0')
  let self.status = 1
  let self.group = a:hi_group
  let self.tabnr = tabpagenr()
  let self.winnr = winnr()
  let self.bufnr = bufnr('%')
  return 1
endfunction
"}}}
function! s:highlight.quench() dict abort "{{{
  if !self.status
    return 0
  endif

  let tabnr = tabpagenr()
  let winnr = winnr()
  let view = winsaveview()
  if s:is_highlight_exists(self.id)
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
      if s:search_highlighted_windows(self.id, tabnr) != [0, 0]
        call map(self.id, 'matchdelete(v:val)')
        call filter(self.id, 'v:val > 0')
        let succeeded = 1
      else
        call filter(self.id, 0)
        let succeeded = 0
      endif
      call s:goto_window(winnr, tabnr, view)
    endif
  endif

  if succeeded
    let self.status = 0
    let self.group = ''
  endif
  return succeeded
endfunction
"}}}
function! s:highlight.scheduled_quench(time, ...) dict abort  "{{{
  let id = get(a:000, 0, -1)
  if id < 0
    let id = timer_start(a:time, s:SID . 'scheduled_quench')
  endif

  if !has_key(s:quench_table, id)
    let s:quench_table[id] = []
  endif
  let s:quench_table[id] += [self]
  return id
endfunction
"}}}

" for scheduled-quench "{{{
let s:quench_table = {}
function! s:scheduled_quench(id) abort  "{{{
  let options = s:shift_options()
  try
    for highlight in s:quench_table[a:id]
      call highlight.quench()
    endfor
    redraw
    execute 'augroup highlightedyank-highlight-cancel-' . a:id
      autocmd!
    augroup END
    execute 'augroup! highlightedyank-highlight-cancel-' . a:id
    unlet s:quench_table[a:id]
  finally
    call s:restore_options(options)
  endtry
endfunction
"}}}
function! highlightedyank#highlight#cancel(...) abort "{{{
  if a:0 > 0
    let id_list = type(a:1) == s:type_list ? a:1 : a:000
  else
    let id_list = keys(s:quench_table)
  endif

  for id in id_list
    call s:scheduled_quench(id)
    call timer_stop(id)
  endfor
endfunction
"}}}
function! highlightedyank#highlight#get(id) abort "{{{
  return get(s:quench_table, a:id, [])
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
  let vcol_tail = virtcol(a:region.tail[1:2])
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
      PP! [head, tail, len, vcol_head, vcol_tail]
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
function! s:goto_window(winnr, tabnr, ...) abort "{{{
  if a:tabnr != tabpagenr()
    execute 'tabnext ' . a:tabnr
  endif
  if tabpagenr() != a:tabnr
    return 0
  endif

  try
    if a:winnr != winnr()
      execute a:winnr . 'wincmd w'
    endif
  catch /^Vim\%((\a\+)\)\=:E16/
    return 0
  endtry

  if a:0 > 0
    call winrestview(a:1)
  endif

  return 1
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
    set guicursor+=n-o:block-NONE
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
function! s:search_highlighted_windows(id, ...) abort  "{{{
  let original_winnr = winnr()
  let original_tabnr = tabpagenr()
  if a:id != []
    let tablist = range(1, tabpagenr('$'))
    if a:0 > 0
      let tabnr = a:1
      let [tabnr, winnr] = s:scan_windows(a:id, tabnr)
      if tabnr != 0
        return [tabnr, winnr]
      endif
      call filter(tablist, 'v:val != tabnr')
    endif

    for tabnr in tablist
      let [tabnr, winnr] = s:scan_windows(a:id, tabnr)
      if tabnr != 0
        return [tabnr, winnr]
      endif
    endfor
  endif
  execute 'tabnext ' . original_tabnr
  execute original_winnr . 'wincmd w'
  return [0, 0]
endfunction
"}}}
function! s:scan_windows(id, tabnr) abort "{{{
  for winnr in range(1, winnr('$'))
    if s:is_highlight_exists(a:id, winnr, a:tabnr)
      return [a:tabnr, winnr]
    endif
  endfor
  return [0, 0]
endfunction
"}}}
function! s:is_highlight_exists(id, ...) abort "{{{
  if a:id != []
    if a:0 > 1
      if !s:goto_window(a:1, a:2)
        return 0
      endif
    elseif a:0 > 0
      if !s:goto_window(a:1, tabpagenr())
        return 0
      endif
    endif

    let id = a:id[0]
    if filter(getmatches(), 'v:val.id == id') != []
      return 1
    endif
  endif
  return 0
endfunction
"}}}


" vim:set foldmethod=marker:
" vim:set commentstring="%s:
" vim:set ts=2 sts=2 sw=2:
