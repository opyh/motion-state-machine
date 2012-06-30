# Hey, this is +motion-state-machine+, a state machine designed for
# RubyMotion.
#
# It comes with a simple syntax to define states and transitions (see
# {Base#when}). It is aware of Grand Central Dispatch queues and uses
# them for synchronization.
#
# Its home is {https://github.com/opyh/motion-state-machine}.
#
# See the {file:README.md} for an overview and introduction.
#
# You might also want to look at {Base#when} and {State::TransitionDefinitionDSL}.

module StateMachine

  # Base class of a finite state machine (FSM). See {StateMachine} for
  # an overview.

  class Base

    # @return [Dispatch::Queue] the GCD queue where the state
    #   machine was started (or +nil+ if the state machine has
    #   not been started yet)
    attr_reader :initial_queue

    # @return [String] Name of the state machine.
    #   Only used in debug output.
    attr_reader :name

    # @return [Boolean] Indicates if the machine logs debug output.
    attr_reader :verbose

    # @return [State] Current {State} (or +nil+ if not in any
    #   state, e.g. after exiting and before entering a new state)
    attr_accessor :current_state


    # Initializes a new StateMachine.
    #
    # @param options [Hash]
    #   Configuration options for the FSM.
    #
    # @option options [Symbol] :start_state
    #   First state after start
    #
    # @option options [String] :name ("State machine")
    #   Name used in debugging output (optional)
    #
    # @option options [Boolean] :verbose (false)
    #   Indicate if the machine should output log texts to console.
    #
    # @example
    #   fsm = StateMachine::Base.new start_state: :awake
    #
    # @return [StateMachine::Base] a new StateMachine object

    def initialize(options)
      super
      @name = options[:name] || "State machine"
      @verbose = !!options[:verbose]
      @state_symbols_to_states = {}

      waiting_for_start_state = state :waiting_for_start,
        "waiting for start (internal state)"
      start_state = options[:start_state].to_sym
      if start_state.nil?
        raise ArgumentError, "You have to supply a :start_state option."
      end
      state start_state, options[:start_state_name]
      self.when :waiting_for_start, do |state|
        state.transition_to start_state, on: :start
      end

  		@current_state = waiting_for_start_state
      @current_state.send :enter!
    end


    # Adds defined transitions to the state machine. States that
    # you refer to with symbols are created automatically, on-the-fly,
    # so you do not have to define them with an extra statement.
    #
    # @param source_state_symbol [Symbol]
    #   Identifier of the state from which the transitions begins.
    #
    # @example Define transitions from a state +:awake+ to other states:
    #   fsm.when :awake do |state|
    #      state.transition_to ...
    #      state.die :on => ...
    #      state.on_entry { ... }
    #      state.on_exit { ... }
    #   end
    #
    # @yieldparam [TransitionDefinitionDSL] Call configuration methods
    #   on this object to define transitions. See
    #   {TransitionDefinitionDSL} for a list of possible methods.
    #
    # @see State::TransitionDefinitionDSL

    def when(source_state_symbol, &block)
      raise_outside_initial_queue
      source_state = state source_state_symbol
      source_state.send :add_transition_map_defined_in, &block
    end


    # @return an array of registered {StateMachine::State} objects.

    def states
      @state_symbols_to_states.values
    end


    # Starts the finite state machine. The machine will be in its
    # start state afterwards. For synchronization, it will remember
    # from which queue/thread it was started.

    def start!
    	@initial_queue = Dispatch::Queue.current
      event :start
    end


    # Sends an event to the state machine. If a matching
    # transition was defined, the transition will be executed. If
    # no transition matches, the event will just be ignored.
    #
    # @note You should call this method from the same queue / thread
    #   where the state machine was started.
    #
    # @param event_symbol [Symbol] The event to trigger on the
    #   state machine.
    #
    # @example
    #   my_state_machine.event :some_event

    def event(event_symbol)
      transition = @events[event_symbol]
      transition.send(:handle_in_source_state) unless transition.nil?
    end


    # @returns [Boolean] +true+ if the machine has been terminated,
    # +false+ otherwise.

    def terminated?
      current_state.terminating?
    end

    # Should stop the machine and clean up memory.
    # Should call exit actions on the current state, if defined.
    #
    # Not yet tested / really implemented yet, so use with care and
    # make a pull request if you should implement it ;)

    def stop_and_cleanup
      raise_outside_initial_queue
      @state_machine.log "Stopping #{self}..." if @verbose
      @current_state.send :exit!
      @current_state = nil
      @state_symbols_to_states.values.each(&:cleanup)
    end


    def inspect
      # Overridden to avoid debug output overhead
      # (default output would include all attributes)

      "#<#{self.class}:#{object_id.to_s(16)}>"
    end


    # @api private
    # Returns a State object identified by the given symbol.

    def state(symbol, name = nil)
      unless symbol.is_a?(Symbol)
        raise ArgumentError,
          "You have to supply a symbol to #state. "\
          "Maybe you wanted to call #current_state?"
      end
      raise_outside_initial_queue
      name ||= symbol.to_s
      @state_symbols_to_states[symbol] ||= State.new(self,
        symbol: symbol,
        name: name)
    end


    # @api private
    #
    # Registers a block that should be called when {#event} is called
    # with the given symbol as parameter.
    #
    # @param event_symbol [Symbol]
    #   symbol that identifies the block
    #
    # @param transition [Transition]
    #   transition that should be executed when calling {#event} with
    #   +event_symbol+ as parameter

    def register_event_handler(event_symbol, transition)
      (@events ||= {})[event_symbol] = transition
    end


    # @api private

    def raise_outside_initial_queue
      outside = Dispatch::Queue.current.to_s != @initial_queue.to_s
      if @initial_queue && outside
        raise RuntimeError,
          "Can't call this from outside #{@initial_queue} "\
          "(called from #{Dispatch::Queue.current})."
      end
    end

    def log(text)
      puts text if @verbose
    end

  end
end
