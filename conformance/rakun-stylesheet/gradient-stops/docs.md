# gradient-stops

#### The stops

`From`, `Via` and `Stop` each carry the **whole of front 33's grid** — the 26
families over eleven shades, plus `White`, `Black`, `Transparent`, `Current`
and `Inherit`. The colour half is `paletteVar(family, shade)`, the same
function `.Bg.Color.*` calls, so a stop and a background reference ONE custom
property by construction:

A full gradient is a direction and two or three stops in one list:
