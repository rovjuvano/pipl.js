# PIPL - Pi-Calculus Programming Library - prototype demo

The demo is a [meteor](http://www.meteor.com/) app (~ 0.6.6.3).

Demo may be available at [pipl-demo.meteor.com](http://pipl-demo.meteor.com/).


## Grammar

    S := sequence
    sequence := ( ( send | read ) '.' )+ sequence_end
    sequence_end := '()' | parallel | choice
    parallel := new_names? '(|' sequence+ )
    choice := new_names? '(+' sequence+ )
    send =: '! '? new_names? name '(' names? ')'
    read =: '! '? new_names? name '[' names? ']'
    new_names := '[' names ']'
    names := name ( ','? name)*

## Reduction Rules

Given processes P, Q and names a, b, c

### communication
    c(a).P
    c[b].Q
reduces to

    P
    Q
where 'b' is bound to 'a' in process Q

### choice
    (+
      a()
      b[]
    )
    b().P
reduces to

    P

### new names
    [a]c().a[]
    c[].a()
reduces to

    a'[]
    a()

## Compiling Parser
Use [PEG.js](http://pegjs.majda.cz/).

    npm install -g pegjs
    pegjs -e PIPL_Parser lib/pipl.pegjs lib/pipl.pegjs.js

#### LICENSE AND COPYRIGHT

Copyright (C) 2013-2014 Robert Juliano

This program is free software; you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation; either version 3 of the License, or (at your option) any later version.
