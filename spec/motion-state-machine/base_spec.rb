describe StateMachine::Base do

  describe "#initialize" do

    it "should raise if not given a start state" do
      lambda {state_machine = StateMachine::Base.new}.
        should.raise(ArgumentError)
    end

    describe "when given a start state" do
      before do
        @fsm = StateMachine::Base.new start_state: :start
      end

      it "should initialize and use the internal state dictionary" do
        dictionary = @fsm.instance_variable_get(:@state_symbols_to_states)
        dictionary.class.should == Hash
      end

      it "should create an internal waiting_for_start state" do
        dictionary = @fsm.instance_variable_get(:@state_symbols_to_states)
        dictionary.count.should == 2
        state = dictionary[:waiting_for_start]
        state.class.should == StateMachine::State
        state.transition_map.count.should == 1
        transition = state.transition_map[:on][:start].first
        transition.options[:from].should == :waiting_for_start
        transition.options[:to].should ==:start
      end

      it "should set its current state to :waiting_for_start" do
        state = @fsm.current_state
        state.class.should == StateMachine::State
        state.symbol.should == :waiting_for_start
      end
    end

  end

  describe "after correct initialization" do

    before do
      @fsm = StateMachine::Base.new start_state: :awake
      @fsm.when(:awake) do |state|
        state.die :on => :terminate
      end
    end

    describe "#state(symbol, name = nil)" do
      it "should create & return a new state for the given symbol if not existing" do
        states_hash = @fsm.instance_variable_get(:@state_symbols_to_states)
        state_count_before = states_hash.count
        states_hash.has_key?(:some_other_state).should == false
        state = @fsm.state(:some_other_state, "Fake State")
        state.class.should == StateMachine::State
        states_hash.count.should == state_count_before + 1
        states_hash.has_key?(:some_other_state).should == true
        state.name.should == "Fake State"
      end

      it "should return the state with the given symbol if existing" do
        states_hash = @fsm.instance_variable_get(:@state_symbols_to_states)
        state_count_before = states_hash.count
        states_hash[:foo] = "bar"
        states_hash.count.should == state_count_before + 1
        @fsm.state(:foo).should == "bar"
        states_hash.count.should == state_count_before + 1
      end
    end

    describe "#start!" do
      it "should remember the initial queue if called from main queue" do
        Dispatch::Queue.current.to_s.should == Dispatch::Queue.main.to_s
        @fsm.start!
        @fsm.initial_queue.to_s.should == Dispatch::Queue.main.to_s
      end

      it "should remember the initial queue if called from another queue" do
        other_queue = Dispatch::Queue.concurrent(:default)
        other_queue.to_s.should != Dispatch::Queue.main.to_s
        other_queue.sync do
          @fsm.start!
        end
        @fsm.initial_queue.to_s.should == other_queue.to_s
      end

      it "should change the current state to the start state" do
        @fsm.current_state.symbol.should == :waiting_for_start
        @fsm.start!
        @fsm.current_state.symbol.should == :awake
      end
    end

    describe "#terminated?" do
      it "should return false until the machine is terminated" do
        @fsm.current_state.symbol.should == :waiting_for_start
        @fsm.terminated?.should == false
        @fsm.start!
        @fsm.current_state.symbol.should == :awake
        @fsm.terminated?.should == false
        @fsm.event(:terminate)
        @fsm.terminated?.should == true
      end
    end

    # describe "#stop_and_cleanup" do
    #   it "should unregister all notifications"
    #   it "should remove references to self from all registered states"
    # end

    # it "should not be too slow"
    #
    # it "should be thread-safe"

  end


end
