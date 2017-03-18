" highlighted-yank: Make the yanked region apparent!
" FIXME: Highlight region is incorrect when an input ^V[count]l ranges
"        multiple lines.

" variables "{{{
" null valiables
let s:null_pos = [0, 0, 0, 0]
let s:null_region = {'wise': '', 'head': copy(s:null_pos), 'tail': copy(s:null_pos), 'blockwidth': 0}

" constants
let s:maxcol = 2147483647

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

" intrinsic keymap
let s:normal = {}
let s:normal['y']  = "\<Plug>(highlightedyank-y)"
let s:normal['"']  = "\<Plug>(highlightedyank-doublequote)"
let s:normal['g@'] = "\<Plug>(highlightedyank-g@)"
let s:normal['gv'] = "\<Plug>(highlightedyank-gv)"
"}}}

function! highlightedyank#yank(mode) abort  "{{{
  let l:count = v:count ? v:count : ''
  let register = v:register ==# s:default_register() ? '' : s:normal['"'] . v:register
  if a:mode ==# 'n'
    call s:yank_normal(l:count, register)
  elseif a:mode ==# 'x'
    call s:yank_visual(register)
  endif
endfunction
"}}}
function! highlightedyank#setoperatorfunc() abort "{{{
  set operatorfunc=highlightedyank#operatorfunc
  return ''
endfunction
"}}}
function! highlightedyank#operatorfunc(motionwise, ...) abort "{{{
  let region = {'head': getpos("'["), 'tail': getpos("']"), 'wise': a:motionwise}
  if s:is_ahead(region.head, region.tail)
    return
  endif

  let register = v:register ==# s:default_register() ? '' : '"' . v:register
  execute printf('normal! `[%sy%s`]', register, s:motionwise2visualmode(a:motionwise))
  call s:highlight_yanked_region(region)
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
  let options = s:shift_options()
  try
    let [input, region] = s:query(a:count)
    if region != s:null_region
      call s:highlight_yanked_region(region)
      call winrestview(view)
      let keyseq = printf('%s%s%s%s', a:register, a:count, s:normal['y'], input)
      call feedkeys(keyseq, 'itx')
    endif
  finally
    call s:restore_options(options)
  endtry
endfunction
"}}}
function! s:yank_visual(register) abort "{{{
  let view = winsaveview()
  let region = deepcopy(s:null_region)
  let region.head = getpos("'<")
  let region.tail = getpos("'>")
  if s:is_ahead(region.head, region.tail)
    return
  endif

  let region.wise = s:visualmode2motionwise(visualmode())
  if region.wise ==# 'block'
    let region.blockwidth = s:is_extended() ? s:maxcol : virtcol(region.tail[1:2]) - virtcol(region.head[1:2]) + 1
  endif
  let options = s:shift_options()
  try
    call s:highlight_yanked_region(region)
    call winrestview(view)
    let keyseq = printf('%s%s%s', s:normal['gv'], a:register, s:normal['y'])
    call feedkeys(keyseq, 'itx')
  finally
    call s:restore_options(options)
  endtry
endfunction
"}}}
function! s:query(count) abort "{{{
  let view = winsaveview()
  let curpos = getpos('.')
  let input = ''
  let region = deepcopy(s:null_region)
  let motionwise = ''
  let dummycursor = s:put_dummy_cursor(curpos)
  try
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
      let region = s:get_region(curpos, a:count, input)
      if region != s:null_region
        break
      endif
    endwhile
  finally
    call s:clear_dummy_cursor(dummycursor)
    call winrestview(view)
  endtry
  return [input, region]
endfunction
"}}}
function! s:get_region(curpos, count, input) abort  "{{{
  let s:region = deepcopy(s:null_region)
  let opfunc = &operatorfunc
  let &operatorfunc = s:SID . 'operator_get_region'
  onoremap <Plug>(highlightedyank) g@
  call setpos('.', a:curpos)
  try
    execute printf("normal %s%s%s", a:count, s:normal['g@'], a:input)
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
    if s:region == s:null_region
      return deepcopy(s:null_region)
    endif
    return s:modify_region(s:region)
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
  return a:region
endfunction
"}}}
function! s:operator_get_region(motionwise) abort "{{{
  let head = getpos("'[")
  let tail = getpos("']")
  if s:is_ahead(head, tail)
    return
  endif

  let s:region.head = head
  let s:region.tail = tail
  let s:region.wise = a:motionwise
endfunction
"}}}
function! s:put_dummy_cursor(curpos) abort "{{{
  if !hlexists('Cursor')
    return {}
  endif
  let pos = {'head': a:curpos, 'tail': a:curpos, 'wise': 'char'}
  let dummycursor = highlightedyank#highlight#new(pos)
  call dummycursor.show('Cursor')
  redraw
  return dummycursor
endfunction
"}}}
function! s:clear_dummy_cursor(dummycursor) abort  "{{{
  if empty(a:dummycursor)
    return
  endif
  call a:dummycursor.quench()
endfunction
"}}}
function! s:highlight_yanked_region(region) abort "{{{
  let keyseq = ''
  let hi_group = 'HighlightedyankRegion'
  let hi_duration = s:get('highlight_duration', 1000)
  let highlight = highlightedyank#highlight#new(a:region)
  if hi_duration < 0
    call s:persist(highlight, hi_group)
  elseif hi_duration > 0
    if s:has_timers
      call s:glow(highlight, hi_group, hi_duration)
    else
      let keyseq = s:blink(highlight, hi_group, hi_duration)
      call feedkeys(keyseq, 'it')
    endif
  endif
endfunction
"}}}
function! s:persist(highlight, hi_group) abort  "{{{
  " highlight off: limit the number of highlighting region to one explicitly
  call highlightedyank#highlight#cancel()

  if a:highlight.show(a:hi_group)
    call a:highlight.persist()
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
  " highlight off: limit the number of highlighting region to one explicitly
  call highlightedyank#highlight#cancel()
  if a:highlight.show(a:hi_group)
    call a:highlight.quench_timer(a:duration)
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
function! s:is_ahead(pos1, pos2) abort  "{{{
  return a:pos1[1] > a:pos2[1] || (a:pos1[1] == a:pos2[1] && a:pos1[2] > a:pos2[2])
endfunction
"}}}
function! s:escape(string) abort  "{{{
  return escape(a:string, '~"\.^$[]*')
endfunction
"}}}
function! s:is_extended() abort "{{{
  " NOTE: This function should be used only when you are sure that the
  "       keymapping is used in visual mode.
  normal! gv
  let extended = winsaveview().curswant == s:maxcol
  execute "normal! \<Esc>"
  return extended
endfunction
"}}}
function! s:visualmode2motionwise(visualmode) abort "{{{
  if a:visualmode ==# 'v'
    let motionwise = 'char'
  elseif a:visualmode ==# 'V'
    let motionwise = 'line'
  elseif a:visualmode[0] ==# "\<C-v>"
    let motionwise = 'block'
  else
    let motionwise = a:visualmode
  endif
  return motionwise
endfunction
"}}}
function! s:motionwise2visualmode(motionwise) abort "{{{
  if a:motionwise ==# 'char'
    let visualmode = 'v'
  elseif a:motionwise ==# 'line'
    let visualmode = 'V'
  elseif a:motionwise[0] ==# 'block'
    let visualmode = "\<C-v>"
  else
    let visualmode = a:motionwise
  endif
  return visualmode
endfunction
"}}}

" for neovim
function! highlightedyank#autocmd_highlight() abort "{{{
  if v:event.operator !=# 'y' || v:event.regtype ==# ''
    return
  endif

  let view = winsaveview()
  let region = s:derive_region(v:event.regtype, v:event.regcontents)
  call s:modify_region(region)
  call s:highlight_yanked_region(region)
  call winrestview(view)
endfunction
"}}}
function! s:derive_region(regtype, regcontents) abort "{{{
  if a:regtype ==# 'v'
    let region = s:derive_region_char(a:regcontents)
  elseif a:regtype ==# 'V'
    let region = s:derive_region_line(a:regcontents)
  elseif a:regtype[0] ==# "\<C-v>"
    let width = str2nr(a:regtype[1:])
    let region = s:derive_region_block(a:regcontents, width)
  else
    let region = deepcopy(s:null_region)
  endif
  return region
endfunction
"}}}
function! s:derive_region_char(regcontents) abort "{{{
  let len = len(a:regcontents)
  let region = {}
  let region.wise = 'char'
  let region.head = getpos("'[")
  let region.tail = copy(region.head)
  if len == 0
    let region = deepcopy(s:null_region)
  elseif len == 1
    let region.tail[2] += strlen(a:regcontents[0]) - 1
  else
    let region.tail[1] += len - 1
    let region.tail[2] = strlen(a:regcontents[-1])
  endif
  return region
endfunction
"}}}
function! s:derive_region_line(regcontents) abort "{{{
  let region = {}
  let region.wise = 'line'
  let region.head = getpos("'[")
  let region.tail = getpos("']")
  return region
endfunction
"}}}
function! s:derive_region_block(regcontents, width) abort "{{{
  let len = len(a:regcontents)
  let region = deepcopy(s:null_region)
  if len > 0
    let curpos = getpos('.')
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
      let region.blockwidth = s:maxcol
    endif
    call setpos('.', curpos)
  endif
  return region
endfunction
"}}}

" vim:set foldmethod=marker:
" vim:set commentstring="%s:
" vim:set ts=2 sts=2 sw=2:
