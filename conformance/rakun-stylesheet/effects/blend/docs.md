# blend

{src/main.bp}

#### Blend modes

`mix-blend-mode` blends an element with what is **behind** it;
`background-blend-mode` blends an element's own background layers with **each
other**. `§ 12.5` says in one sentence that the two take the same seventeen
values, which is why they are two sub-sections of one section.

The two value tables are written twice, because two enum types cannot share a
`case`. A test strips the property name off each side and asserts the seventeen
values are **equal, in order**, so a typo in one and not the other reddens here
rather than in a browser.
