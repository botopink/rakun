A `Boundary` pairs an id, a fallback element and an unstarted thunk. `Suspense`
renders the fallback inside `<div data-jh-h="…">`; `resolve` awaits the child once
and `fillHtml` writes the fill — a `<template data-jh-f>` and the script that
moves it into place.
