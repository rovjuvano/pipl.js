PIPL = {}
(exports ? this).Pipl = class Pipl
  constructor: ->
    @engine = new PIPL.Engine()
    @main = new PIPL.ParallelProcess(@engine)

  # Public: Generate unique id for use as channel_id or name_id.
  new_id: -> @engine.new_id()

  # Public: Create a new sequence of processes starting with a read.
  read: (channel_id, name_id, replicate=false, new_names) ->
    @main.read(channel_id, name_id, replicate, new_names)

  # Public: Create a new sequence of processes starting with a send.
  send: (channel_id, name_id, replicate=false, new_names) ->
    @main.send(channel_id, name_id, replicate, new_names)

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
    $.extend(true, {}, this)

# Internal: Core execution logic.
class PIPL.Engine
  constructor: ->
    @queue = []
    @readers = {}
    @senders = {}

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
    @step()
    setTimeout((=> @run()), 10) if @queue.length > 0

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

  # Internal: Add new_names to refs.
  make_new_names: (refs, new_names) ->
    return unless new_names
    refs.set(name, @new_id()) for name in new_names

# Internal: Abstract parent class for Read and Send processes.
class PIPL.SimpleProcess
  constructor: (@engine, @channel_id, @name_id, @replicate, @new_names) ->

  # Public: Append read process.
  read: (channel_id, name_id, replicate=false, new_names) ->
    @next = new PIPL.ReadProcess(@engine, channel_id, name_id, replicate, new_names)

  # Public: Append send process.
  send: (channel_id, name_id, replicate=false, new_names) ->
    @next = new PIPL.SendProcess(@engine, channel_id, name_id, replicate, new_names)

  # Public: Append parallel process.
  parallel: (new_names) ->
    @next = new PIPL.ParallelProcess(@engine, new_names)

  # Public: Append choice process.
  choice: (new_names) ->
    @next = new PIPL.ChoiceProcess(@engine, new_names)

class PIPL.ReadProcess extends PIPL.SimpleProcess
  proceed: (refs) ->
    @engine.enqueue_reader( refs.get(@channel_id), this, refs )

  input: (refs, value) ->
    @engine.make_new_names(refs, @new_names)
    console.log("read: #{@channel_id}=#{refs.get(@channel_id)}[#{@name_id} = #{value}]")
    if @next
      refs = refs.dup() if @replicate
      refs.set(@name_id, value) unless @no_name
      @next.proceed(refs)
    @proceed(refs) if @replicate

class PIPL.SendProcess extends PIPL.SimpleProcess
  proceed: (refs) ->
    @engine.enqueue_sender( refs.get(@channel_id), this, refs )

  output: (refs) ->
    @engine.make_new_names(refs, @new_names)
    console.log("send: #{@channel_id}=#{refs.get(@channel_id)}(#{@name_id}=#{refs.get(@name_id)})")
    if @next
      refs = refs.dup() if @replicate
      @next.proceed(refs)
    @proceed(refs) if @replicate
    refs.get(@name_id)

# Internal: Abstract parent class for Parallel and Choice processes.
class PIPL.ComplexProcess
  constructor: (@engine, @new_names) ->
    @processes = []

  # Public: Create a new sequence of processes starting with a read.
  read: (channel_id, name_id, replicate=false, new_names) ->
    p = @make_read(channel_id, name_id, replicate, new_names)
    @processes.push(p)
    p

  # Public: Create a new sequence of processes starting with a send.
  send: (channel_id, name_id, replicate=false, new_names) ->
    p = @make_send(channel_id, name_id, replicate, new_names)
    @processes.push(p)
    p

class PIPL.ParallelProcess extends PIPL.ComplexProcess
  make_read: (channel_id, name_id, replicate, new_names) ->
    new PIPL.ReadProcess(@engine, channel_id, name_id, replicate, new_names)

  make_send: (channel_id, name_id, replicate, new_names) ->
    new PIPL.SendProcess(@engine, channel_id, name_id, replicate, new_names)

  proceed: (refs) ->
    @engine.make_new_names(refs, @new_names)
    if @processes.length > 0
      @processes[0].proceed(refs)
      @processes[i].proceed(refs.dup()) for i in [1..(@processes.length-1)]

class PIPL.ChoiceProcess extends PIPL.ComplexProcess
  make_read: (channel_id, name_id, replicate, new_names) ->
    new PIPL.ChoiceReadProcess(@engine, this, channel_id, name_id, replicate, new_names)

  make_send: (channel_id, name_id, replicate, new_names) ->
    new PIPL.ChoiceSendProcess(@engine, this, channel_id, name_id, replicate, new_names)

  proceed: (refs) ->
    @engine.make_new_names(refs, @new_names)
    @processes.forEach (p) -> p.proceed(refs)

  notify: (refs) ->
    @processes.forEach (p) -> p.kill(refs)

class PIPL.ChoiceReadProcess extends PIPL.ReadProcess
  constructor: (@engine, @parent, @channel_id, @name_id, @replicate, @new_names) ->

  kill: (refs) ->
    @engine.dequeue_reader(refs.get(@channel_id), this)

  input: (refs, value) ->
    @parent.notify(refs)
    super(refs, value)

class PIPL.ChoiceSendProcess extends PIPL.SendProcess
  constructor: (@engine, @parent, @channel_id, @name_id, @replicate, @new_names) ->

  kill: (refs) ->
    @engine.dequeue_sender(refs.get(@channel_id), this)

  output: (refs) ->
    @parent.notify(refs)
    super(refs)
