return unless Meteor.isClient
Handlebars.registerHelper('log', (msg)-> console.log(msg))
pipl = null
run = ->
  code = $('#subject').val()
  try
    ast = PIPL_Parser.parse(code)
    pipl = new Pipl() if (!pipl || $('#reset').is(':checked'))
    window.last_pipl = pipl
    ast.enter(pipl)
    pipl.run()
    $('#result').removeClass('error').text(ast.toString())
  catch e
    msg = "Line #{e.line}, column #{e.column}: #{e.message}"
    $('#result').addClass('error').text(msg)

Template.form.events =
  'click #run': run
  'keypress #subject': (event) ->
    if event.ctrlKey && event.keyCode == 10
      run()

Template.examples.events =
  'change #examples': (event) ->
    $('#subject').val( event.target.value )
    $('#examples').val('**')

Template.examples.examples = [
  {
    title: '** clear **'
    code: ''
  },
  {
    title: 'Simple'
    code: [
      'c1(n1) . n1[n2] . ()',
      'c1[n3] . n3(cowbell) . ()',
    ].join("\n")
  },
  {
    title: 'Procedure'
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
    title: 'Replication'
    code: [
      '!print[s] . ()',
      'print(1) . ()',
      'print(2) . ()',
      'print(3) . ()',
      'print(4) . ()',
      'print(5) . ()',
    ].join("\n")
  },
  { 
    title: 'Choice'
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
      '!print[s] . ()',
    ].join("\n")
  },
  {
    title: 'Polyadic',
    code: [
      'c(won, too, three) . ()',
      'c[a b c] . print(a) . print(b) . print(c) . ()',
      '!print[s] . ()',
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
      '!print[s] . ()',
    ].join("\n")
  },
  {
    title: 'Factorial'
    code: [
      '!factorial[n, factorial-out] .',
      '[greater-than-two, two-or-less]',
      '(|',
      '  greater-than(n, 2, greater-than-two, two-or-less) .',
      '  (+',
      '    two-or-less[] . factorial-out(n) . ()',
      '    greater-than-two[] .',
      '    [t1 t2 t3]',
      '    (|',
      '      subtract(n, 1, t1) . ()',
      '      t1[n-1] . factorial(n-1, t2) . ()',
      '      t2[factorial-n-1] . multiply(n, factorial-n-1, t3) . ()',
      '      t3[res] . factorial-out(res) . ()',
      '    )',
      '  )',
      '  print(n).()',
      ')',
      'factorial(4, is-24) . ()',
      'greater-than[a, b, greater, not-greater].greater()',
      '. greater-than[a, b, greater, not-greater].greater()',
      '. greater-than[a, b, greater, not-greater].not-greater()',
      '. ()',
      'subtract[n, 1, subtract-out].subtract-out(3)',
      '. subtract[n, 1, subtract-out].subtract-out(2)',
      '. ()',
      'multiply[a, b, multiply-out].multiply-out(6)',
      '. multiply[a, b, multiply-out].multiply-out(24)',
      '. ()',
      'is-24[_] . ()',
      '!print[s] . ()',
    ].join("\n")
  },
  {
    title: 'Shared Variable',
    code: [
      '!create[name, value, out] .',
      '[get set store]',
      '(|',
      '  out(get, set) . store(name, value) . ()',
      '  !store[name, value] .',
      '  (+',
      '    get[out] . out(value) . store(name, value) . ()',
      '    set[value] . store(name, value) . ()',
      '  )',
      ')',
      'create(x, 2, out) . out[get, set] .',
      '(|',
      '  get(print) . set(7) . get(print) . t1() . ()',
      '  t1[] . get(print) . set(sub1) . get(print) . t2() . ()',
      '  t2[] . send(set, t3) . ()',
      '  t3[] . get(print) . set(sub2) . get(print) . ()',
      ')',
      'send[setter, next] . setter(outside) . next() . ()',
      '!print[s] . ()',
    ].join("\n")
  },
  {
    title: 'logic'
    code: [
      '!true[true_p, false_p] . true_p(true) . ()',
      '!false[true_p, false_p]  .false_p(false) . ()',
      '',
      '!not[value, out]',
      '. [is-true, is-false]value(is-true, is-false) .',
      '(+',
      '   is-true[] . out[false] . ()',
      '   is-false[] . out[true] . ()',
      ')',
      '',
      '!and[a, b, out]',
      '. [a-is-true, a-is-false]a(a-is-true, a-is-false) .',
      '(+',
      '  a-is-true[]  . out(b) . ()',
      '  a-is-false[] . out(a) . ()',
      ')',
      '',
      '!or[a, b, out]',
      '. [a-is-true, a-is-false]a(a-is-true, a-is-false) .',
      '(+',
      '  a-is-true[]  . out(a) . ()',
      '  a-is-false[] . out(b) . ()',
      ')',
      '',
      '!xor[a, b, out]',
      '. [not-a]not(a, not-a)',
      '. [not-b]not(b, not-b)',
      '. [a-not-b]and(a, not-b, a-not-b)',
      '. [b-not-a]and(b, not-a, b-not-a)',
      '. or(a-not-b, b-not-a, out) . ()',
      '',
      '!xor[a, b, out]',
      '. [a-is-true, a-is-false]a(a-is-true, a-is-false) .',
      '(+',
      '  a-is-true[] . not(b, out) . ()',
      '  a-is-false[] . out(b) . ()',
      ')',
    ].join("\n")
  },
]
