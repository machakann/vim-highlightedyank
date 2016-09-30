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

" SID
function! s:SID() abort
  return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_SID$')
endfunction
let s:SID = printf("\<SNR>%s_", s:SID())
delfunction s:SID

" state
let s:working = 0
let s:flash_echo_id = 0
let s:highlight_func = has('timers') ? 's:glow' : 's:blink'
"}}}

function! highlightedyank#yank(mode) abort  "{{{
  let l:count = v:count ? v:count : ''
  let register = v:register ==# s:default_register() ? '' : "\<Plug>(highlightedyank-doublequote)" . v:register
  if a:mode ==# 'n'
    call s:yank_normal(l:count, register)
  elseif a:mode ==# 'x'
    call s:yank_visual(register)
  endif
endfunction
"}}}
function! s:default_register() abort  "{{{
  if &clipboard =~# 'unnamedplus'
    let default_register = '+'
  elseif &clipboard =~# 'unnamed'
    let default_register = '*'
  else
    let default_register = '"'
  endif
  return default_register
endfunction
"}}}
function! s:yank_normal(count, register) abort "{{{
  let view = winsaveview()
  let s:working = 1
  let [input, region, motionwise] = s:query(a:count)
  let s:working = 0
  if motionwise !=# ''
    let keyseq = printf('%s%s%s%s', a:register, a:count, "\<Plug>(highlightedyank-y)", input)
    let s:input = input
    let hi_group = 'HighlightedyankRegion'
    let hi_duration = s:get('highlight_duration', 1000)

    let errmsg = ''
    let options = s:shift_options()
    try
      let highlight = highlightedyank#highlight#new()
      call highlight.order(region, motionwise)
      if hi_duration < 0
        let keyseq .= s:persist(highlight, hi_group)
      elseif hi_duration > 0
        let keyseq .= {s:highlight_func}(highlight, hi_group, hi_duration)
      endif
    catch
      let errmsg = printf('highlightedyank: Unanticipated error. [%s] %s', v:throwpoint, v:exception)
    finally
      call s:restore_options(options)
      call winrestview(view)
      call feedkeys(keyseq, 'itx')

      if errmsg !=# ''
        echoerr errmsg
      endif
    endtry
  else
    normal! :
    call winrestview(view)
  endif
endfunction
"}}}
function! highlightedyank#autocmd_highlight() abort "{{{
  let view = winsaveview()
  let region = {}
  let region.head = getpos("'[")
  let region.tail = getpos("']")
  let char = getline(region.tail[1])[region.tail[2] - 1]
  let linecontent = v:event.regcontents[len(v:event.regcontents) - 1]
  let tailchar = linecontent[len(linecontent) - 1]
  if char != tailchar
    let region.tail[2] = region.tail[2] - 1
  endif
  if v:event.regtype == 'v'
    let motionwise = 'char'
  elseif v:event.regtype == 'V'
    let motionwise = 'line'
  elseif v:event.regtype =~ "\<c-v>"
    let motionwise = 'block'
  else
    let motionwise = ''
  endif
  if motionwise !=# ''
    call s:modify_region(region)
    let hi_group = 'HighlightedyankRegion'
    let hi_duration = s:get('highlight_duration', 1000)

    let errmsg = ''
    let options = s:shift_options()
    try
      let highlight = highlightedyank#highlight#new()
      call highlight.order(region, motionwise)
      if hi_duration < 0
        call s:persist(highlight, hi_group)
      elseif hi_duration > 0
        call {s:highlight_func}(highlight, hi_group, hi_duration)
      endif
    catch
      let errmsg = printf('highlightedyank: Unanticipated error. [%s] %s', v:throwpoint, v:exception)
    finally
      call s:restore_options(options)

      if errmsg !=# ''
        echoerr errmsg
      endif
    endtry
  else
    normal! :
  endif
endfunction
"}}}
function! s:yank_visual(register) abort "{{{
  let view = winsaveview()
  let region = {}
  let region.head = getpos("'<")
  let region.tail = getpos("'>")
  if s:is_equal_or_ahead(region.tail, region.head)
    let keyseq = printf('%s%s', a:register, "\<Plug>(highlightedyank-y)")
    let motionwise = visualmode()
    let hi_group = 'HighlightedyankRegion'
    let hi_duration = s:get('highlight_duration', 1000)

    let options = s:shift_options()
    try
      let highlight = highlightedyank#highlight#new()
      call highlight.order(region, motionwise)
      if hi_duration < 0
        let keyseq .= s:persist(highlight, hi_group)
      elseif hi_duration > 0
        let keyseq .= {s:highlight_func}(highlight, hi_group, hi_duration)
      endif
    finally
      call s:restore_options(options)

      " NOTE: countermeasure for flickering.
      normal! gv
      if line('.') != view.lnum
        normal! o
      endif
      if line('.') == view.lnum && col('.') - 1 == view.col
        call winrestview(view)
      endif
      call feedkeys(keyseq, 'itx')
    endtry
  endif
endfunction
"}}}
function! s:query(count) abort "{{{
  let curpos = getpos('.')
  let input = ''
  let region = deepcopy(s:null_region)
  let motionwise = ''
  let dummycursor = s:put_dummy_cursor(curpos)
  try
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
      call s:input_echo(input)
      if motionwise !=# ''
        call s:modify_region(region)
        break
      endif
    endwhile
  finally
    call s:clear_dummy_cursor(dummycursor)
  endtry
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
function! s:put_dummy_cursor(curpos) abort "{{{
  let dummycursor = highlightedyank#highlight#new()
  if hlexists('Cursor')
    call dummycursor.order({'head': a:curpos, 'tail': a:curpos}, 'v')
    call dummycursor.show('Cursor')
    redraw
  endif
  return dummycursor
endfunction
"}}}
function! s:clear_dummy_cursor(dummycursor) abort  "{{{
  call a:dummycursor.quench()
endfunction
"}}}
function! s:persist(highlight, hi_group) abort  "{{{
  if a:highlight.show(a:hi_group)
    " highlight off: limit the number of highlighting region to one explicitly
    call highlightedyank#highlight#cancel()

    let id = a:highlight.persist()
    call s:cancel_if_edited(id)
  endif
  return ''
endfunction
"}}}
function! s:blink(highlight, hi_group, duration) abort "{{{
  let key = ''
  if a:highlight.show(a:hi_group)
    redraw
    let key = s:wait_for_input(a:highlight, a:duration)
  endif
  return key
endfunction
"}}}
function! s:glow(highlight, hi_group, duration) abort "{{{
  if a:highlight.show(a:hi_group)
    " highlight off: limit the number of highlighting region to one explicitly
    call highlightedyank#highlight#cancel()

    let id = a:highlight.scheduled_quench(a:duration)
    if s:flash_echo_id > 0
      call timer_stop(s:flash_echo_id)
    endif
    let s:flash_echo_id = timer_start(a:duration, s:SID . 'flash_echo')
    call s:cancel_if_edited(id)
  endif
  return ''
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
    for highlight in highlightlist
      if s:highlight_off_by_{a:event}(highlight)
        call highlightedyank#highlight#cancel(a:id)
        break
      endif
    endfor
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
  if !s:working && mode() !~# '[cr!]'
    echo ''
    let s:flash_echo_id = 0
  endif
endfunction
"}}}
function! s:echo(messages) abort  "{{{
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
