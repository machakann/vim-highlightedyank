" highlight object - managing highlight on a buffer
let s:NULLPOS = [0, 0, 0, 0]
let s:MAXCOL = 2147483647
let s:ON = 1
let s:OFF = 0



function! highlightedyank#highlight#new(region) abort  "{{{
  let highlight = deepcopy(s:highlight)
  if a:region.wise ==# 'char' || a:region.wise ==# 'v'
    let highlight.order_list = s:highlight_order_charwise(a:region)
  elseif a:region.wise ==# 'line' || a:region.wise ==# 'V'
    let highlight.order_list = s:highlight_order_linewise(a:region)
  elseif a:region.wise ==# 'block' || a:region.wise[0] ==# "\<C-v>"
    let highlight.order_list = s:highlight_order_blockwise(a:region)
  endif
  return highlight
endfunction "}}}


" Highlight class {{{
let s:highlight = {
  \   'status': s:OFF,
  \   'group': '',
  \   'id': [],
  \   'order_list': [],
  \   'bufnr': 0,
  \   'winid': 0,
  \ }


function! s:highlight.show(...) dict abort "{{{
  if empty(self.order_list)
    return 0
  endif

  if a:0 < 1
    if empty(self.group)
      return 0
    else
      let hi_group = self.group
    endif
  else
    let hi_group = a:1
  endif

  if self.status is s:ON
    if hi_group ==# self.group
      return 0
    else
      call self.quench()
    endif
  endif

  for order in self.order_list
    let self.id += [matchaddpos(hi_group, order)]
  endfor
  call filter(self.id, 'v:val > 0')
  let self.status = s:ON
  let self.group = hi_group
  let self.bufnr = bufnr('%')
  let self.winid = win_getid()
  return 1
endfunction "}}}


function! s:highlight.quench() dict abort "{{{
  if self.status is s:OFF
    return 0
  endif
  call map(self.id, 'matchdelete(v:val)')
  call filter(self.id, 'v:val > 0')
  return 1
endfunction "}}}


function! s:highlight.switch() abort "{{{
  if win_getid() != self.winid
    return
  endif

  if bufnr('%') == self.bufnr
    call self.show()
  else
    call self.quench()
  endif
endfunction "}}}


function! s:highlight.empty() abort "{{{
  return empty(self.order_list)
endfunction "}}}
"}}}


function! s:highlight_order_charwise(region) abort  "{{{
  if a:region.head == s:NULLPOS || a:region.tail == s:NULLPOS || s:is_ahead(a:region.head, a:region.tail)
    return []
  endif
  if a:region.head[1] == a:region.tail[1]
    let order = [a:region.head[1:2] + [a:region.tail[2] - a:region.head[2] + 1]]
    return [order]
  endif

  let order = []
  let order_list = []
  let n = 0
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
  if order != []
    let order_list += [order]
  endif
  return order_list
endfunction "}}}


function! s:highlight_order_linewise(region) abort  "{{{
  if a:region.head == s:NULLPOS || a:region.tail == s:NULLPOS || a:region.head[1] > a:region.tail[1]
    return []
  endif

  let order = []
  let order_list = []
  let n = 0
  for lnum in range(a:region.head[1], a:region.tail[1])
    let order += [lnum]
    if n == 7
      let order_list += [order]
      let order = []
      let n = 0
    else
      let n += 1
    endif
  endfor
  if order != []
    let order_list += [order]
  endif
  return order_list
endfunction "}}}


function! s:highlight_order_blockwise(region) abort "{{{
  if a:region.head == s:NULLPOS || a:region.tail == s:NULLPOS || s:is_ahead(a:region.head, a:region.tail)
    return []
  endif

  let view = winsaveview()
  let vcol_head = virtcol(a:region.head[1:2])
  if a:region.blockwidth == s:MAXCOL
    let vcol_tail = a:region.blockwidth
  else
    let vcol_tail = vcol_head + a:region.blockwidth - 1
  endif
  let order = []
  let order_list = []
  let n = 0
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
  if order != []
    let order_list += [order]
  endif
  call winrestview(view)
  return order_list
endfunction "}}}


function! s:is_ahead(pos1, pos2) abort  "{{{
  return a:pos1[1] > a:pos2[1] || (a:pos1[1] == a:pos2[1] && a:pos1[2] > a:pos2[2])
endfunction "}}}

" vim:set foldmethod=marker:
" vim:set commentstring="%s:
" vim:set ts=2 sts=2 sw=2:
