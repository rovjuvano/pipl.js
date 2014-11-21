var __slice = [].slice,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

var PIPL = {};

var make_step = function(engine, klass, channel_id, name_ids, replicate, new_names, process) {
  if (!Array.isArray(name_ids)) {
    name_ids = [name_ids];
  }
  return new klass(engine, channel_id, name_ids, replicate, new_names, process);
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
    this.readers = {};
    this.senders = {};
    this._run_loop = _run_loop.bind(this);
  }

  Engine.prototype.__id = 0;

  Engine.prototype.new_id = function() {
    return ("#<ID:xxx" + ((this.__id++).toString(16)) + "xxx>").replace(/x/g, function(c) {
      return (Math.random() * 16 | 0).toString(16);
    });
  };

  Engine.prototype.enqueue_reader = function(channel, process, refs) {
    this.enqueue(this.readers, channel, process, refs);
  };

  Engine.prototype.enqueue_sender = function(channel, process, refs) {
    this.enqueue(this.senders, channel, process, refs);
  };

  Engine.prototype.enqueue = function(queue, channel, process, refs) {
    queue[channel] || (queue[channel] = []);
    queue[channel].push([process, refs]);
    this.enqueue_step(channel);
  };

  Engine.prototype.enqueue_step = function(channel) {
    if (waiting(this.readers, channel) && waiting(this.senders, channel)) {
      this.queue.push(channel);
    }
  };

  var waiting = function(queue, channel) {
    return queue[channel] && queue[channel].length > 0;
  };

  Engine.prototype.dequeue_reader = function(channel, process) {
    dequeue(this.readers, channel, process);
  };

  Engine.prototype.dequeue_sender = function(channel, process) {
    dequeue(this.senders, channel, process);
  };

  var dequeue = function(queue, channel, process) {
    queue[channel].splice(queue[channel].indexOf(process), 1)[0];
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
    if (this.readers[channel].length < 1 || this.senders[channel].length < 1) {
      return;
    }
    var _;
    _ = select(this.readers[channel]);
    var reader = _[0], reader_refs = _[1];
    _ = select(this.senders[channel]);
    var sender = _[0], sender_refs = _[1];
    reader.input(reader_refs, sender.output(sender_refs));
  };

  var select = function(queue) {
    return queue.splice(Math.floor(Math.random() * queue.length), 1)[0];
  };

  var clean = function(queue) {
    Object.keys(queue).forEach(function(id) {
      if (queue[id].length < 1) {
        delete queue[id];
      }
    });
  }
  Engine.prototype.clean = function() {
    clean(this.readers);
    clean(this.senders);
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

PIPL.SimpleProcess = (function() {
  function SimpleProcess(engine, channel_id, name_ids, replicate, new_names) {
    this.engine = engine;
    this.channel_id = channel_id;
    this.name_ids = name_ids;
    this.replicate = replicate;
    this.new_names = new_names;
  }

  SimpleProcess.prototype.read = function(channel_id, name_ids, replicate, new_names) {
    return this.next = make_step(this.engine, PIPL.ReadProcess, channel_id, name_ids, replicate, new_names, this);
  };

  SimpleProcess.prototype.send = function(channel_id, name_ids, replicate, new_names) {
    return this.next = make_step(this.engine, PIPL.SendProcess, channel_id, name_ids, replicate, new_names, this);
  };

  SimpleProcess.prototype.call = function() {
    var callback = arguments[0];
    var args = __slice.call(arguments, 1);
    return this.next = new PIPL.CallProcess(this.engine, callback, args);
  };

  SimpleProcess.prototype.parallel = function(new_names) {
    return this.next = new PIPL.ParallelProcess(this.engine, new_names);
  };

  SimpleProcess.prototype.choice = function(new_names) {
    return this.next = new PIPL.ChoiceProcess(this.engine, new_names);
  };

  return SimpleProcess;
})();

PIPL.ReadProcess = (function(_super) {
  __extends(ReadProcess, _super);

  function ReadProcess() {
    ReadProcess.__super__.constructor.apply(this, arguments);
  }

  ReadProcess.prototype.proceed = function(refs) {
    this.engine.enqueue_reader(refs.get(this.channel_id), this, refs);
  };

  ReadProcess.prototype.input = function(refs, values) {
    this.engine.make_new_names(refs, this.new_names);
    if (this.next) {
      if (this.replicate) {
        refs = refs.dup();
      }
      this.name_ids.forEach(function(name_id, i) {
        refs.set(name_id, values[i]);
      });
      this.next.proceed(refs);
    }
    if (this.replicate) {
      this.proceed(refs);
    }
  };

  return ReadProcess;
})(PIPL.SimpleProcess);

PIPL.SendProcess = (function(_super) {
  __extends(SendProcess, _super);

  function SendProcess() {
    SendProcess.__super__.constructor.apply(this, arguments);
  }

  SendProcess.prototype.proceed = function(refs) {
    this.engine.enqueue_sender(refs.get(this.channel_id), this, refs);
  };

  SendProcess.prototype.output = function(refs) {
    this.engine.make_new_names(refs, this.new_names);
    if (this.next) {
      if (this.replicate) {
        refs = refs.dup();
      }
      this.next.proceed(refs);
    }
    if (this.replicate) {
      this.proceed(refs);
    }
    return this.name_ids.map(function(name_id) {
      return refs.get(name_id);
    });
  };

  return SendProcess;
})(PIPL.SimpleProcess);

PIPL.CallProcess = (function(_super) {
  __extends(CallProcess, _super);

  function CallProcess(engine, callback, args) {
    this.engine = engine;
    this.callback = callback;
    this.args = args;
  }

  CallProcess.prototype.proceed = function(refs) {
    this.callback.call(this, refs, this.args);
    if (this.next) {
      return this.next.proceed(refs);
    }
  };

  return CallProcess;
})(PIPL.SimpleProcess);

PIPL.ComplexProcess = (function() {
  function ComplexProcess(engine, new_names) {
    this.engine = engine;
    this.new_names = new_names;
    this.processes = [];
  }

  ComplexProcess.prototype.read = function(channel_id, name_ids, replicate, new_names) {
    var p = make_step(this.engine, this.read_class, channel_id, name_ids, replicate, new_names, this);
    this.processes.push(p);
    return p;
  };

  ComplexProcess.prototype.send = function(channel_id, name_ids, replicate, new_names) {
    var p = make_step(this.engine, this.send_class, channel_id, name_ids, replicate, new_names, this);
    this.processes.push(p);
    return p;
  };

  return ComplexProcess;
})();

PIPL.ParallelProcess = (function(_super) {
  __extends(ParallelProcess, _super);

  function ParallelProcess() {
    return ParallelProcess.__super__.constructor.apply(this, arguments);
  }

  ParallelProcess.prototype.read_class = PIPL.ReadProcess;
  ParallelProcess.prototype.send_class = PIPL.SendProcess;

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
})(PIPL.ComplexProcess);

PIPL.ChoiceReadProcess = (function(_super) {
  __extends(ChoiceReadProcess, _super);

  function ChoiceReadProcess(engine, channel_id, name_ids, replicate, new_names, parent) {
    this.engine = engine;
    this.channel_id = channel_id;
    this.name_ids = name_ids;
    this.replicate = false;
    this.new_names = new_names;
    this.parent = parent;
  }

  ChoiceReadProcess.prototype.kill = function(refs) {
    this.engine.dequeue_reader(refs.get(this.channel_id), this);
  };

  ChoiceReadProcess.prototype.input = function(refs, value) {
    this.parent.notify(refs);
    ChoiceReadProcess.__super__.input.call(this, refs, value);
  };

  return ChoiceReadProcess;
})(PIPL.ReadProcess);

PIPL.ChoiceSendProcess = (function(_super) {
  __extends(ChoiceSendProcess, _super);

  function ChoiceSendProcess(engine, channel_id, name_ids, replicate, new_names, parent) {
    this.engine = engine;
    this.channel_id = channel_id;
    this.name_ids = name_ids;
    this.replicate = false;
    this.new_names = new_names;
    this.parent = parent;
  }

  ChoiceSendProcess.prototype.kill = function(refs) {
    this.engine.dequeue_sender(refs.get(this.channel_id), this);
  };

  ChoiceSendProcess.prototype.output = function(refs) {
    this.parent.notify(refs);
    return ChoiceSendProcess.__super__.output.call(this, refs);
  };

  return ChoiceSendProcess;
})(PIPL.SendProcess);

PIPL.ChoiceProcess = (function(_super) {
  __extends(ChoiceProcess, _super);

  function ChoiceProcess() {
    return ChoiceProcess.__super__.constructor.apply(this, arguments);
  }

  ChoiceProcess.prototype.read_class = PIPL.ChoiceReadProcess;
  ChoiceProcess.prototype.send_class = PIPL.ChoiceSendProcess;

  ChoiceProcess.prototype.proceed = function(refs) {
    this.engine.make_new_names(refs, this.new_names);
    this.processes.forEach(function(p) {
      p.proceed(refs);
    });
  };

  ChoiceProcess.prototype.notify = function(refs) {
    this.processes.forEach(function(p) {
      p.kill(refs);
    });
  };

  return ChoiceProcess;
})(PIPL.ComplexProcess);
