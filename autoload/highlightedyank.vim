" highlighted-yank: Make the yanked region apparent!
" FIXME: Highlight region is incorrect when an input ^V[count]l ranges
"        multiple lines.

" variables "{{{
" null valiables
let s:null_pos = [0, 0, 0, 0]
let s:null_region = {'head': copy(s:null_pos), 'tail': copy(s:null_pos)}

" types
let s:type_num  = type(0)

" features
let s:has_gui_running = has('gui_running')
let s:has_timers = has('timers')

" SID
function! s:SID() abort
  return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_SID$')
endfunction
let s:SID = printf("\<SNR>%s_", s:SID())
delfunction s:SID

" state
let s:working = 0
"}}}

function! highlightedyank#yank(mode) abort  "{{{
  let l:count = v:count ? v:count : ''
  let register = v:register ==# '' ? '' : "\<Plug>(highlightedyank-doublequote)" . v:register
  if a:mode ==# 'n'
    call s:yank_normal(l:count, register)
  elseif a:mode ==# 'x'
    call s:yank_visual(register)
  endif
endfunction
"}}}
function! s:yank_normal(count, register) abort "{{{
  let view = winsaveview()
  let s:working = 1
  let [input, region, motionwise] = s:query(a:count)
  let s:working = 0
  if motionwise !=# ''
    let s:input = input
    let hi_group = 'HighlightedyankRegion'
    let hi_duration = s:get('highlight_duration', 1000)

    let options = s:shift_options()
    try
      let highlight = highlightedyank#highlight#new()
      call highlight.order(region, motionwise)
      if s:has_timers
        call s:glow(highlight, hi_group, hi_duration)
      else
        let input .= s:blink(highlight, hi_group, hi_duration)
      endif
    finally
      call s:restore_options(options)
      call winrestview(view)
    endtry
    let keyseq = printf('%s%s%s%s', a:register, a:count, "\<Plug>(highlightedyank-y)", input)
    call feedkeys(keyseq, 'it')
    let keyseq = printf(':call %safter_echo()%s', s:SID, "\<CR>")
    call feedkeys(keyseq, 'in')
  else
    call feedkeys(":echo ''\<CR>", 'in')
    call winrestview(view)
  endif
endfunction
"}}}
function! s:yank_visual(register) abort "{{{
  let region = {}
  let region.head = getpos("'<")
  let region.tail = getpos("'>")
  if s:is_equal_or_ahead(region.tail, region.head)
    let motionwise = visualmode()
    let hi_group = 'HighlightedyankRegion'
    let hi_duration = s:get('highlight_duration', 1000)

    let options = s:shift_options()
    try
      let input = ''
      let highlight = highlightedyank#highlight#new()
      call highlight.order(region, motionwise)
      if s:has_timers
        call s:glow(highlight, hi_group, hi_duration)
      else
        let input .= s:blink(highlight, hi_group, hi_duration)
      endif
    finally
      call s:restore_options(options)
    endtry
    let keyseq = printf('%sgv%s%s', a:register, "\<Plug>(highlightedyank-y)", input)
    call feedkeys(keyseq, 'it')
  endif
endfunction
"}}}
function! s:query(count) abort "{{{
  let curpos = getpos('.')
  let input = ''
  let region = deepcopy(s:null_region)
  let motionwise = ''
  call s:input_echo()
  while 1
    let c = getchar(0)
    if empty(c)
      sleep 20m
      continue
    endif

    let c = type(c) == s:type_num ? nr2char(c) : c
    if c ==# "\<Esc>"
      break
    endif

    let input .= c
    let [region, motionwise] = s:get_region(curpos, a:count, input)
    if motionwise !=# ''
      call s:modify_region(region)
      break
    endif
    call s:input_echo(input)
  endwhile
  return [input, region, motionwise]
endfunction
"}}}
function! s:get_region(curpos, count, input) abort  "{{{
  let s:region = deepcopy(s:null_region)
  let s:motionwise = ''
  let opfunc = &operatorfunc
  let &operatorfunc = s:SID . 'operator_get_region'
  onoremap <Plug>(highlightedyank) g@
  call setpos('.', a:curpos)
  try
    execute printf("normal %s\<Plug>(highlightedyank-g@)%s", a:count, a:input)
  catch
    let verbose = get(g:, 'highlightedyank#verbose', 0)
    echohl ErrorMsg
    if verbose >= 2
      echomsg printf('highlightedyank: Motion error. [%s] %s', a:input, v:exception)
    elseif verbose == 1
      echomsg 'highlightedyank: Motion error.'
    endif
    echohl NONE
  finally
    onoremap <Plug>(highlightedyank) y
    let &operatorfunc = opfunc
    return [s:region, s:motionwise]
  endtry
endfunction
"}}}
function! s:modify_region(region) abort "{{{
  " for multibyte characters
  if a:region.tail[2] != col([a:region.tail[1], '$']) && a:region.tail[3] == 0
    let cursor = getpos('.')
    call setpos('.', a:region.tail)
    call search('.', 'bc')
    let a:region.tail = getpos('.')
    call setpos('.', cursor)
  endif
endfunction
"}}}
function! s:operator_get_region(motionwise) abort "{{{
  let head = getpos("'[")
  let tail = getpos("']")
  if !s:is_equal_or_ahead(tail, head)
    return
  endif

  let s:region.head = head
  let s:region.tail = tail
  let s:motionwise = a:motionwise
endfunction
"}}}
function! s:blink(highlight, hi_group, duration) abort "{{{
  if a:duration != 0 && a:highlight.show(a:hi_group)
    redraw
    if a:duration > 0
      let c = s:wait_for_input(a:highlight, a:duration)
    else
      " highlight off: limit the number of highlighting region to one explicitly
      call highlightedyank#highlight#cancel()

      let id = a:highlight.persist()
      call s:cancel_if_edited(id)
      let c = ''
    endif
  endif
  return c
endfunction
"}}}
function! s:glow(highlight, hi_group, duration) abort "{{{
  if a:duration != 0 && a:highlight.show(a:hi_group)
    " highlight off: limit the number of highlighting region to one explicitly
    call highlightedyank#highlight#cancel()

    if a:duration > 0
      let id = a:highlight.scheduled_quench(a:duration)
      call timer_start(a:duration, s:SID . 'flash_echo')
      call s:cancel_if_edited(id)
    else
      let id = a:highlight.persist()
      call s:cancel_if_edited(id)
    endif
  endif
endfunction
"}}}
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
    let c = type(c) == s:type_num ? nr2char(c) : c
  endif

  return c
endfunction
"}}}
function! s:cancel_if_edited(id) abort "{{{
  execute 'augroup highlightedyank-highlight-cancel-' . a:id
    autocmd!
    execute printf('autocmd TextChanged <buffer> call %scancel_highlight(%s, "TextChanged")', s:SID, a:id)
    execute printf('autocmd InsertEnter <buffer> call %scancel_highlight(%s, "InsertEnter")', s:SID, a:id)
  augroup END
endfunction
"}}}
function! s:cancel_highlight(id, event) abort  "{{{
  let highlightlist = highlightedyank#highlight#get(a:id)
  let bufnrlist = map(deepcopy(highlightlist), 'v:val.bufnr')
  let currentbuf = bufnr('%')
  if filter(bufnrlist, 'v:val == currentbuf') != []
    let pos = a:event ==# 'TextChanged' ? getpos("'[") : getpos('.')
    for highlight in highlightlist
      if s:is_equal_or_ahead(highlight.region.tail, pos)
        call highlightedyank#highlight#cancel(a:id)
        execute 'augroup highlightedyank-highlight-cancel-' . a:id
          autocmd!
        augroup END
        break
      endif
    endfor
  endif
endfunction
"}}}
function! s:after_echo() abort  "{{{
  call s:input_echo(s:input)
endfunction
"}}}
function! s:input_echo(...) abort  "{{{
  let messages = [
        \   ['highlighted-yank', 'ModeMsg'],
        \   [': ', 'NONE'],
        \   ['Input motion/textobject', 'MoreMsg'],
        \   [': ', 'NONE'],
        \ ]
  if a:0 > 0
    let messages += [[a:1, 'Special']]
  endif
  call s:echo(messages)
endfunction
"}}}
function! s:flash_echo(...) abort  "{{{
  if !s:working
    echo ''
    redraw
  endif
endfunction
"}}}
function! s:echo(messages) abort  "{{{
  echo ''
  redraw
  for [mes, hi_group] in a:messages
    execute 'echohl ' . hi_group
    echon mes
    echohl NONE
  endfor
endfunction
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
function! s:get(name, default) abort  "{{{
  let identifier = 'highlightedyank_' . a:name
  return get(b:, identifier, get(g:, identifier, a:default))
endfunction
"}}}
function! s:is_equal_or_ahead(pos1, pos2) abort  "{{{
  return a:pos1[1] > a:pos2[1] || (a:pos1[1] == a:pos2[1] && a:pos1[2] >= a:pos2[2])
endfunction
"}}}


" vim:set foldmethod=marker:
" vim:set commentstring="%s:
" vim:set ts=2 sts=2 sw=2:
