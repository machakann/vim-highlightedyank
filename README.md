# vim-highlightedyank
Make the yanked region apparent!

## Usage
```vim
nmap y <Plug>(highlightedyank)
omap y <Plug>(highlightedyank)
```

If you want to optimize highlight duration, use `g:highlightedyank_highlight_duration` , `b:highlightedyank_highlight_duration`. Assign number of time in milli seconds.
```vim
let g:highlightedyank_highlight_duration = 1000
```
