" highlighted-yank: Make the yanked region apparent!
" FIXME: Highlight region is incorrect when an input ^V[count]l ranges
"        multiple lines.
let s:NULLPOS = [0, 0, 0, 0]
let s:NULLREGION = [s:NULLPOS, s:NULLPOS, '']
let s:MAXCOL = 2147483647
let s:ON = 1
let s:OFF = 0
let s:HIGROUP = 'HighlightedyankRegion'



let s:timer = -1

" Highlight the yanked region
function! highlightedyank#debounce() abort "{{{
  if s:state is s:OFF
    return
  endif

  let operator = v:event.operator
  let regtype = v:event.regtype
  let regcontents = v:event.regcontents
  let marks = [line("'["), line("']"), col("'["), col("']")]
  if s:timer isnot -1
    call timer_stop(s:timer)
  endif

  " NOTE: The timer callback is not called while vim is busy, thus the
  "       highlight procedure starts after the control is returned to the user.
  "       This makes complex-repeat faster because the highlight doesn't
  "       performed during a macro execution.
  let s:timer = timer_start(1, {-> s:highlight(operator, regtype, regcontents, marks)})
endfunction "}}}


let s:state = s:ON

function! highlightedyank#on() abort "{{{
  let s:state = s:ON
endfunction "}}}


function! highlightedyank#off() abort "{{{
  let s:state = s:OFF
endfunction "}}}


function! highlightedyank#toggle() abort "{{{
  if s:state is s:ON
    call highlightedyank#off()
  else
    call highlightedyank#on()
  endif
endfunction "}}}


function! s:highlight(operator, regtype, regcontents, marks) abort "{{{
  let s:timer = -1
  if a:operator isnot# 'y' || a:regtype is# ''
    return
  endif
  if a:marks !=#  [line("'["), line("']"), col("'["), col("']")]
    return
  endif

  let [start, end, type] = s:get_region(a:regtype, a:regcontents)
  if empty(type)
    return
  endif

  let maxlinenumber = s:get('max_lines', 10000)
  if end[1] - start[1] + 1 > maxlinenumber
    return
  endif

  let hi_duration = s:get('highlight_duration', 1000)
  if hi_duration == 0
    return
  endif

  call highlightedyank#highlight#add(s:HIGROUP, start, end, type, hi_duration)
endfunction "}}}


function! s:get_region(regtype, regcontents) abort "{{{
  if a:regtype is# 'v'
    return s:get_region_char(a:regcontents)
  elseif a:regtype is# 'V'
    return s:get_region_line(a:regcontents)
  elseif a:regtype[0] is# "\<C-v>"
    " NOTE: the width from v:event.regtype is not correct if 'clipboard' is
    "       unnamed or unnamedplus in windows
    " let width = str2nr(a:regtype[1:])
    return s:get_region_block(a:regcontents)
  endif
  return s:NULLREGION
endfunction "}}}


function! s:get_region_char(regcontents) abort "{{{
  let len = len(a:regcontents)
  let start = getpos("'[")
  let end = copy(start)
  if len == 0
    return s:NULLREGION
  elseif len == 1
    let end[2] += strlen(a:regcontents[0]) - 1
  elseif len == 2 && empty(a:regcontents[1])
    let end[2] += strlen(a:regcontents[0])
  else
    if empty(a:regcontents[-1])
      let end[1] += len - 2
      let end[2] = strlen(a:regcontents[-2])
    else
      let end[1] += len - 1
      let end[2] = strlen(a:regcontents[-1])
    endif
  endif
  let end = s:modify_end(end)
  return [start, end, 'v']
endfunction "}}}


function! s:get_region_line(regcontents) abort "{{{
  let start = getpos("'[")
  let end = getpos("']")
  if end[2] == s:MAXCOL
    let end[2] = col([end[1], '$'])
  endif
  return [start, end, 'V']
endfunction "}}}


function! s:get_region_block(regcontents) abort "{{{
  let len = len(a:regcontents)
  if len == 0
    return s:NULLREGION
  endif

  let view = winsaveview()
  let curcol = col('.')
  let width = max(map(copy(a:regcontents), 'strdisplaywidth(v:val, curcol)'))
  let start = getpos("'[")
  call setpos('.', start)
  if len > 1
    execute printf('normal! %sj', len - 1)
  endif
  execute printf('normal! %s|', virtcol('.') + width - 1)
  let end = s:modify_end(getpos('.'))
  call winrestview(view)

  let blockwidth = width
  if strdisplaywidth(getline('.')) < width
    let blockwidth = s:MAXCOL
  endif
  let type = "\<C-v>" . blockwidth
  return [start, end, type]
endfunction "}}}


function! s:modify_end(end) abort "{{{
  " for multibyte characters
  if a:end[2] == col([a:end[1], '$']) || a:end[3] != 0
    return a:end
  endif

  let cursor = getpos('.')
  call setpos('.', a:end)
  let letterhead = searchpos('\zs', 'bcn', line('.'))
  if letterhead[1] > a:end[2]
    " try again without 'c' flag if letterhead is behind the original
    " position. It may look strange but it happens with &enc ==# 'cp932'
    let letterhead = searchpos('\zs', 'bn', line('.'))
  endif
  let a:end[1:2] = letterhead
  call setpos('.', cursor)
  return a:end
endfunction "}}}


function! s:get(name, default) abort  "{{{
  let identifier = 'highlightedyank_' . a:name
  return get(b:, identifier, get(g:, identifier, a:default))
endfunction "}}}

" vim:set foldmethod=marker:
" vim:set commentstring="%s:
" vim:set ts=2 sts=2 sw=2:
