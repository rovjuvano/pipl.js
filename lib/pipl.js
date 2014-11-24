var PIPL = {};

var make_step = function(engine, type, channel_id, name_ids, replicate, new_names, process) {
  if (!Array.isArray(name_ids)) {
    name_ids = [name_ids];
  }
  var handler_class = type === 'read' ? PIPL.ReadHandler : PIPL.SendHandler;
  return new PIPL.SequentialProcess(engine, type, handler_class, channel_id, name_ids, replicate, new_names, process);
};

this.Pipl = (function() {
  function Pipl() {
    this.engine = new PIPL.Engine();
    this.main = new PIPL.ParallelProcess(this.engine);
  }

  Pipl.prototype.new_id = function() {
    return this.engine.new_id();
  };

  Pipl.prototype.read = function(channel_id, name_ids, replicate, new_names) {
    return this.main.read(channel_id, name_ids, replicate, new_names);
  };

  Pipl.prototype.send = function(channel_id, name_ids, replicate, new_names) {
    return this.main.send(channel_id, name_ids, replicate, new_names);
  };

  Pipl.prototype.run = function() {
    this.main.proceed(new PIPL.Refs());
    this.main = new PIPL.ParallelProcess(this.engine);
    this.engine.run();
  };

  return Pipl;
})();

PIPL.Refs = (function() {
  function Refs() {
    this.store = {};
  }

  Refs.prototype.get = function(key) {
    if (this.store.hasOwnProperty(key)) {
      return this.store[key];
    } else {
      return key;
    }
  };

  Refs.prototype.set = function(key, value) {
    return this.store[key] = value;
  };

  Refs.prototype.dup = function() {
    var dup = new PIPL.Refs();
    $.extend(dup.store, this.store);
    return dup;
  };

  return Refs;
})();

PIPL.Engine = (function() {
  var _run_loop = function() {
      var nice = 100;
      while (this.queue.length > 0 && nice > 0) {
        this.step();
        nice--;
      }
      this.run();      
  }

  function Engine() {
    this.queue = [];
    this.channels = {};
    this._run_loop = _run_loop.bind(this);
  }

  Engine.prototype.__id = 0;

  Engine.prototype.new_id = function() {
    return ("#<ID:xxx" + ((this.__id++).toString(16)) + "xxx>").replace(/x/g, function(c) {
      return (Math.random() * 16 | 0).toString(16);
    });
  };

  Engine.prototype.enqueue = function(type, channelName, handler) {
    this.channels[channelName] || (this.channels[channelName] = {
      read: [],
      send: []
    });
    var channel = this.channels[channelName];
    channel[type].push(handler);
    if (channel.read.length > 0 && channel.send.length > 0) {
      this.queue.push(channel);
    }
  };

  Engine.prototype.dequeue = function(type, channelName, process) {
    var queue = this.channels[channelName][type];
    var index = queue.length;
    while (--index >= 0) {
      if (queue[index].process === process) {
        queue.splice(index, 1)[0];
        break;
      }
    }
  };

  Engine.prototype.run = function() {
    if (this.queue.length > 0) {
      setTimeout(this._run_loop, 10);
    } else {
      this.clean();
    }
  };

  Engine.prototype.step = function() {
    if (this.queue.length < 1) {
      return;
    }
    var channel = select(this.queue);
    if (channel.read.length < 1 || channel.send.length < 1) {
      return;
    }
    var reader = select(channel.read);
    var sender = select(channel.send);
    reader.input(sender.output());
  };

  var select = function(queue) {
    return queue.splice(Math.floor(Math.random() * queue.length), 1)[0];
  };

  Engine.prototype.clean = function() {
    var channels = this.channels;
    Object.keys(channels).forEach(function(channelName) {
      var channel = channels[channelName];
      if (channel.read.length < 1 && channel.send.length < 1) {
        delete channels[channelName];
      }
    })
  };

  Engine.prototype.make_new_names = function(refs, new_names) {
    if (new_names) {
      new_names.forEach(function(name) {
        refs.set(name, this.new_id());
      }.bind(this));
    }
  };

  return Engine;
})();

PIPL.SequentialProcess = (function() {
  function SequentialProcess(engine, type, handler_class, channel_id, name_ids, replicate, new_names, parent) {
    this.type = type;
    this.handler_class = handler_class;
    this.engine = engine;
    this.channel_id = channel_id;
    this.name_ids = name_ids;
    this.replicate = replicate;
    this.new_names = new_names;
    this.parent = parent;
  }

  SequentialProcess.prototype.read = function(channel_id, name_ids, replicate, new_names) {
    return this.next = make_step(this.engine, 'read', channel_id, name_ids, replicate, new_names, this);
  };

  SequentialProcess.prototype.send = function(channel_id, name_ids, replicate, new_names) {
    return this.next = make_step(this.engine, 'send', channel_id, name_ids, replicate, new_names, this);
  };

  SequentialProcess.prototype.call = function() {
    var callback = arguments[0];
    var args = Array.prototype.slice.call(arguments, 1);
    return this.next = new PIPL.CallProcess(this.engine, callback, args);
  };

  SequentialProcess.prototype.parallel = function(new_names) {
    return this.next = new PIPL.ParallelProcess(this.engine, new_names);
  };

  SequentialProcess.prototype.choice = function(new_names) {
    return this.next = new PIPL.ChoiceProcess(this.engine, new_names);
  };

  SequentialProcess.prototype.proceed = function(refs) {
    this.engine.enqueue(this.type, refs.get(this.channel_id), new this.handler_class(this, refs));
  };

  return SequentialProcess;
})();

PIPL.ReadHandler = (function() {
  function ReadHandler(process, refs) {
    this.process = process;
    this.refs = refs;
  }

  ReadHandler.prototype.input = function(values) {
    var p = this.process;
    var refs = (p.next && p.replicate) ? this.refs.dup() : this.refs;
    if (p.parent.notify) {
      p.parent.notify(refs);
    }
    p.engine.make_new_names(refs, p.new_names);
    if (p.next) {
      p.name_ids.forEach(function(name_id, i) {
        refs.set(name_id, values[i]);
      });
      p.next.proceed(refs);
    }
    if (p.replicate) {
      p.proceed(refs);
    }
  };

  return ReadHandler;
})();

PIPL.SendHandler = (function() {
  function SendHandler(process, refs) {
    this.process = process;
    this.refs = refs;
  }

  SendHandler.prototype.output = function() {
    var p = this.process;
    var refs = (p.next && p.replicate) ? this.refs.dup() : this.refs;
    if (p.parent.notify) {
      p.parent.notify(refs);
    }
    p.engine.make_new_names(refs, p.new_names);
    if (p.next) {
      p.next.proceed(refs);
    }
    if (p.replicate) {
      p.proceed(refs);
    }
    return p.name_ids.map(function(name_id) {
      return refs.get(name_id);
    });
  };

  return SendHandler;
})();

PIPL.CallProcess = (function() {
  function CallProcess(engine, callback, args) {
    this.engine = engine;
    this.callback = callback;
    this.args = args;
  }

  CallProcess.prototype.read = PIPL.SequentialProcess.prototype.read;
  CallProcess.prototype.send = PIPL.SequentialProcess.prototype.send;
  CallProcess.prototype.call = PIPL.SequentialProcess.prototype.call;
  CallProcess.prototype.parallel = PIPL.SequentialProcess.prototype.parallel;
  CallProcess.prototype.choice = PIPL.SequentialProcess.prototype.choice;

  CallProcess.prototype.proceed = function(refs) {
    this.callback.call(this, refs, this.args);
    if (this.next) {
      return this.next.proceed(refs);
    }
  };

  return CallProcess;
})();

PIPL.ParallelProcess = (function() {
  function ParallelProcess(engine, new_names) {
    this.engine = engine;
    this.new_names = new_names;
    this.processes = [];
  };

  var add_process = function(self, type, channel_id, name_ids, replicate, new_names) {
    var p = make_step(self.engine, type, channel_id, name_ids, replicate, new_names, self);
    self.processes.push(p);
    return p;
  };

  ParallelProcess.prototype.read = function(channel_id, name_ids, replicate, new_names) {
    return add_process(this, 'read', channel_id, name_ids, replicate, new_names);
  };

  ParallelProcess.prototype.send = function(channel_id, name_ids, replicate, new_names) {
    return add_process(this, 'send', channel_id, name_ids, replicate, new_names);
  };

  ParallelProcess.prototype.proceed = function(refs) {
    this.engine.make_new_names(refs, this.new_names);
    var i = this.processes.length;
    if (i > 0) {
      this.processes[--i].proceed(refs);
      while (i) {
        this.processes[--i].proceed(refs.dup());
      }
    }
  };

  return ParallelProcess;
})();

PIPL.ChoiceProcess = (function() {
  function ChoiceProcess(engine, new_names) {
    this.engine = engine;
    this.new_names = new_names;
    this.processes = [];
  }

  ChoiceProcess.prototype.read = PIPL.ParallelProcess.prototype.read;
  ChoiceProcess.prototype.send = PIPL.ParallelProcess.prototype.send;

  ChoiceProcess.prototype.proceed = function(refs) {
    this.engine.make_new_names(refs, this.new_names);
    this.processes.forEach(function(p) {
      p.proceed(refs);
    });
  };

  ChoiceProcess.prototype.notify = function(refs) {
    var self = this;
    self.processes.forEach(function(p) {
      self.engine.dequeue(p.type, refs.get(p.channel_id), p);
    });
  };

  return ChoiceProcess;
})();
