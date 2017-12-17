# vim-highlightedyank
Make the yanked region apparent!

## Usage

### If you are using Neovim or Vim 8.0.1394 (or later version),
there is no need for configuration, as the highlight event is automatically triggered by the TextYankPost event.

### If you are using older Vim,

define a keymapping to `<Plug>(highlightedyank)`. It would be good to check the existence of |TextYankPost| event.

```vim
if !exists('##TextYankPost')
  map y <Plug>(highlightedyank)
endif
```

## Optimizing highlight duration

If you want to optimize highlight duration, use `g:highlightedyank_highlight_duration` or `b:highlightedyank_highlight_duration`. Assign number of time in milli seconds.

```vim
let g:highlightedyank_highlight_duration = 1000
```

If a negative number is assigned, the highlight would get persistent.

```vim
let g:highlightedyank_highlight_duration = -1
```

When a new text is yanked, the old highlighting would be deleted. Or when
former lines are edited, the highlighting would be deleted to prevent shifting
the position, also.

## Highlight coloring

If for some reason the highlight is not visible you can redefine the
`HighlightedyankRegion` highlight group like so:

```
hi HighlightedyankRegion cterm=reverse gui=reverse
```

## Demo
![vim-highlightedyank](http://i.imgur.com/HulyZ6n.gif)
