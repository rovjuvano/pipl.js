PIPL = {}
(exports ? this).Pipl = class Pipl
  constructor: ->
    @engine = new PIPL.Engine()
    @main = new PIPL.ParallelProcess(@engine)

  # Public: Generate unique id for use as channel_id or name_id.
  __id: 0
  new_id: ->
    "#<ID:xxx#{(@__id++).toString(16)}xxx>".replace(/x/g, (c) ->
      (Math.random()*16|0).toString(16)
    )

  # Public: Create a new sequence of processes starting with a read.
  read: (channel_id, name_id, replicate=false) ->
    @main.read(channel_id, name_id, replicate)

  # Public: Create a new sequence of processes starting with a send.
  send: (channel_id, name_id, replicate=false) ->
    @main.send(channel_id, name_id, replicate)

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

  # Public: Handle new read request on channel from process.
  enqueue_reader: (channel, process) ->
    @enqueue(@readers, channel, process)

  # Public: Handle new send request on channel from process.
  enqueue_sender: (channel, process) ->
    @enqueue(@senders, channel, process)

  # Internal: enqueue helper
  enqueue: (queue, channel, process) ->
    queue[channel] ||= []
    queue[channel].push(process)
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
    reader = select(@readers[channel])
    sender = select(@senders[channel])
    reader.read( sender.send() ) if reader && sender

  # Internal: Remove process from queue for completing step.
  select = (queue) ->
    queue.splice( Math.floor(Math.random() * queue.length), 1 )[0]

# Internal: Abstract parent class for Read and Send processes.
class PIPL.SimpleProcess
  constructor: (@engine, @channel_id, @name_id, @replicate) ->

  # Public: Append read process.
  read: (channel_id, name_id, replicate=false) ->
    @next = new PIPL.ReadProcess(@engine, channel_id, name_id, replicate)

  # Public: Append send process.
  send: (channel_id, name_id, replicate=false) ->
    @next = new PIPL.SendProcess(@engine, channel_id, name_id, replicate)

  # Public: Append parallel process.
  parallel: ->
    @next = new PIPL.ParallelProcess(@engine)

  # Public: Append choice process.
  chice: ->
    @next = new PIPL.ChoiceProcess(@engine)

class PIPL.ReadProcess extends PIPL.SimpleProcess
  proceed: (refs) ->
    @refs = refs
    @engine.enqueue_reader( @refs.get(@channel_id), this )

  read: (value) ->
    console.log("read: #{@channel_id}=#{@refs.get(@channel_id)}(#{@name_id} = #{value})")
    if @next
      refs = if @replicate then @refs.dup() else @refs
      refs.set(@name_id, value)
      @next.proceed(refs)
    @proceed(@refs) if @replicate

class PIPL.SendProcess extends PIPL.SimpleProcess
  proceed: (refs) ->
    @refs = refs
    @engine.enqueue_sender( @refs.get(@channel_id), this )

  send: ->
    console.log("send: #{@channel_id}=#{@refs.get(@channel_id)}(#{@name_id}=#{@refs.get(@name_id)})")
    if @next
      refs = if @replicate then @refs.dup() else @refs
      @next.proceed(refs)
    @proceed(@refs) if @replicate
    @refs.get(@name_id)

# Internal: Abstract parent class for Parallel and Choice processes.
class PIPL.ComplexProcess
  constructor: (@engine) ->
    @processes = []

  # Public: Create a new sequence of processes starting with a read.
  read: (channel_id, name_id, replicate=false) ->
    p = @make_read(channel_id, name_id, replicate)
    @processes.push(p)
    p

  # Public: Create a new sequence of processes starting with a send.
  send: (channel_id, name_id, replicate=false) ->
    p = @make_send(channel_id, name_id, replicate)
    @processes.push(p)
    p

class PIPL.ParallelProcess extends PIPL.ComplexProcess
  make_read: (channel_id, name_id, replicate) ->
    new PIPL.ReadProcess(@engine, channel_id, name_id, replicate)

  make_send: (channel_id, name_id, replicate) ->
    new PIPL.SendProcess(@engine, channel_id, name_id, replicate)

  proceed: (refs) ->
    if @processes.length > 0
      @processes[0].proceed(refs)
      @processes[i].proceed(refs.dup()) for i in [1..(@processes.length-1)]

class PIPL.ChoiceProcess extends PIPL.ComplexProcess
  make_read: (channel_id, name_id, replicate) ->
    new PIPL.ChoiceReadProcess(@engine, this, channel_id, name_id, replicate)

  make_send: (channel_id, name_id, replicate) ->
    new PIPL.ChoiceSendProcess(@engine, this, channel_id, name_id, replicate)

  proceed: (refs) ->
    @process.forEach (p) -> p.proceed(refs)

  notify: ->
    @process.forEach (p) -> p.kill()

class PIPL.ChoiceReadProcess extends PIPL.ReadProcess
  contructor: (@engine, @parent, @channel_id, @name_id, @replicate) ->

  kill: ->
    @engine.dequeue_reader(@refs.get(@channel_id), this)

  read: ->
    @parent.notify
    super(value)

class PIPL.ChoiceSendProcess extends PIPL.SendProcess
  contructor: (@engine, @parent, @channel_id, @name_id, @replicate) ->

  kill: ->
    @engine.dequeue_sender(@refs.get(@channel_id), this)

  send: ->
    @parent.notify
    super(value)
