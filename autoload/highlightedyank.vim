" highlighted-yank: Make the yanked region apparent!
" FIXME: Highlight region is incorrect when an input ^V[count]l ranges
"        multiple lines.
let s:Const = highlightedyank#constant#import()
let s:Feature = s:Const.Feature
let s:Type = s:Const.Type
let s:NULLREGION = s:Const.NULLREGION
let s:MAXCOL = s:Const.MAXCOL
let s:ON = 1
let s:OFF = 0

let s:STATE = s:ON
function! highlightedyank#autocmd_highlight() abort "{{{
  if s:STATE is s:OFF
    return
  endif
  let operator = v:event.operator
  let regtype = v:event.regtype
  let regcontents = v:event.regcontents
  if operator !=# 'y' || regtype ==# ''
    return
  endif

  let view = winsaveview()
  let region = s:derive_region(regtype, regcontents)
  call s:modify_region(region)
  call s:highlight_yanked_region(region)
  call winrestview(view)
endfunction "}}}
function! highlightedyank#on() abort "{{{
  let s:STATE = s:ON
endfunction "}}}
function! highlightedyank#off() abort "{{{
  let s:STATE = s:OFF
endfunction "}}}
function! highlightedyank#toggle() abort "{{{
  if s:STATE is s:ON
    call highlightedyank#off()
  else
    call highlightedyank#on()
  endif
endfunction "}}}
function! s:derive_region(regtype, regcontents) abort "{{{
  if a:regtype ==# 'v'
    let region = s:derive_region_char(a:regcontents)
  elseif a:regtype ==# 'V'
    let region = s:derive_region_line(a:regcontents)
  elseif a:regtype[0] ==# "\<C-v>"
    let width = str2nr(a:regtype[1:])
    let region = s:derive_region_block(a:regcontents, width)
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
  return region
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
function! s:derive_region_block(regcontents, width) abort "{{{
  let len = len(a:regcontents)
  if len == 0
    return deepcopy(s:NULLREGION)
  endif

  let curpos = getpos('.')
  let region = deepcopy(s:NULLREGION)
  let region.wise = 'block'
  let region.head = getpos("'[")
  call setpos('.', region.head)
  if len > 1
    execute printf('normal! %sj', len - 1)
  endif
  execute printf('normal! %s|', virtcol('.') + a:width - 1)
  let region.tail = getpos('.')
  let region.blockwidth = a:width
  if strdisplaywidth(getline('.')) < a:width
    let region.blockwidth = s:MAXCOL
  endif
  call setpos('.', curpos)
  return region
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
function! s:highlight_yanked_region(region) abort "{{{
  let maxlinenumber = s:get('max_lines', 10000)
  if a:region.tail[1] - a:region.head[1] + 1 > maxlinenumber
    return
  endif

  let keyseq = ''
  let hi_group = 'HighlightedyankRegion'
  let hi_duration = s:get('highlight_duration', 1000)
  let timeout = s:get('timeout', 1000)
  let highlight = highlightedyank#highlight#new(a:region, timeout)
  if highlight.empty()
    return
  endif
  if hi_duration < 0
    call s:persist(highlight, hi_group)
  elseif hi_duration > 0
    if s:Feature.TIMERS
      call s:glow(highlight, hi_group, hi_duration)
    else
      let keyseq = s:blink(highlight, hi_group, hi_duration)
      call feedkeys(keyseq, 'it')
    endif
  endif
endfunction "}}}
function! s:persist(highlight, hi_group) abort  "{{{
  call highlightedyank#highlight#cancel()
  if a:highlight.show(a:hi_group)
    call a:highlight.persist()
  endif
endfunction "}}}
function! s:blink(highlight, hi_group, duration) abort "{{{
  let key = ''
  if a:highlight.show(a:hi_group)
    redraw
    let key = s:wait_for_input(a:highlight, a:duration)
  endif
  return key
endfunction "}}}
function! s:glow(highlight, hi_group, duration) abort "{{{
  call highlightedyank#highlight#cancel()
  if a:highlight.show(a:hi_group)
    call a:highlight.quench_timer(a:duration)
  endif
endfunction "}}}
function! s:wait_for_input(highlight, duration) abort  "{{{
  let clock = highlightedyank#clock#new()
  try
    let c = 0
    call clock.start()
    while empty(c)
      let c = getchar(0)
      if clock.started && clock.elapsed() > a:duration
        break
      endif
      sleep 20m
    endwhile
  finally
    call a:highlight.quench()
    call clock.stop()
  endtry

  if c == 0
    let c = ''
  else
    let c = type(c) == s:Type.NUM ? nr2char(c) : c
  endif
  return c
endfunction "}}}
function! s:get(name, default) abort  "{{{
  let identifier = 'highlightedyank_' . a:name
  return get(b:, identifier, get(g:, identifier, a:default))
endfunction "}}}

" vim:set foldmethod=marker:
" vim:set commentstring="%s:
" vim:set ts=2 sts=2 sw=2:
