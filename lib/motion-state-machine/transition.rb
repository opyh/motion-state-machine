module StateMachine

  # See subclasses for various transition implementations.
  # Sorry for putting multiple classes in one file —
  # RubyMotion has no decentral dependency management yet...

  # @abstract Subclass and override {#event_description}, {#arm} and {#unarm} to implement a custom Transition class.

  class Transition

    # @return [Hash] configuration options of the transition.
    attr_reader :options

    # @return [Base] the state machine that this transition belongs to.
    attr_reader :state_machine

    # @return [State] the state from which the transition starts.
    attr_reader :source_state

    # @return [State] the state that the transition leads to.
    attr_reader :destination_state

    # @return [Object] a more specific object that triggers
    #   the transition.
    attr_reader :event_trigger_value


    class << self
      # @return [Symbol] Metaclass attribute, contains the key that
      #   is used for generating the specific transition via {#make}.
      attr_accessor :event_type
    end


    @@types_to_subclasses = {}

    # @return [Array<Class<Transition>>] a list of all registered transition subclasses
    def self.types
      @@types_to_subclasses.keys
    end


    # Creates a new {Transition} object with the given options.
    # The returned object's subclass is determined by the
    # +:type+ option.
    #
    # @param options [Hash] Configuration options for the transition.
    # @option options [Symbol] :type Type identifier for the transition, ex. +:on+, +:after+, +:on_notification+.
    #
    # See {#initialize} for all possible options.
    #
    # @example
    #   StateMachine::Transition.make type: :to, ... # => #<StateMachine::Transition:...>
    # @return [Transition] a new object with the class that fits the given +:type+ option.

    def self.make(options)
      klass = @@types_to_subclasses[options[:type]]
      klass.new options
    end


    # Initializes a new {Transition} between two given states.
    #
    # Additionally, you must also supply an event trigger value as
    # option. Its key must be equal to the transition class's
    # +event_type+., ex. if +event_type+ is +:on+, you have to supply
    # the event value using the option key +:on+.
    #
    # @param options [Hash] Configuration options for the transition.
    #
    # @option options [StateMachine::Base] :state_machine
    #   State machine that the transition belongs to.
    #
    # @option options [Symbol] :from
    #   State where the transition begins.
    #
    # @option options [Symbol] :to
    #   State where the transition ends.
    #
    # @option options [Proc] :if (nil)
    #   Block that should return a +Boolean+. If the block returns
    #   +false+, the transition will be blocked and not executed
    #   (optional).
    #
    # @option options [Proc] :unless (nil)
    #   Block that should return a +Boolean+. If the block returns
    #   +true+, the transition will be blocked and not executed
    #   (optional).
    #
    # @option options [Boolean] :internal (false)
    #   If set to true, the transition will not leave it's source
    #   state: Entry and Exit actions will not be called in this case.
    #   For internal transitions, +:from+ and +:to+ must be the same
    #   (optional).
    #
    # @note This method should not be used directly. To create +Transition+ objects, use {#make} instead.

    def initialize(options)
      @options = options.dup
      @state_machine = @options.delete :state_machine
      @source_state = @state_machine.state options[:from]
      @destination_state = @state_machine.state options[:to]

      event_type = self.class.event_type
      if event_type.nil?
        raise RuntimeError, "#{self.class} has no defined event type."
      end

      [:from, :to].each do |symbol|
        unless options[symbol].is_a?(Symbol)
          raise ":#{symbol} option must be given as symbol."
        end
      end

      @event_trigger_value = options[event_type]
      if @event_trigger_value.nil?
        raise ArgumentError, "You must supply an event trigger value."
      end

      if options[:internal] && options[:from] != options[:to]
        raise ArgumentError,
          "Internal states must have same source and destination state."
      end
    end


    # @return [Boolean] Asks the guard blocks given for +:if+ and
    #   +:unless+ if the transition is allowed. Returns +true+ if the
    #   transition is allowed to be executed.

    def allowed?
      if_guard = options[:if]
      unless if_guard.nil?
        return false unless if_guard.call(@state_machine)
      end
      unless_guard = options[:unless]
      unless unless_guard.nil?
        return false if unless_guard.call(@state_machine)
      end
      true
    end


    # @return [String] a short description of the event.
    #   Used for debug output.

    def event_description
      # Implement this in a subclass.
      "after unclassified event"
    end


    def inspect
      "#<#{self.class.name}:0x#{object_id.to_s(16)} "\
      "#{event_description} @options=#{options.inspect}>"
    end


    protected


    # Defines a +Hash+ key symbol that is unique to a {Transition}
    # subclass. The key is used by {#make} to identify which
    # {Transition} subclass should be created.
    #
    # @param [Symbol] type_symbol
    #   Unique symbol identifying your transition subclass.

    def self.type(type_symbol)
      unless type_symbol.is_a?(Symbol)
        raise ArgumentError, "Type must be given as symbol."
      end
      if @@types_to_subclasses[type_symbol].nil?
        @@types_to_subclasses[type_symbol] = self
      else
        other_class = @@types_to_subclasses[type_symbol]
        raise ArgumentError,
          "Can't register :#{type_symbol} twice, "
          "already used by #{other_class}."
      end
      @event_type = type_symbol
    end


    # Delegates handling the transition to the source state, which
    # makes sure that there are no ambiguous transitions for the
    # same event.

    def handle_in_source_state
      if @state_machine.initial_queue.nil?
        raise RuntimeError, "State machine not started yet."
      end

      if Dispatch::Queue.current.to_s != @state_machine.initial_queue.to_s
        raise RuntimeError,
          "#{self.class.event_type}:#{@event_trigger_value} must be "\
          "called from the queue where the state machine was started."
      end

      @source_state.send :guarded_execute,
        self.class.event_type,
        @event_trigger_value
    end


    private


    # Executed the transition directly, without checking the guard
    # blocks. Calls {State#exit!} on the source state, executes
    # the transition's +:action+ block and calls {State#enter!} on
    # the destination state.

    def unguarded_execute
      @source_state.send :exit! unless @options[:internal] == true
      # Could use @state_machine.instance_eval(&options[:action]) here,
      # but this would be much slower
      @options[:action] && @options[:action].call(@state_machine)
      @destination_state.send :enter! unless @options[:internal] == true

      @state_machine.log "#{event_log_text}"
    end


    # @return [String] Debug string that can be logged after the
    #   transition has been executed.

    def event_log_text
  		if @options[:internal]
  			"#{@state_machine.name} still #{destination_state.name} "\
        "#{event_description} (internal transition, not exiting state)."
  		else
				"#{@state_machine.name} #{destination_state.name} "\
        "#{event_description}."
      end
    end


    # Called by source {State} when it is entered. Allows the
    # transition to initialize a mechanism that catches its trigger
    # event. Override this in a subclass.

    def arm
    end


    # Called by source {State} when it is exited. Subclass
    # implementations should deactivate their triggering
    # mechanism in this method.

    def unarm
    end

  end


  # This is kind of the 'standard' transition. It is created when
  # supplying the +:on+  option in the state machine definition.
  #
  # If armed, the transition is triggered when sending an event to the
  # state machine by calling {StateMachine::Base#event} with the
  # event's symbol as parameter. Sending the same event symbol while
  # not armed will just ignore the event.
  #
  # Note that you should call the {StateMachine::Base#event} method
  # from the same queue / thread where the state machine was started.
  #
  # @example Create a {SendEventTransition}:
  #
  #   state_machine.when :sleeping do |state|
  #     state.transition_to :awake, on: :foo
  #   end
  #
  #   state_machine.event :foo
  #     # => state machine goes to :awake state

  class SendEventTransition < Transition
    type :on

    def initialize(options)
      super(options)
      unarm
    end

    def event_description
      "after #{event_trigger_value}"
    end

    def arm
      state_machine.register_event_handler event_trigger_value, self
    end

    def unarm
      state_machine.register_event_handler event_trigger_value, nil
    end
  end


  # Transitions of this type are triggered on a given timeout (in
  # seconds). Created when supplying an :after option in the transition
  # definition.
  #
  # The timeout is canceled when the state is left.
  #
  # The transition uses Grand Central Dispatch's timer source
  # mechanism: It adds a timer source to the state machine's initial
  # GCD queue.
  #
  # The system tries to achieve an accuracy of 1 millisecond for the
  # timeout. You can change this behavior to trade timing accuracy vs.
  # system performance by using the +leeway+ option (given in seconds).
  # See {http://developer.apple.com/mac/library/DOCUMENTATION/Darwin/Reference/ManPages/man3/dispatch_source_set_timer.3.html Apple's GCD documentation}
  # for more information about this parameter.
  #
  # @example Create a transition that timeouts after 8 hours:
  #
  #   state_machine.when :sleeping do |state|
  #     # Timeout after 28800 seconds
  #     state.transition_to :awake, after: 8 * 60 * 60
  #   end

  class TimedTransition < Transition
    type :after

    def event_description
      "after #{event_trigger_value} seconds of "\
      "#{source_state.name} (timeout)"
    end

    #
    def arm
      @state_machine.log "Starting timeout -> #{options[:to]}, "\
        "after #{options[:after]}"
      delay = event_trigger_value
      interval = Dispatch::TIME_FOREVER
      leeway = @options[:leeway] || 0.001
      queue = @state_machine.initial_queue
      @timer = Dispatch::Source.timer(delay, interval, leeway, queue) do
        @state_machine.log "Timeout!"
        self.handle_in_source_state
      end
    end

    def unarm
      @state_machine.log "Timer unarmed"
      @timer.cancel!
    end

  end


  # Triggered on a specified +NSNotification+ name. Created when
  # supplying an +:on_notification+ option in the transition definition.
  #
  # On entering the source state, the transition registers itself as
  # +NSNotification+ observer on the default +NSNotificationCenter+. It
  # deregisters when the state is exited.
  #
  # @example
  #   state_machine.when :awake do |state|
  #     state.transition_to :sleeping,
  #       on_notificaiton: UIApplicationDidEnterBackgroundNotification
  #   end

  class NotificationTransition < Transition
    type :on_notification

    def initialize(options)
      super options
    end

    def event_description
      "after getting a #{event_trigger_value}"
    end

    def arm
      @observer = NSNotificationCenter.defaultCenter.addObserverForName event_trigger_value, 
        object: nil, 
        queue: NSOperationQueue.mainQueue, 
        usingBlock: -> notification {
          handle_in_initial_queue
          state_machine.log "Registered notification #{event_trigger_value}"
        }      
    end

    def unarm
      NSNotificationCenter.defaultCenter.removeObserver @observer
      @state_machine.log "Removed as observer"
    end


    private

    # This makes sure that state entry/exit and transition actions are
    # called within the initial queue/thread.

    def handle_in_initial_queue
      if state_machine.initial_queue.to_s == Dispatch::Queue.main.to_s
        handle_in_source_state
      else
        state_machine.initial_queue.async do
          handle_in_source_state
        end
      end
    end

  end

end
