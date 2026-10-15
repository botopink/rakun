# layout-overflow-z

{src/main.bp}

#### Overflow, overscroll, visibility, z-index, isolation

Two of these are places a transcription slips, so each has its own assertion:
`invisible` is the **utility** name and `hidden` is the **CSS value**, and `Z`
is the one numeric family in `Layout` that is **not a length** — `z-50` is the
bare integer `50`, never a `calc` and never a `rem`.
