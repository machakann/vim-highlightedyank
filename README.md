# vim-highlightedyank
Make the yanked region apparent!

## Usage
```vim
map y <Plug>(highlightedyank)
```

If you use Neovim, there is no need for configuration, as the highlight event is automatically triggered by the TextYankPost event.

If you want to optimize highlight duration, use `g:highlightedyank_highlight_duration` , `b:highlightedyank_highlight_duration`. Assign number of time in milli seconds.
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
