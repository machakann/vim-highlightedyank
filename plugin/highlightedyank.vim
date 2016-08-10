" highlighted-yank: Make the yanked region apparent!
" Last Change: 10-Aug-2016.
" Maintainer : Masaaki Nakamura <mckn@outlook.com>

" License    : NYSL
"              Japanese <http://www.kmonos.net/nysl/>
"              English (Unofficial) <http://www.kmonos.net/nysl/index.en.html>

if exists("g:loaded_highlightedyank")
  finish
endif
let g:loaded_highlightedyank = 1

nnoremap <silent> <Plug>(highlightedyank) :<C-u>call highlightedyank#yank('n')<CR>
xnoremap <silent> <Plug>(highlightedyank) :<C-u>call highlightedyank#yank('x')<CR>
onoremap          <Plug>(highlightedyank) y

" highlight group
function! s:default_highlight() abort
  highlight default link HighlightedyankRegion IncSearch
endfunction
call s:default_highlight()

" intrinsic keymappings
noremap <Plug>(highlightedyank-y) y
noremap <Plug>(highlightedyank-g@) g@
noremap <Plug>(highlightedyank-doublequote) "

