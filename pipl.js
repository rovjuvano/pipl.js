if (!Meteor.isClient) {
  return;
}

Handlebars.registerHelper('log', function(msg) {
  console.log(msg);
});

var getPipl = function() {
    if (!window.last_pipl || $('#reset').is(':checked')) {
      var pipl = new Pipl();
      add_print(pipl);
      add_math_functions(pipl);
      window.last_pipl = pipl;
    }
    return window.last_pipl;
}
var run = function() {
  var code = $('#subject').val();
  try {
    var ast = PIPL_Parser.parse(code);
    var pipl = getPipl();
    ast.enter(pipl);
    $('#result').removeClass('error').empty();
    pipl.run();
  } catch (e) {
    msg = "Line " + e.line + ", column " + e.column + ": " + e.message;
    $('#result').addClass('error').text(msg);
  }
};

var add_print = function(pipl) {
  var REFS = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  pipl
    .read('print', REFS, true)
    .call(function(refs) {
      var text = REFS.map(function(ref) { return refs.get(ref) }).join(' ');
      $('#result').append($('<li></li>').text(text));
  });
};

add_math_functions = function(pipl) {
  var _add_4 = function(n, f) {
    pipl
      .read(n, ['a', 'b', 'out'], true)
      .call(function(refs) {
        var result = f(+refs.get('a'), +refs.get('b'));
        refs.set('__', result);
      })
      .send('out', '__');
  };
  _add_4('+', function(a, b) { return a + b; });
  _add_4('-', function(a, b) { return a - b; });
  _add_4('*', function(a, b) { return a * b; });
  _add_4('/', function(a, b) { return a / b; });

  var _add_cmp = function(n, f) {
    return pipl
      .read(n, ['a', 'b', 'true', 'false'], true)
      .call(function(refs) {
        var result = f(+refs.get('a'), +refs.get('b'));
        refs.set('__', refs.get(result));
      })
      .send('__', '');
  };
  _add_cmp('>', function(a, b) { return a > b; });
  _add_cmp('<', function(a, b) { return a < b; });
  _add_cmp('>=', function(a, b) { return a >= b; });
  _add_cmp('<=', function(a, b) { return a <= b; });
};

Template.form.events = {
  'click #run': run,
  'keypress #subject': function(event) {
    if (event.ctrlKey && (event.keyCode === 10 || event.keyCode === 13)) {
      run();
    }
  }
};

Template.examples.events = {
  'change #examples': function(event) {
    $('#subject').val(event.target.value);
    $('#examples').val('**');
  }
};

Template.examples.examples = [
  {
    title: '** clear **',
    code: ''
  },
  {
    title: 'Simple',
    code: [
      'c1(n1) . n1[n2] . ()',
      'c1[n3] . n3(cowbell) . ()',
    ].join("\n")
  },
  {
    title: 'Procedure',
    code: [
      's0(begin) . ()',
      's0[a].s1(b) . ()',
      's1[b].s2(c) . ()',
      's2[c].s3(d) . ()',
      's3[d].s4(e) . ()',
      's4[end] . ()',
    ].join("\n")
  },
  {
    title: 'Replication',
    code: [
      '! call[s] . print(s) . ()',
      'call(1) . ()',
      'call(2) . ()',
      'call(3) . ()',
      'call(4) . ()',
      'call(5) . ()',
    ].join("\n")
  },
  { 
    title: 'Choice',
    code: [
      'if(when) . if(else) .',
      '(+',
      '  when[_] . print(this_time_true) . ()',
      '  else[_] . print(this_time_false) . ()',
      '  never[_] . print(never_this*) . ()',
      ')',
      'if[true_block] . if[false_block].',
      '(|',
      '  true_block(t) . ()',
      '  false_block(f) . ()',
      ')',
    ].join("\n")
  },
  {
    title: 'Polyadic',
    code: [
      'c(won, too, three) . ()',
      'c[a b c] . print(a) . print(b) . print(c) . ()',
    ].join("\n")
  },
  {
    title: 'No names',
    code: [
      'c() . wa() . ()',
      'c[] . wb() . ()',
    ].join("\n")
  },
  {
    title: 'New IDs',
    code: [
      '[case-a]c(case-a) . [case-b]c(case-b) .',
      '[y, z]',
      '(|',
      '  case-a[case-a-result] . y(case-a-result) . ()',
      '  case-b[case-b-result] . y(case-b-result) . ()',
      '  y[result] . print(z) . print(result) . ()',
      ')',
      'c[a] . c[b] . a(c-result) . ()',
      'case-b(never-read) . ()',
      'y(never-read) . ()',
      'z(z) . () ',
    ].join("\n")
  },
  {
    title: 'Arithmetic v1',
    code: [
      '+(6, 2, out) . out[r] . print(6 + 2 = r) .',
      '-(6, 2, out) . out[r] . print(6 - 2 = r) .',
      '*(6, 2, out) . out[r] . print(6 * 2 = r) .',
      '/(6, 2, out) . out[r] . print(6 / 2 = r) .',
      '()',
    ].join("\n")
  },
  {
    title: 'Arithmetic v2',
    code: [
      '! f[a op b] . [p] op(a, b, p) . p[r] . print(a op b = r) . s() . ()',
      'f(6 + 2) . s[] .',
      'f(6 - 2) . s[] .',
      'f(6 * 2) . s[] .',
      'f(6 / 2) . s[] .',
      '()',
    ].join("\n")
  },
  {
    title: 'Numeric Comparison',
    code: [
      '! cmp[a, op, b] .',
      '(|',
      '  [t f] op(a, b, t, f) .',
      '  (+',
      '    t[].p(true) . ()',
      '    f[].p(false) . ()',
      '  )',
      '  p[r] . print(a op b = r) . s() . ()',
      ')',
      'cmp(6 < 2) . s[] .',
      'cmp(6 > 2) . s[] .',
      'cmp(6 <= 2) . s[] .',
      'cmp(6 >= 2) . s[] .',
      'print(-- equal --) .',
      'cmp(2 < 2) . s[] .',
      'cmp(2 > 2) . s[] .',
      'cmp(2 <= 2) . s[] .',
      'cmp(2 >= 2) . s[] .',
      '()',
    ].join("\n")
  },
  {
    title: 'Factorial',
    code: [
      '! ![n, factorial-out] .',
      '[greater-than-two, two-or-less]',
      '(|',
      '  >(n, 2, greater-than-two, two-or-less) .',
      '  (+',
      '    two-or-less[] . factorial-out(n) . ()',
      '    greater-than-two[] .',
      '    [t1 t2 t3]',
      '    (|',
      '      -(n, 1, t1) . ()',
      '      t1[n-1] . !(n-1, t2) . ()',
      '      t2[factorial-n-1] . *(n, factorial-n-1, t3) . ()',
      '      t3[res] . factorial-out(res) . ()',
      '    )',
      '  )',
      ')',
      '!(4, print) . ()',
    ].join("\n")
  },
  {
    title: 'Shared Variable',
    code: [
      '! create[name, value, out] .',
      '[get set store]',
      '(|',
      '  out(get, set) . store(name, value) . ()',
      '  ! store[name, value] .',
      '  (+',
      '    get[out] . out(value) . store(name, value) . ()',
      '    set[value] . store(name, value) . ()',
      '  )',
      ')',
      '[out]create(x, 2, out) . out[get, set] .',
      '(|',
      '  get(print) . set(7) . get(print) . t1() . ()',
      '  t1[] . get(print) . set(sub1) . get(print) . t2() . ()',
      '  t2[] . send(set, t3) . ()',
      '  t3[] . get(print) . set(sub2) . get(print) . ()',
      ')',
      'send[setter, next] . setter(outside) . next() . ()',
    ].join("\n")
  },
  {
    title: 'logic',
    code: [
      '! true[true_p, false_p] . true_p(true) . ()',
      '! false[true_p, false_p]  .false_p(false) . ()',
      '',
      '! not[value, out]',
      '. [is-true, is-false]value(is-true, is-false) .',
      '(+',
      '   is-true[] . out[false] . ()',
      '   is-false[] . out[true] . ()',
      ')',
      '',
      '! and[a, b, out]',
      '. [a-is-true, a-is-false]a(a-is-true, a-is-false) .',
      '(+',
      '  a-is-true[]  . out(b) . ()',
      '  a-is-false[] . out(a) . ()',
      ')',
      '',
      '! or[a, b, out]',
      '. [a-is-true, a-is-false]a(a-is-true, a-is-false) .',
      '(+',
      '  a-is-true[]  . out(a) . ()',
      '  a-is-false[] . out(b) . ()',
      ')',
      '',
      '! xor[a, b, out]',
      '. [not-a]not(a, not-a)',
      '. [not-b]not(b, not-b)',
      '. [a-not-b]and(a, not-b, a-not-b)',
      '. [b-not-a]and(b, not-a, b-not-a)',
      '. or(a-not-b, b-not-a, out) . ()',
      '',
      '! xor[a, b, out]',
      '. [a-is-true, a-is-false]a(a-is-true, a-is-false) .',
      '(+',
      '  a-is-true[] . not(b, out) . ()',
      '  a-is-false[] . out(b) . ()',
      ')',
    ].join("\n")
  },
]
