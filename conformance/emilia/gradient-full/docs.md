# gradient-full

A full gradient is a direction and two or three stops in one list:

**Token order is load-bearing here**, and deliberately so. `Via` writes a
three-stop list and `From` a two-stop one; whichever is listed LAST wins, which
is how a `From` + `Via` + `Stop` triple ends up with the three-colour list.
`Stop` writes no list at all — if it did, it would overwrite `Via`'s.
