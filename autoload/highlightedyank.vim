" highlighted-yank: Make the yanked region apparent!
" FIXME: Highlight region is incorrect when an input ^V[count]l ranges
"        multiple lines.
let s:Schedule = vital#highlightedyank#new().import('Schedule')
                  \.augroup('highlightedyank-highlight')
let s:NULLPOS = [0, 0, 0, 0]
let s:NULLREGION = {
  \ 'wise': '', 'blockwidth': 0,
  \ 'head': copy(s:NULLPOS), 'tail': copy(s:NULLPOS),
  \ }
let s:MAXCOL = 2147483647
let s:ON = 1
let s:OFF = 0
let s:HIGROUP = 'HighlightedyankRegion'



let s:timer = -1

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

  " NOTE: The timer callback would not be called while vim is busy, thus the
  "       highlight procedure starts after the control has been returned to
  "       user.
  "       This makes complex-repeat faster because the highlight doesn't
  "       performed in a macro execution.
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
  if a:marks !=#  [line("'["), line("']"), col("'["), col("']")]
    return
  endif
  if a:operator !=# 'y' || a:regtype ==# ''
    return
  endif

  let view = winsaveview()
  let region = s:derive_region(a:regtype, a:regcontents)
  let maxlinenumber = s:get('max_lines', 10000)
  if region.tail[1] - region.head[1] + 1 <= maxlinenumber
    let hi_duration = s:get('highlight_duration', 1000)
    if hi_duration != 0
      call s:glow(region, s:HIGROUP, hi_duration)
    endif
  endif
  call winrestview(view)
endfunction "}}}


function! s:derive_region(regtype, regcontents) abort "{{{
  if a:regtype ==# 'v'
    let region = s:derive_region_char(a:regcontents)
  elseif a:regtype ==# 'V'
    let region = s:derive_region_line(a:regcontents)
  elseif a:regtype[0] ==# "\<C-v>"
    " NOTE: the width from v:event.regtype is not correct if 'clipboard' is
    "       unnamed or unnamedplus in windows
    " let width = str2nr(a:regtype[1:])
    let region = s:derive_region_block(a:regcontents)
  else
    let region = deepcopy(s:NULLREGION)
  endif
  return region
endfunction "}}}


function! s:derive_region_char(regcontents) abort "{{{
  let len = len(a:regcontents)
  let region = {}
  let region.wise = 'char'
  let region.head = getpos("'[")
  let region.tail = copy(region.head)
  if len == 0
    let region = deepcopy(s:NULLREGION)
  elseif len == 1
    let region.tail[2] += strlen(a:regcontents[0]) - 1
  elseif len == 2 && empty(a:regcontents[1])
    let region.tail[2] += strlen(a:regcontents[0])
  else
    if empty(a:regcontents[-1])
      let region.tail[1] += len - 2
      let region.tail[2] = strlen(a:regcontents[-2])
    else
      let region.tail[1] += len - 1
      let region.tail[2] = strlen(a:regcontents[-1])
    endif
  endif
  return s:modify_region(region)
endfunction "}}}


function! s:derive_region_line(regcontents) abort "{{{
  let region = {}
  let region.wise = 'line'
  let region.head = getpos("'[")
  let region.tail = getpos("']")
  if region.tail[2] == s:MAXCOL
    let region.tail[2] = col([region.tail[1], '$'])
  endif
  return region
endfunction "}}}


function! s:derive_region_block(regcontents) abort "{{{
  let len = len(a:regcontents)
  if len == 0
    return deepcopy(s:NULLREGION)
  endif

  let curpos = getpos('.')
  let curcol = curpos[2]
  let width = max(map(copy(a:regcontents), 'strdisplaywidth(v:val, curcol)'))
  let region = deepcopy(s:NULLREGION)
  let region.wise = 'block'
  let region.head = getpos("'[")
  call setpos('.', region.head)
  if len > 1
    execute printf('normal! %sj', len - 1)
  endif
  execute printf('normal! %s|', virtcol('.') + width - 1)
  let region.tail = getpos('.')
  let region.blockwidth = width
  if strdisplaywidth(getline('.')) < width
    let region.blockwidth = s:MAXCOL
  endif
  call setpos('.', curpos)
  return s:modify_region(region)
endfunction "}}}


function! s:modify_region(region) abort "{{{
  " for multibyte characters
  if a:region.tail[2] != col([a:region.tail[1], '$']) && a:region.tail[3] == 0
    let cursor = getpos('.')
    call setpos('.', a:region.tail)
    call search('\%(^\|.\)', 'bc')
    let a:region.tail = getpos('.')
    call setpos('.', cursor)
  endif
  return a:region
endfunction "}}}


let s:quenchtask = {}

function! s:glow(region, hi_group, duration) abort "{{{
  let highlight = highlightedyank#highlight#new(a:region)
  if highlight.empty()
    return
  endif

  if !empty(s:quenchtask) && !s:quenchtask.hasdone()
    call s:quenchtask.trigger()
  endif
  if !highlight.show(a:hi_group)
    return
  endif

  let switchtask = s:Schedule.Task()
  call switchtask.repeat(-1)
  call switchtask.call(highlight.switch, [], highlight)
  call switchtask.waitfor(['BufEnter'])

  let s:quenchtask = s:Schedule.Task()
  call s:quenchtask.call(funcref('s:quench'), [highlight])
  call s:quenchtask.call(switchtask.cancel, [], switchtask)
  call s:quenchtask.waitfor([a:duration,
    \ ['TextChanged', '<buffer>'], ['InsertEnter', '<buffer>'],
    \ ['BufUnload', '<buffer>'], ['CmdwinLeave', '<buffer>'],
    \ ['TabLeave', '*']])
endfunction "}}}


function! s:quench(highlight) abort "{{{
  if win_getid() == a:highlight.winid
    " current window
    call a:highlight.quench()
  else
    " move to another window
    let original_winid = win_getid()
    let view = winsaveview()

    if s:is_in_cmdline_window()
      " cannot move out from commandline-window
      " quench later
      let quenchtask = s:Schedule.TaskChain()
      call quenchtask.hook(['CmdWinLeave'])
      call quenchtask.hook([1]).call(a:highlight.quench, [], a:highlight)
      call quenchtask.waitfor()
    else
      noautocmd let reached = win_gotoid(a:highlight.winid)
      if reached
        " reached to the highlighted buffer
        call a:highlight.quench()
      else
        " highlighted buffer does not exist
        call filter(a:highlight.id, 0)
      endif
      noautocmd call win_gotoid(original_winid)
      call winrestview(view)
    endif
  endif
endfunction "}}}


function! s:get(name, default) abort  "{{{
  let identifier = 'highlightedyank_' . a:name
  return get(b:, identifier, get(g:, identifier, a:default))
endfunction "}}}


function! s:is_in_cmdline_window() abort "{{{
  return getcmdwintype() !=# ''
endfunction "}}}

" vim:set foldmethod=marker:
" vim:set commentstring="%s:
" vim:set ts=2 sts=2 sw=2:
