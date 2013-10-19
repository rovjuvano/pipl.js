/* example PIPL code
par(two).
(|
  abc(xyz).xyz[abc] . ()
  [one two]one(two).two[three] . ()
  AB(xy).[three]CD(vw).EF[tu] . ()
  abc[xyz] .xyz(abc) . ()
  lmn[xyz]. xyz(lmn) . ()
  lmn[qrs].qrs(lmn).[one two](| a(b).b[c].() x(y).y[z].() )
  lmn[ qrs].qrs(lmn) . ()
  lmn[qrs ].qrs(lmn) . ()
  lmn[qrs].qrs( lmn) . ()
  lmn[qrs].qrs(lmn ) . ()
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
  mko(1nji).ctf(8vgy) . ()
 ! nji[ 2bhu ].bhu(9vgy ).vgy( 5cft).! hang(ten) . ()
 zse(3xdr).fas{}df(0).a!sdf(word) . ()
)
[a,b].x(c,d,e).[one two three].y[].z( hay, bay ,say , way day ) . ()

*/
// PEG.js grammar for PIPL
{
var Send = (function() {
  function Send(channel, names, repeat, new_names) {
    this.channel = channel;
    this.names = names;
    this.repeat = repeat;
    this.new_names = new_names;
  }
  Send.prototype.enter = function(p) {
    var s;
    if (this.names.length > 1) {
      var channel = '__' + this.channel;
      new_names = this.new_names || [];
      new_names.push(channel);
      s = p.send(this.channel, channel, this.repeat, new_names);
      this.names.forEach(function(name) {
        s = s.send(channel, name, false, null);
      });
    }
    else {
      var name = this.names.length > 0 ? this.names[0] : '';
      s = p.send(this.channel, name, this.repeat, this.new_names);
    }
    return s;
  }
  return Send;
})();

var Read = (function() {
  function Read(channel, names, repeat, new_names) {
    this.channel = channel;
    this.names = names;
    this.repeat = repeat;
    this.new_names = new_names;
  }
  Read.prototype.enter = function(p) {
    var s;
    if (this.names.length > 1) {
      var channel = '__' + this.channel;
      s = p.read(this.channel, channel, this.repeat, this.new_names);
      this.names.forEach(function(name) {
        s = s.read(channel, name, false, null);
      });
    }
    else {
      var name = this.names.length > 0 ? this.names[0] : '';
      s = p.read(this.channel, name, this.repeat, this.new_names);
    }
    return s;
  }
  return Read;
})();

var Sequence = (function() {
  function Sequence(rest, last) {
    if (last)
      rest.push(last);
    this.items = rest;
  }
  Sequence.prototype.enter = function(p) {
    var s = this.items[0].enter(p);
    for (var i=1; i<this.items.length; i++) {
      if (this.items[i].enter)
        s = this.items[i].enter(s);
    }
    return s;
  };
  return Sequence;
})();

var Parallel = (function() {
  function Parallel(items, new_names, start) {
    this.items = items;
    this.new_names = new_names;
    this.start = start;
  }
  Parallel.prototype.enter = function(p) {
    var s = this.start ? p : p.parallel(this.new_names);
    for (var i=0; i<this.items.length; i++) {
      this.items[i].enter(s);
    }
  };
  return Parallel;
})();

var Choice = (function() {
  function Choice(items, new_names, start) {
    this.items = items;
    this.new_names = new_names;
  }
  Choice.prototype.enter = function(p) {
    var s = p.choice(this.new_names);
    for (var i=0; i<this.items.length; i++) {
      this.items[i].enter(s);
    }
  };
  return Choice;
})();
}

start = s:_sequence+ _ { return new Parallel(s, null, true) }

_sequence
 = _ s:sequence {return s}

sequence
  = r:prefix_+ l:sequence_end { return new Sequence(r, l) }

sequence_end
  = '(' _ ')' / l:(parallel / choice) {return l}

prefix_
  = s:step _ '.' _ {return s}

step = send / read
send = r:replicate_? nn:new_names_? c:name _ '(' _ n:names? _ ')' { return new Send(c, n, r, nn) }
read = r:replicate_? nn:new_names_? c:name _ '[' _ n:names? _ ']' { return new Read(c, n, r, nn) }

parallel
  = nn:new_names_? '(' _ '|' s:_sequence+ _ ')' { return new Parallel(s, nn) }

choice
  = nn:new_names_? '(' _ '+' s:_sequence+ _ ')' { return new Choice(s, nn) }

new_names_
  = '[' _ n:names? _ ']' _ {return n}

replicate_ = b:'!' (whitespace+ / &'[') {return true}

names
  = f:name r:_name* { r.unshift(f); return r }

_name = _ ','? _ n:name {return n}

name 'identifier'
  = c:name_char+ { return c.join('') }

name_char = [^()\[\], \t\r\n\0-\x1F\x7f]
whitespace 'whitespace' = [ \t\r\n]
_ = whitespace*
