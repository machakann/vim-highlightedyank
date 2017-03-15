" highlighted-yank: Make the yanked region apparent!
" Last Change: 16-Mar-2017.
" Maintainer : Masaaki Nakamura <mckn@outlook.com>

" License    : NYSL
"              Japanese <http://www.kmonos.net/nysl/>
"              English (Unofficial) <http://www.kmonos.net/nysl/index.en.html>

if exists("g:loaded_highlightedyank")
  finish
endif
let g:loaded_highlightedyank = 1

function! s:keymap(...) abort
  if stridx(&cpoptions, 'y') < 0
    nnoremap <silent> <Plug>(highlightedyank) :<C-u>call highlightedyank#yank('n')<CR>
    xnoremap <silent> <Plug>(highlightedyank) :<C-u>call highlightedyank#yank('x')<CR>
    onoremap          <Plug>(highlightedyank) y
  else
    noremap  <expr>   <Plug>(highlightedyank-setoperatorfunc) highlightedyank#setoperatorfunc()
    nmap     <silent> <Plug>(highlightedyank) <Plug>(highlightedyank-setoperatorfunc)<Plug>(highlightedyank-g@)
    xmap     <silent> <Plug>(highlightedyank) <Plug>(highlightedyank-setoperatorfunc)<Plug>(highlightedyank-g@)
    onoremap          <Plug>(highlightedyank) g@
  endif
endfunction
call s:keymap()

" highlight group
function! s:default_highlight() abort
  highlight default link HighlightedyankRegion IncSearch
endfunction
call s:default_highlight()
augroup highlightedyank-event-ColorScheme
  autocmd!
  autocmd ColorScheme * call s:default_highlight()
augroup END

" intrinsic keymappings
noremap <Plug>(highlightedyank-y) y
noremap <Plug>(highlightedyank-doublequote) "
noremap <Plug>(highlightedyank-g@) g@
noremap <Plug>(highlightedyank-gv) gv

if exists('##TextYankPost') && !hasmapto('<Plug>(highlightedyank)') && !exists('g:highlightedyank_disable_autocmd')
  augroup highlightedyank
    autocmd!
    autocmd TextYankPost * silent call highlightedyank#autocmd_highlight()
  augroup END
else
  augroup highlightedyank-event-OptionSet
    autocmd!
    autocmd OptionSet cpoptions call s:keymap()
  augroup END
endif
