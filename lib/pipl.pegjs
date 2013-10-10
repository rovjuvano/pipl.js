// example PIPL code
par(two).(
abc(xyz).xyz[abc]
| abc[xyz].xyz(abc)
| lmn[xyz].xyz(lmn).()
| lmn[qrs].qrs(lmn)
)
| par[three]
| xyx(123).1[xyz].(
  mko(1nji)
 .ctf(8vgy)
+ !nji[ 2bhu ]
 .bhu(9vgy ).
  vgy( 5cft)
 . ! hang(ten)
+ zse(3xdr).fas{}df(0).a!sdf(word)
)

// PEG.js grammar for PIPL
{
send = function(channel, name, repeat) {
  return('send' + repeat + '(' + channel + ',' + name +')');
  return {
    class:  'Send',
    channel: channel,
    name:    name,
    repeat:  !!repeat
  };
};
read = function(channel, name, repeat) {
  return('read' + repeat + '(' + channel + ',' + name +')');
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
}

start = _ p:parallel _ {return p}

sequence
  = r:prefix* l:step { return sequence(r, l) }
  / r:prefix+ '(' _ l:(parallel / choice)? _ ')' { return sequence(r, l) }

prefix
  = s:step _ '.' _ {return s}

step
  = r:'!'? c:name '(' n:name ')' { return send(c, n, r) }
  / r:'!'? c:name '[' n:name ']' { return read(c, n, r) }

parallel
  = f:sequence r:( _ '|' _ s:sequence {return s} )+ { return parallel(f, r) }

choice
  = f:sequence r:( _ '+' _ s:sequence {return s} )+ { return choice(f, r) }

name 'identifier'
  = _ f:name_first r:name_rest* _ { return f + r.join("") }

name_first = [^()\[\] \t\r\n\0-\x1F\x7f!]
name_rest  = [^()\[\] \t\r\n\0-\x1F\x7f]
_ 'whitespace' = [ \t\r\n]*
