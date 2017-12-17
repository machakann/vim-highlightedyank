" constant object - holding constants

function! highlightedyank#constant#import() abort "{{{
  return s:const
endfunction "}}}

unlet! s:const
let s:const = {}
let s:const.NULLPOS = [0, 0, 0, 0]
let s:const.NULLREGION = {'wise': '', 'head': copy(s:const.NULLPOS), 'tail': copy(s:const.NULLPOS), 'blockwidth': 0}
let s:const.MAXCOL = 2147483647

let s:Feature = {}
let s:Feature.GUI_RUNNING = has('gui_running')
let s:Feature.TIMERS = has('timers')
let s:const.Feature = s:Feature

let s:Type = {}
if exists('v:t_number')
  let s:Type.STR = v:t_string
  let s:Type.NUM = v:t_number
  let s:Type.LIST = v:t_list
  let s:Type.DICT = v:t_dict
  let s:Type.FLOAT = v:t_float
  let s:Type.FUNC = v:t_func
else
  let s:Type.STR = type('')
  let s:Type.NUM = type(0)
  let s:Type.LIST = type([])
  let s:Type.DICT = type({})
  let s:Type.FLOAT = type(0.0)
  let s:Type.FUNC = type(function('tr'))
endif
let s:const.Type = s:Type
lockvar! s:const

" vim:set foldmethod=marker:
" vim:set commentstring="%s:
" vim:set ts=2 sts=2 sw=2:

