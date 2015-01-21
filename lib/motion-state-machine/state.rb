module StateMachine
  class State
    # @return [Symbol] The state's identifying symbol.
    attr_reader :symbol

    # @return [StateMachine::Base] the FSM that the state belongs to.
    attr_reader :state_machine

    # @return [String] the state's name. Only used in debug log output.
    attr_accessor :name

    # @return [Array] an array of +Proc+ objects called when entering
    #   the state.
    attr_accessor :entry_actions

    # @return [Array] an array of +Proc+ objects called when exiting
    #   the state.
    attr_accessor :exit_actions


    # @return [Hash] The state machine's internal transition map (event
    #   types -> event values -> possible transitions)
    #
    # @example
    #   {
    #     :on => {
    #       :some_event => [transition1, transition2, ...],
    #       :other_event => [transition3, transition4, ...],
    #     },
    #     :after => {
    #       5.0 => [transition5, transition6, ...]
    #     }
    #   }

    attr_reader :transition_map


    # Initializes a new State.
    #
    # @param [StateMachine] state_machine
    #   The state machine that the state belongs to.
    #
    # @param [Hash] options
    #   Configuration options for the state.
    #
    # @option options [Symbol] :symbol
    #   The state's identifier.
    #
    # @option options [String] :name (nil)
    #   The state's name. Only used in debug log output (optional).
    #
    # @example
    #   StateMachine::State.new state_machine: my_fsm,
    #     :symbol => :doing_something,
    #     :name => "doing something very important"
    #
    # @return [StateMachine::State] a new State object

    def initialize(state_machine, options)
      @state_machine = state_machine
      @symbol = options[:symbol]
      @name = options[:name] || options[:symbol].to_s
      if @symbol.nil? || @state_machine.nil?
        raise ArgumentError, "Missing parameter"
      end

      @transition_map = {}
      @entry_actions = []
      @exit_actions = []
    end


    # @return [Boolean] indicates if the state is a termination state.

    def terminating?
      !!@terminating
    end

    def terminating=(value)
      @terminating = !!value
    end

    # @api private
    # Registers a transition in the transition map.
    #
    # @param [Transition] transition the transition to register.

    def register(transition)
      event_type = transition.class.instance_variable_get(:@event_type)
      event_trigger_value = transition.event_trigger_value

      transition_map[event_type] ||= {}

      transitions =
        (transition_map[event_type][event_trigger_value] ||= [])
      transitions << transition

      transition
    end

    class TransitionDefinitionDSL

      # Initializes a new object that provides methods for configuring
      # state transitions.
      #
      # See {Base#when} for an explanation how to use the DSL.
      #
      # @param [State] source_state
      #   The source state in which the transitions begin.
      #
      # @param [StateMachine] state_machine
      #   The state machine in which the transitions should be defined.
      #
      # @yieldparam [TransitionDefinitionDSL] state
      #   The DSL object. Call methods on this object to define
      #   transitions.
      #
      # @return [StateMachine::State::TransitionDefinitionDSL]
      #   the initialized object.
      #
      # @api private
      # @see Base#when

      def initialize(source_state, state_machine, &block)
        @state_machine = state_machine
        @state = source_state
        yield(self)
      end

      # Creates transitions to another state when defined events happen.
      #
      # If multiple trigger events are defined, any of them will create
      # its own {Transition} object.
      #
      # You can specify guard blocks that can prevent a transition from
      # happening.
      #
      # @param options [Hash]
      #   Configuration options for the transition.
      #
      # @option options [Symbol]  :on
      #   Event symbol to trigger the transition via {Base#event}.
      #
      # @option options [String]  :on_notification
      #   +NSNotification+ name that triggers the transition if posted
      #   via default +NSNotificationCenter+.
      #
      # @option options [Float]   :after
      #   Defines a timeout after which the transition occurs if the
      #   state is not left before. Given in seconds.
      #
      # @option options [Proc]    :if (nil)
      #   Block that should return a +Boolean+. Return +false+ in this
      #   block to prevent the transition from happening.
      #
      # @option options [Proc]    :unless (nil)
      #   Block that should return a +Boolean+. Return +true+ in this
      #   block to prevent the transition from happening.
      #
      # @option options [Proc]    :action (nil)
      #   Block that is executed after exiting the source state and
      #   before entering the destination state. Will be called with
      #   the state machine as first parameter.
      #
      # @option options [Boolean] :internal (false)
      #   For a transition from a state to itself: If +true+, the
      #   transition does not call entry/exit actions on the state
      #   when executed.
      #
      # @example
      #   fsm.when :loading do |state|
      #      state.transition_to :displaying_data,
      #        on: :data_loaded,
      #        if: proc { data.valid? },
      #        action: proc { dismiss_loading_indicator }
      #   end
      #
      # @return [Array<StateMachine::Transition>] an array of all
      #   created transitions.
      #
      # @see Base#when

      def transition_to(destination_state_symbol, options)
        unless destination_state_symbol.is_a? Symbol
          raise ArgumentError,
            "No destination state given "\
            "(got #{destination_state_symbol.inspect})"
        end

        options.merge! from: @state.symbol, to: destination_state_symbol

        defined_event_types = Transition.types.select do |type|
          !options[type].nil?
        end

        if defined_event_types.empty?
          raise ArgumentError,
            "No trigger event found in #{options}. "\
            "Valid trigger event keys: #{Transition.types}."
        end

        transitions = []

        defined_event_types.each do |type|
          event_trigger_value = options[type]
          if event_trigger_value
            options.merge! state_machine: @state_machine,
                           type: type
            transition = Transition.make options
            @state.register(transition)
            transitions << transition
          end
        end

        transitions
      end


      # Defines a transition to a terminating state when a specified
      # event happens. Works analog to {#transition_to}, but creates a
      # terminating destination state automatically.
      #
      # @return [Array<StateMachine::Transition>]
      #   an array of all transitions that are defined in the option
      #   array (e.g. two transitions if you define an +:on+ and an
      #   +:after+ option, but no +:on_notification+ option).
      #
      # @see Base#when

      def die(options)
        termination_states = @state_machine.states.select(&:terminating?)
        symbol = "terminated_#{termination_states.count}".to_sym

        termination_state = @state_machine.state symbol
        termination_state.terminating = true

        transitions = transition_to(symbol, options)
        event_texts = transitions.collect(&:event_log_text).join(" or ")
        termination_state.name =
          "terminated (internal state) #{event_texts}"

        transitions
      end


      # Defines a block that will be called without parameters when the
      # source state is entered.
      #
      # @see Base#when

      def on_entry(blk = nil, &block)
        if block_given?
          @state.entry_actions << block
        else
          @state.entry_actions << blk
        end
      end




      # Defines a block that will be called without parameters when the
      # source state is exited.
      #
      # @see Base#when

      def on_exit(blk = nil, &block)
        if block_given?
          @state.exit_actions << block
        else
          @state.exit_actions << blk
        end
      end

    end


    private


    # Adds the outgoing transitions defined in the given block to the
    # state.

    def add_transition_map_defined_in(&block)
      TransitionDefinitionDSL.new self, @state_machine, &block
    end


    # Sets the state machine's current_state to self, calls all entry
    # actions and activates triggering mechanisms of all outgoing
    # transitions.

    def enter!
      @state_machine.current_state = self

      @entry_actions.each do |entry_action|
        entry_action.call(@state_machine)
      end
      @transition_map.each do |type, events_to_transition_arrays|
        events_to_transition_arrays.each do |event, transitions|
          transitions.each(&:arm)
        end
      end
    end


    # Sets the state machine's current_state to nil, calls all exit
    # actions and deactivates triggering mechanisms of all outgoing
    # transitions.

    def exit!
      map = @transition_map
      map.each do |type, events_to_transition_arrays|
        events_to_transition_arrays.each do |event, transitions|
          transitions.each(&:unarm)
        end
      end

      @exit_actions.each do |exit_action|
        exit_action.call(@state_machine)
      end
      @state_machine.current_state = nil
    end


    # Cleans up references to allow easier GC.

    def cleanup
      @transition_map.each do |type, events_to_transition_arrays|
        events_to_transition_arrays.each do |event, transitions|
          transitions.clear
        end
      end

      @transition_map = nil
      @state_machine = nil
      @entry_actions = nil
      @exit_actions = nil
    end


    # Executes the registered transition for the given event type and
    # event trigger value, if such a transition exists and it is
    # allowed.
    #
    # @raise [RuntimeError] if multiple transitions would be allowed at
    #   the same time.

    def guarded_execute(event_type, event_trigger_value, args = nil)
      @state_machine.raise_outside_initial_queue

      return if terminating?

      if @transition_map[event_type].nil? ||
         @transition_map[event_type][event_trigger_value].nil?
        raise ArgumentError,
          "No registered transition found "\
          "for event #{event_type}:#{event_trigger_value}."
      end

      possible_transitions =
        @transition_map[event_type][event_trigger_value]

      return if possible_transitions.empty?
      allowed_transitions = possible_transitions.select(&:allowed?)

      if allowed_transitions.empty?
        @state_machine.log "All transitions are disallowed for "\
          "#{event_type}:#{event_trigger_value}."
      elsif allowed_transitions.count > 1
        list = allowed_transitions.collect do |t|
          "-> #{t.options[:to]}"
        end
        raise RuntimeError,
          "Not sure which transition to trigger "\
          "when #{symbol} while #{self} (allowed: #{list}). "\
          "Please make sure guard conditions exclude each other."
      else
        transition = allowed_transitions.first
        unless transition.nil?
          transition.send :unguarded_execute, args
        end
      end

    end

  end
end
