// example PIPL code

par(two).
(|
  abc(xyz).xyz[abc]
  [one].[two].one(two).two[three]
  AB(xy).[three].CD(vw).EF[tu]
  abc[xyz] .xyz(abc)
  lmn[xyz]. xyz(lmn)
  lmn[qrs].qrs(lmn).[one].[two].(| a(b).b[c] x(y).y[z] )
  lmn[ qrs].qrs(lmn)
  lmn[qrs ].qrs(lmn)
  lmn[qrs].qrs( lmn)
  lmn[qrs].qrs(lmn )
  lmn[qrs].qrs(lmn).( )
  lmn [ qrs ] . qrs ( lmn ) . ( )

lmn
[
qrs
]
.
qrs
(
lmn
)
.
(
)
)
par[three].
xyx(123).1[xyz].
(+
  mko(1nji).ctf(8vgy)
 !nji[ 2bhu ].bhu(9vgy ).vgy( 5cft).!hang(ten)
 zse(3xdr).fas{}df(0).a!sdf(word)
)
[a,b].x(c,d,e).[one two three].y[].z( hay, bay ,say , way day )

// PEG.js grammar for PIPL
{
send = function(channel, names, repeat) {
  return('send' + repeat + '(' + channel + ', ' + names.join(', ') +')');
  return {
    class:  'Send',
    channel: channel,
    name:    name,
    repeat:  !!repeat
  };
};
read = function(channel, names, repeat) {
  names = names || ['null'];
  return('read' + repeat + '(' + channel + ', ' + names.join(', ') +')');
  return {
    class:  'Read',
    channel: channel,
    name:    name,
    repeat:  !!repeat
  };
};
sequence = function(rest, last) {
  rest.unshift('.');
  rest.push(last);
  return rest;
};

parallel = function(first, rest) {
  rest.unshift('|', first);
  return rest;
};
choice = function(first, rest) {
  rest.unshift('+', first);
  return rest;
};
new_name = function(names, block) {
  return [names, block];
};
}

start = _ f:sequence r:_sequence+ _ { return parallel(f, r) }

_sequence
 = _ s:sequence {return s}

sequence
  = r:prefix_+ l:sequence_end { return sequence(r, l) }

sequence_end
  = l:read / l:send / '(' _ l:(parallel / choice)? _ ')' {return l}

prefix_
  = s:step _ '.' _ {return s}

step = var / send / read
var  = '[' _ n:names _ ']' { return read(null, n, '') }
send = r:bang_? c:name _ '(' _ n:names _ ')' { return send(c, n, r) }
read = r:bang_? c:name _ '[' _ n:names? _ ']' { return read(c, n, r) }

bang_ = l:'!' _ {return l}

parallel
  = '|' _ f:sequence r:_sequence+ { return parallel(f, r) }

choice
  = '+' _ f:sequence r:_sequence+ { return choice(f, r) }

names
  = f:name r:_name* { r.unshift(f); return r }

_name = _ ','? _ n:name {return n}

name 'identifier'
  = f:name_first r:name_rest* { return f + r.join("") }

name 'identifier'
  = f:name_first r:name_rest* { return f + r.join("") }

name_first = [^()\[\], \t\r\n\0-\x1F\x7f!]
name_rest  = [^()\[\], \t\r\n\0-\x1F\x7f]
_ 'whitespace' = [ \t\r\n]*
