" highlighted-yank: Make the yanked region apparent!
" Last Change: 26-Jun-2016.
" Maintainer : Masaaki Nakamura <mckn@outlook.com>

" License    : NYSL
"              Japanese <http://www.kmonos.net/nysl/>
"              English (Unofficial) <http://www.kmonos.net/nysl/index.en.html>

if exists("g:loaded_highlightedyank")
  finish
endif
let g:loaded_highlightedyank = 1

nnoremap <silent> <Plug>(highlightedyank) :<C-u>call highlightedyank#yank()<CR>
onoremap          <Plug>(highlightedyank) y

" highlight group
function! s:default_highlight() abort
  highlight default link HighlightedyankRegion IncSearch
endfunction
call s:default_highlight()

" intrinsic keymappings
nnoremap <Plug>(highlightedyank-y) y
nnoremap <Plug>(highlightedyank-g@) g@

