PIPL = {}

# Internal: Make Read/Send process, handle multiple names.
make_step = (engine, klass, channel_id, name_ids, replicate, new_names, process) ->
  name_ids = [name_ids] unless Array.isArray(name_ids)
  new klass(engine, channel_id, name_ids, replicate, new_names, process)

(exports ? this).Pipl = class Pipl
  constructor: ->
    @engine = new PIPL.Engine()
    @main = new PIPL.ParallelProcess(@engine)

  # Public: Generate unique id for use as channel_id or name_id.
  new_id: -> @engine.new_id()

  # Public: Create a new sequence of processes starting with a read.
  read: (channel_id, name_ids, replicate=false, new_names) ->
    @main.read(channel_id, name_ids, replicate, new_names)

  # Public: Create a new sequence of processes starting with a send.
  send: (channel_id, name_ids, replicate=false, new_names) ->
    @main.send(channel_id, name_ids, replicate, new_names)

  # Public: Run to completion.
  run: ->
    @main.proceed(new PIPL.Refs())
    @main = new PIPL.ParallelProcess(@engine)
    @engine.run()

# Internal: Symbol table.
class PIPL.Refs
  constructor: ->
    @store = {}

  get: (key) ->
    if @store.hasOwnProperty(key) then @store[key] else key

  set: (key, value) ->
    @store[key] = value

  dup: ->
    dup = new PIPL.Refs()
    $.extend(dup.store, @store)
    dup

# Internal: Core execution logic.
class PIPL.Engine
  constructor: ->
    @queue = []
    @readers = {}
    @senders = {}
    @_run_loop ||= =>
      nice = 100
      while @queue.length > 0 && nice > 0
        @step()
        nice--
      @run()

  __id: 0
  new_id: ->
    "#<ID:xxx#{(@__id++).toString(16)}xxx>".replace(/x/g, (c) ->
      (Math.random()*16|0).toString(16)
    )

  # Public: Handle new read request on channel from process.
  enqueue_reader: (channel, process, refs) ->
    @enqueue(@readers, channel, process, refs)

  # Public: Handle new send request on channel from process.
  enqueue_sender: (channel, process, refs) ->
    @enqueue(@senders, channel, process, refs)

  # Internal: enqueue helper
  enqueue: (queue, channel, process, refs) ->
    queue[channel] ||= []
    queue[channel].push([process, refs])
    @enqueue_step(channel)

  # Internal: Enqueue step if necessary.
  enqueue_step: (channel) ->
    if waiting(@readers, channel) && waiting(@senders, channel)
      @queue.push(channel)

  # Internal: Check if channel has any processes waiting in queue.
  waiting = (queue, channel) ->
    queue[channel] && queue[channel].length > 0

  # Public: Handle removing alternate process after choice processes proceeds.
  dequeue_reader: (channel, process) ->
    dequeue(@readers, channel, process)

  # Public: Handle removing alternate process after choice processes proceeds.
  dequeue_sender: (channel, process) ->
    dequeue(@senders, channel, process)

  # Internal: dequeue helper
  dequeue = (queue, channel, process) ->
    queue[channel].splice( queue[channel].indexOf(process), 1)[0]

  # Public: Run to completion.
  run: ->
    if @queue.length > 0
      setTimeout(@_run_loop, 10)
    else
      @clean()

  # Internal: Complete send/read on channel.
  step: ->
    return unless @queue.length > 0
    channel = select(@queue)

    return unless @readers[channel].length > 0
    return unless @senders[channel].length > 0
    [reader, reader_refs] = select(@readers[channel])
    [sender, sender_refs] = select(@senders[channel])

    reader.input( reader_refs, sender.output(sender_refs) )

  # Internal: Remove process from queue for completing step.
  select = (queue) ->
    queue.splice( Math.floor(Math.random() * queue.length), 1 )[0]

  # Public: Free memory used by unused IDs.
  clean: ->
    for queue in [@readers, @senders]
      do -> Object.keys(queue).forEach (id) ->
        if queue[id].length < 1
          delete queue[id]

  # Internal: Add new_names to refs.
  make_new_names: (refs, new_names) ->
    return unless new_names
    refs.set(name, @new_id()) for name in new_names

# Internal: Abstract parent class for Read and Send processes.
class PIPL.SimpleProcess
  constructor: (@engine, @channel_id, @name_ids, @replicate, @new_names) ->

  # Public: Append read process.
  read: (channel_id, name_ids, replicate=false, new_names) ->
    @next = make_step(@engine, PIPL.ReadProcess, channel_id, name_ids, replicate, new_names, this)

  # Public: Append send process.
  send: (channel_id, name_ids, replicate=false, new_names) ->
    @next = make_step(@engine, PIPL.SendProcess, channel_id, name_ids, replicate, new_names, this)

  # Public: Append function
  call: (callback, args...) ->
    @next = new PIPL.CallProcess(@engine, callback, args)

  # Public: Append parallel process.
  parallel: (new_names) ->
    @next = new PIPL.ParallelProcess(@engine, new_names)

  # Public: Append choice process.
  choice: (new_names) ->
    @next = new PIPL.ChoiceProcess(@engine, new_names)

class PIPL.ReadProcess extends PIPL.SimpleProcess
  proceed: (refs) ->
    @engine.enqueue_reader( refs.get(@channel_id), this, refs )

  input: (refs, values) ->
    @engine.make_new_names(refs, @new_names)
    if @next
      refs = refs.dup() if @replicate
      refs.set(name_id, values[i]) for name_id, i in @name_ids
      @next.proceed(refs)
    @proceed(refs) if @replicate

class PIPL.SendProcess extends PIPL.SimpleProcess
  proceed: (refs) ->
    @engine.enqueue_sender( refs.get(@channel_id), this, refs )

  output: (refs) ->
    @engine.make_new_names(refs, @new_names)
    if @next
      refs = refs.dup() if @replicate
      @next.proceed(refs)
    @proceed(refs) if @replicate
    (refs.get(name_id) for name_id in @name_ids)

class PIPL.CallProcess extends PIPL.SimpleProcess
  constructor: (@engine, @callback, @args) ->
  proceed: (refs) ->
    @callback.call(@, refs, @args)
    @next.proceed(refs) if @next

# Internal: Abstract parent class for Parallel and Choice processes.
class PIPL.ComplexProcess
  constructor: (@engine, @new_names) ->
    @processes = []

  # Public: Create a new sequence of processes starting with a read.
  read: (channel_id, name_ids, replicate=false, new_names) ->
    p = make_step(@engine, @read_class(), channel_id, name_ids, replicate, new_names, this)
    @processes.push(p)
    p

  # Public: Create a new sequence of processes starting with a send.
  send: (channel_id, name_ids, replicate=false, new_names) ->
    p = make_step(@engine, @send_class(), channel_id, name_ids, replicate, new_names, this)
    @processes.push(p)
    p

class PIPL.ParallelProcess extends PIPL.ComplexProcess
  read_class: -> PIPL.ReadProcess
  send_class: -> PIPL.SendProcess

  proceed: (refs) ->
    @engine.make_new_names(refs, @new_names)
    if @processes.length > 0
      @processes[0].proceed(refs)
    if @processes.length > 1
      @processes[i].proceed(refs.dup()) for i in [1..(@processes.length-1)]

class PIPL.ChoiceProcess extends PIPL.ComplexProcess
  read_class: -> PIPL.ChoiceReadProcess
  send_class: -> PIPL.ChoiceSendProcess

  proceed: (refs) ->
    @engine.make_new_names(refs, @new_names)
    @processes.forEach (p) -> p.proceed(refs)

  notify: (refs) ->
    @processes.forEach (p) -> p.kill(refs)

class PIPL.ChoiceReadProcess extends PIPL.ReadProcess
  constructor: (@engine, @channel_id, @name_ids, @replicate, @new_names, @parent) ->
    @replicate = false

  kill: (refs) ->
    @engine.dequeue_reader(refs.get(@channel_id), this)

  input: (refs, value) ->
    @parent.notify(refs)
    super(refs, value)

class PIPL.ChoiceSendProcess extends PIPL.SendProcess
  constructor: (@engine, @channel_id, @name_ids, @replicate, @new_names, @parent) ->
    @replicate = false

  kill: (refs) ->
    @engine.dequeue_sender(refs.get(@channel_id), this)

  output: (refs) ->
    @parent.notify(refs)
    super(refs)
